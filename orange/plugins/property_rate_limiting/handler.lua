local ipairs = ipairs
local type = type
local tostring = tostring
local table_concat = table.concat;

local utils = require("orange.utils.utils")
local orange_db = require("orange.store.orange_db")
local judge_util = require("orange.utils.judge")
local BasePlugin = require("orange.plugins.base_handler")
local plugin_config =  require("orange.plugins.property_rate_limiting.plugin")
local counter = require("orange.plugins.property_rate_limiting.counter")
local extractor_util = require("orange.utils.extractor")
local sp_utils = require("orange.utils.sputils")
local block_prefix = "BLOCK"

local function get_stat_by_key(limit_key)
    return counter.get(limit_key)
end

local function incr_stat(limit_key, limit_type)
    counter.incr(limit_key, 1, limit_type)
end

local function get_limit_type(period)
    if not period then return nil end

    if period == 1 then
        return "Second"
    elseif period == 60 then
        return "Minute"
    elseif period == 3600 then
        return "Hour"
    elseif period == 86400 then
        return "Day"
    else
        return nil
    end
end

local function do_filter_no_blocked(handle, rule, real_value, limit_type, limit_key, remote_addr, current_stat, blocked_num, ngx_var_uri)
    if current_stat >= handle.count then
        if handle.log == true then
            ngx.log(ngx.INFO, plugin_config.message_forbidden, rule.name, " uri:", ngx_var_uri, " limit:", handle.count, " reached:", current_stat, " remaining:", 0)
        end

        ngx.header[plugin_config.plug_reponse_header_prefix ..limit_type] = 0
        ngx.exit(429)
        return true
    else
        ngx.header[plugin_config.plug_reponse_header_prefix ..limit_type] = handle.count - current_stat - 1
        incr_stat(limit_key, limit_type)

        -- only for test, comment it in production
        -- if handle.log == true then
        --     ngx.log(ngx.INFO, "[RateLimiting-Rule] ", rule.name, " uri:", ngx_var_uri, " limit:", handle.count, " reached:", current_stat + 1)
        -- end
    end
    return false
end

local function do_filter_has_blocked(handle, rule, real_value, limit_type, limit_key, remote_addr, current_stat, blocked_num, ngx_var_uri)
    --block_key 添加限制类型limit_type 区分不同规则
    local block_key = block_prefix .. "#" .. rule.id .. "#" .. real_value .. "#" .. limit_type
    ngx.log(ngx.ERR,"property_rate_limiting - block_key：",block_key)
    --判断是否处于封禁状态
    local is_blocked = get_stat_by_key(block_key)
    ngx.log(ngx.ERR,"property_rate_limiting - is_blocked：", is_blocked)
    --该key是针对当前period下的限制访问频次
    local handle_count_key = rule.id .. "#" .. limit_type
    local before_handle_count = get_stat_by_key(handle_count_key) or 0
    ngx.log(ngx.ERR,"property_rate_limiting - before_handle_count：",before_handle_count)

    --如果控制台重新设置了限制次数，则加以判断
    if is_blocked and handle.count <= before_handle_count then
        if handle.log == true then
            ngx.log(ngx.ERR, plugin_config.message_forbidden, " remote_addr：", remote_addr, ' rule_name：', rule.name, " uri：", ngx_var_uri, " limit：", handle.count, " reached:", current_stat, " remaining：", 0)
        end
        ngx.header[plugin_config.plug_reponse_header_prefix ..limit_type] = 0
        ngx.exit(403)
        return true
    end

    --current_stat：当前访问次数，handle.count：限制时间范围内的访问访问数量
    if current_stat >= handle.count then
        if handle.log == true then
            ngx.log(ngx.ERR, plugin_config.message_forbidden, " remote_addr：", remote_addr, ' rule_name：', rule.name, " uri：", ngx_var_uri, " limit：", handle.count, " reached：", current_stat, " remaining：", 0)
        end
        ngx.header[plugin_config.plug_reponse_header_prefix ..limit_type] = 0
        if not is_blocked then
            --之前没用被封禁，则设置封禁时长，blocked_num 秒后自动从缓存过期
            counter.set(block_key, 1, blocked_num)
        end
        ngx.exit(403)
        return true
    else
        --在允许访问频次范围内，访问次数+1
        ngx.header[plugin_config.plug_reponse_header_prefix ..limit_type] = handle.count - current_stat - 1
        counter.set(handle_count_key, handle.count, blocked_num)
        if is_blocked then
            counter.delete(block_key)
        end
        incr_stat(limit_key, limit_type)

        -- only for test, comment it in production
        -- if handle.log == true then
        --     ngx.log(ngx.ERR, "[RateLimiting-Rule] ", rule.name, " uri:", ngx_var_uri, " limit:", handle.count, " reached:", current_stat + 1)
        -- end
    end
    return false
