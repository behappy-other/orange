local BasePlugin = require("orange.plugins.base_handler")
local json = require("orange.utils.json")
local utils = require("orange.utils.utils")
local sputils = require("orange.utils.sputils")
local orange_db = require("orange.store.orange_db")
local judge_util = require("orange.utils.judge")
local bot_rules = require "orange.plugins.bot_detection.rules"
local ipairs = ipairs
local re_find = ngx.re.find

local MATCH_EMPTY = 0
local MATCH_BOT = 3

local function filter_rules(sid, plugin, ngx_var_uri)

    local rules = orange_db.get_json(plugin .. ".selector." .. sid .. ".rules")
    if not rules or type(rules) ~= "table" or #rules <= 0 then
        return false
    end


    local user_agent, err = get_user_agent()
    for i, rule in ipairs(rules) do
        if rule.enable == true then
            -- judge阶段
            local pass = judge_util.judge_rule(rule, plugin)

            -- handle阶段
            if pass then
                -- log
                local handle = rule.handle
                if handle and handle.log == true then
                    require("orange.utils.sputils").log(ngx.ERR, "[BotDetection] start handling: ", rule.id, ":", ngx_var_uri)
                end

                if handle.continue == true then
                else
                    -- 不再匹配后续的规则
                    -- if we saw a denied UA or bot, return forbidden. otherwise,
                    -- fall out of our handler
                    if err then
                        require("orange.utils.sputils").log(ngx.ERR, "[BotDetection] handling exception: ", err)
                        return true
                    end
                    local match = examine_agent(user_agent, handle.rule)
                    return match > 1
                end
            end
        end
    end

    return false
end

function get_user_agent()
    local user_agent = ngx.req.get_headers()["user-agent"]
    if type(user_agent) == "table" then
        return nil, "Only one User-Agent header allowed"
    end
    return user_agent
end

function examine_agent(user_agent, additional_rule)
    user_agent = utils.strip(user_agent)
    if additional_rule ~= nil and additional_rule ~= "" and re_find(user_agent, additional_rule, "jo") then
        return MATCH_BOT
    end
    for _, rule in ipairs(bot_rules.bots) do
        if re_find(user_agent, rule, "jo") then
            return MATCH_BOT
        end
    end

    return MATCH_EMPTY
end

local BotDetectionHandler = BasePlugin:extend()
BotDetectionHandler.PRIORITY = 4996

function BotDetectionHandler:new(store)
    BotDetectionHandler.super.new(self, 'BotDetectionHandler-plugin')
    self.store = store
end

function BotDetectionHandler:access(conf)
    BotDetectionHandler.super.access(self)

    local enable = orange_db.get("bot_detection.enable")
    local meta = orange_db.get_json("bot_detection.meta")
    local selectors = orange_db.get_json("bot_detection.selectors")
    local ordered_selectors = meta and meta.selectors

    if not enable or enable ~= true or not meta or not ordered_selectors or not selectors then
        return
    end

    local ngx_var_uri = ngx.var.uri
    for i, sid in ipairs(ordered_selectors) do
        require("orange.utils.sputils").log(ngx.INFO, "==[BotDetection][PASS THROUGH SELECTOR:", sid, "]")
        local selector = selectors[sid]
        if selector and selector.enable == true then
            local selector_pass
            if selector.type == 0 then -- 全流量选择器
                selector_pass = true
            else
                selector_pass = judge_util.judge_selector(selector, "bot_detection")-- selector judge
            end

            if selector_pass then
                if selector.handle and selector.handle.log == true then
                    require("orange.utils.sputils").log(ngx.INFO, "[BotDetection][PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end

                local filter_res = filter_rules(sid, "bot_detection", ngx_var_uri)
                -- true则拦截,false则继续
                if filter_res == true then
                    -- 不再执行此插件其他逻辑
                    sputils.waf_html()
                    return
                end
            else
                if selector.handle and selector.handle.log == true then
                    require("orange.utils.sputils").log(ngx.INFO, "[BotDetection][NOT-PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end
            end
        end
    end

end



return BotDetectionHandler
