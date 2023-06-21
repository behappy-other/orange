---
--- Generated by Luanalysis
--- Created by Jessica.
--- DateTime: 2021/6/10 14:50
---
local redis = require("orange.utils.redis")
local config_loader = require("orange.utils.config_loader")

local BaseRedis = {}
local env_orange_conf = os.getenv("ORANGE_CONF")
local conf_file_path = env_orange_conf or ngx.config.prefix().. "/conf/orange.conf"
local context = config_loader.load(conf_file_path)
local cache = redis:new({
    host = context.redis.host,
    port = context.redis.port,
    password = context.redis.password,
    db_index = context.redis.db_index,
});

function BaseRedis.get(cache_prefix, key)
    key = cache_prefix .. ":" .. key
    local res, err = cache:get(key)
    return tonumber(res)
end

function BaseRedis.get_string(cache_prefix, key)
    key = cache_prefix .. ":" .. key
    local res, err = cache:get(key)
    return res
end

function BaseRedis.set(cache_prefix, key, value, expired)
    key = cache_prefix .. ":" .. key
    local res, err = cache:set(key, value)
    cache:expire(key, expired or -1)
    return res
end

function BaseRedis.setnx(cache_prefix, key, value, expired)
    key = cache_prefix .. ":" .. key
    ngx.log(ngx.ERR, "key: ", key)
    local res, err = cache:setnx(key, value, expired or -1)
    return res, err
end

function BaseRedis.incr(cache_prefix, key, value, expired)
    key = cache_prefix .. ":" .. key
    local res, err = cache:get(key)
    if not res then
        res, err = cache:set(key, 0)
        cache:expire(key, expired or -1)
    end
    res, err = cache:incr(key)
    return res
end

function BaseRedis.delete(cache_prefix, key)
    key = cache_prefix .. ":" .. key
    local res, err = cache:del(key)
    return res
end

function BaseRedis.get_keys(cache_prefix)
    local res, err = cache:keys(cache_prefix)
    return res
end

function BaseRedis.scan(prefix, cursor, count)
    prefix = prefix .. ":*"
    local res, err = cache:scan(cursor, "count", count, "match", prefix)
    if not res then
        ngx.log(ngx.ERR, "failed to scan: ", err)
        return
    end
    local cursor, keys, err = unpack(res)
    return cursor, keys, err
end

return BaseRedis