end

local function filter_rules(sid, plugin, ngx_var_uri)
    local rules = orange_db.get_json(plugin .. ".selector." .. sid .. ".rules")
    if not rules or type(rules) ~= "table" or #rules <= 0 then
        return false
    end

    --日志记录remote_addr
    local remote_addr = ngx.var.remote_addr

    for i, rule in ipairs(rules) do
        if rule.enable == true then
            ngx.log(ngx.ERR, "property_rate_limiting - rule.extractor: ", sp_utils.tableToStr(rule.extractor))
            -- 变量取值
            local real_value = table_concat( extractor_util.extract_variables(rule.extractor),"#")
            ngx.log(ngx.ERR, "property_rate_limiting - real_value: ", real_value)
            local pass = (real_value ~= '');

            -- handle阶段
            local handle = rule.handle
            local blocked_num = handle.blocked
            if pass then
                local limit_type = get_limit_type(handle.period)
                ngx.log(ngx.ERR, "property_rate_limiting - limit_type: ", limit_type)
                -- only work for valid limit type(1 second/minute/hour/day)
                if limit_type then
                    local current_timetable = utils.current_timetable()
                    local time_key = current_timetable[limit_type]
                    ngx.log(ngx.ERR,"property_rate_limiting - time_key：",time_key)
                    local limit_key = rule.id .. "#" .. time_key .. "#" .. real_value
                    ngx.log(ngx.ERR,"property_rate_limiting - limit_key：",limit_key)
                    --得到当前缓存中limit_key的数量 - 对应该time_key下已访问的数量
                    local current_stat = get_stat_by_key(limit_key) or 0
                    ngx.log(ngx.ERR,"property_rate_limiting - current_stat：",current_stat,", limit_type：",limit_type)

                    --如果blocked不为空，则需要进行封禁403。反之429
                    ngx.log(ngx.ERR, "property_rate_limiting - blocked_num: ", blocked_num)
                    if blocked_num and blocked_num ~= "" then
                        return do_filter_has_blocked(handle, rule, real_value, limit_type, limit_key, remote_addr, current_stat, blocked_num, ngx_var_uri)
                    else
                        return do_filter_no_blocked(handle, rule, real_value, limit_type, limit_key, remote_addr, current_stat, blocked_num, ngx_var_uri)
                    end
                end
            end -- end `pass`

        end -- end `enable`
    end -- end for

    return false
end


local PropertyRateLimitingHandler = BasePlugin:extend()
PropertyRateLimitingHandler.PRIORITY = 1000

function PropertyRateLimitingHandler:new(store)
    PropertyRateLimitingHandler.super.new(self, plugin_config.name)
    self.store = store
end

function PropertyRateLimitingHandler:access(conf)
    PropertyRateLimitingHandler.super.access(self)

    local enable = orange_db.get(plugin_config.table_name..".enable")
    local meta = orange_db.get_json(plugin_config.table_name..".meta")
    local selectors = orange_db.get_json(plugin_config.table_name..".selectors")
    local ordered_selectors = meta and meta.selectors

    if not enable or enable ~= true or not meta or not ordered_selectors or not selectors then
        return
    end

    local ngx_var_uri = ngx.var.uri
    for i, sid in ipairs(ordered_selectors) do
        ngx.log(ngx.ERR, "==[",plugin_config.name_for_log,"][PASS THROUGH SELECTOR:", sid, "]")
        local selector = selectors[sid]
        if selector and selector.enable == true then
            local selector_pass
            if selector.type == 0 then -- 全流量选择器
                selector_pass = true
            else
                selector_pass = judge_util.judge_selector(selector,plugin_config.table_name)-- selector judge
            end

            if selector_pass then
                if selector.handle and selector.handle.log == true then
                    ngx.log(ngx.ERR, "[",plugin_config.name_for_log,"][PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end

                local stop = filter_rules(sid, plugin_config.table_name, ngx_var_uri)
                local selector_continue = selector.handle and selector.handle.continue
                if stop or not selector_continue then -- 不再执行此插件其他逻辑
                    return
                end
            else
                if selector.handle and selector.handle.log == true then
                    ngx.log(ngx.ERR, "[",plugin_config.name_for_log,"][NOT-PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end
            end
        end
    end

end

return PropertyRateLimitingHandler
