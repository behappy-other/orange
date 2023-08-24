local _M = {}

function _M.log(level, ...)
    ngx.log(level, '~ ',os.date("%Y-%m-%d %H:%M:%S.%f") ,' ~ gateway_orange_service ~ ', '-',' ~ ', '-', ' ~ ', '-', ' ~ ', ...)
end

return _M
