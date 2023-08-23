---
-- from https://github.com/Mashape/kong/blob/master/kong/plugins/base_plugin.lua
-- modified by sumory.wu

local Object = require("orange.lib.classic")
local BasePlugin = Object:extend()

function BasePlugin:new(name)
    self._name = name
end

function BasePlugin:get_name()
    return self._name
end

function BasePlugin:init_worker()
    require("orange.utils.sputils").log(ngx.DEBUG, " executing plugin \"", self._name, "\": init_worker")
end

function BasePlugin:redirect()
    require("orange.utils.sputils").log(ngx.DEBUG, " executing plugin \"", self._name, "\": redirect")
end

function BasePlugin:rewrite()
    require("orange.utils.sputils").log(ngx.DEBUG, " executing plugin \"", self._name, "\": rewrite")
end

function BasePlugin:access()
    require("orange.utils.sputils").log(ngx.DEBUG, " executing plugin \"", self._name, "\": access")
end

function BasePlugin:balancer()
    require("orange.utils.sputils").log(ngx.DEBUG, " executing plugin \"", self._name, "\": balancer")
end

function BasePlugin:header_filter()
    require("orange.utils.sputils").log(ngx.DEBUG, " executing plugin \"", self._name, "\": header_filter")
end

function BasePlugin:body_filter()
    require("orange.utils.sputils").log(ngx.DEBUG, " executing plugin \"", self._name, "\": body_filter")
end

function BasePlugin:log()
    require("orange.utils.sputils").log(ngx.DEBUG, " executing plugin \"", self._name, "\": log")
end

return BasePlugin
