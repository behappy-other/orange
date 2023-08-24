local _M = {}

function _M.log(level, ...)
    ngx.log(level, '[',os.date("%Y-%m-%d %H:%M:%S") ,'] ~ gateway_orange_service ~ ', '-',' ~ ', '-', ' ~ ', ngx.var.remote_addr, ' ~ ', ...)
end

return _M
