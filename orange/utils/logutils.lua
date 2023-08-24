local _M = {}

function _M.log(level, ...)
    if ngx ~= nil and ngx.req ~= nil then
        local headers = ngx.req.get_headers()
        if headers ~= nil and next(headers) ~= nil then
            return require("orange.utils.logutils").log(level, '[',os.date("%Y-%m-%d %H:%M:%S") ,'] ~ gateway_orange_service ~ ', (headers["trace-id"] or "-"), ' ~ ', '-', ' ~ ', ngx.var.remote_addr, ' ~ ', ...)
        end
    end
    require("orange.utils.logutils").log(level, '[',os.date("%Y-%m-%d %H:%M:%S") ,'] ~ gateway_orange_service ~ ', '-',' ~ ', '-', ' ~ ', ngx.var.remote_addr, ' ~ ', ...)
end

return _M
