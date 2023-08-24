local _M = {}

function _M.log(level, ...)
    ngx.log(level, 'level ~ ',os.date("%Y-%m-%d %H:%M:%S.000") ,' ~ gateway_orange_service ~ ', '-',' ~ ', '-', ' ~ ', '-', ' ~ ', ...)
end

return _M
