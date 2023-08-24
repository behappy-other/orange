local _M = {}

function _M.log(level, ...)
    ngx.log(level, '[',os.date("%Y-%m-%d %H:%M:%S") ,'] ~ gateway_orange_service ~ ', '-',' ~ ', '-', ' ~ ', '-', ' ~ ', 'no header')
end

return _M
