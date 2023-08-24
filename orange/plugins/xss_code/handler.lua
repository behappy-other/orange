local BasePlugin = require("orange.plugins.base_handler")
local json = require("orange.utils.json")
local sputils = require("orange.utils.sputils")
local orange_db = require("orange.store.orange_db")
local judge_util = require("orange.utils.judge")
local injection = require("orange.utils.injection")

local function filter_rules(sid, plugin, ngx_var_uri, args)

    local rules = orange_db.get_json(plugin .. ".selector." .. sid .. ".rules")
    if not rules or type(rules) ~= "table" or #rules <= 0 then
        return false
    end

    for i, rule in ipairs(rules) do
        if rule.enable == true then
            -- judge阶段
            local pass = judge_util.judge_rule(rule, plugin)

            -- handle阶段
            if pass then
                -- log
                local handle = rule.handle
                if handle and handle.log == true then
                    require("orange.utils.logutils").log(ngx.ERR, "[XssCode] start handling: ", rule.id, ":", ngx_var_uri)
                end

                if handle.continue == true then
                else
                    for i, v in ipairs(args) do
                        if injection.xss(v) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end


local XssCodeHandler = BasePlugin:extend()
XssCodeHandler.PRIORITY = 4997

function XssCodeHandler:new(store)
    XssCodeHandler.super.new(self, 'XssCodeHandler-plugin')
    self.store = store
end

function XssCodeHandler:access(conf)
    XssCodeHandler.super.access(self)

    local enable = orange_db.get("xss_code.enable")
    local meta = orange_db.get_json("xss_code.meta")
    local selectors = orange_db.get_json("xss_code.selectors")
    local ordered_selectors = meta and meta.selectors

    if not enable or enable ~= true or not meta or not ordered_selectors or not selectors then
        return
    end

    local params = sputils.getReqParamsStr(ngx)
    local ngx_var_uri = ngx.var.uri
    for i, sid in ipairs(ordered_selectors) do
        require("orange.utils.logutils").log(ngx.INFO, "==[XssCode][PASS THROUGH SELECTOR:", sid, "]")
        local selector = selectors[sid]
        if selector and selector.enable == true then
            local selector_pass
            if selector.type == 0 then -- 全流量选择器
                selector_pass = true
            else
                selector_pass = judge_util.judge_selector(selector, "xss_code")-- selector judge
            end

            if selector_pass then
                if selector.handle and selector.handle.log == true then
                    require("orange.utils.logutils").log(ngx.INFO, "[XssCode][PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end

                local filter_res = filter_rules(sid, "xss_code", ngx_var_uri, params)
                --true则拦截,false则继续
                if filter_res == true then
                    -- 不再执行此插件其他逻辑
                    sputils.waf_html()
                    return
                end
            else
                if selector.handle and selector.handle.log == true then
                    require("orange.utils.logutils").log(ngx.INFO, "[XssCode][NOT-PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end
            end
        end
    end

end

return XssCodeHandler
