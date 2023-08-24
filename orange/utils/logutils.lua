local _M = {}

function _M.log(level, ...)
    ngx.log(level, ...)
end

return _M
