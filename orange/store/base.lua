local Object = require("orange.lib.classic")
local Store = Object:extend()

function Store:new(name)
    self._name = name
end

function Store:set(k, v)
    require("orange.utils.logutils").log(ngx.DEBUG, " store \"" .. self._name .. "\" set:" .. k, " v:", v)
end

function Store:get(k)
    require("orange.utils.logutils").log(ngx.DEBUG, " store \"" .. self._name .. "\" get:" .. k)
end

return Store
