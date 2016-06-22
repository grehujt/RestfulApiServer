
local dbInfo = require("dbinfo")
local encode = encode
local M = { _VERSION = "1.0.1" }

------------------------------------------------

local function _get_conn()
    local mysql = require("resty.mysql")
    local client, errmsg = mysql:new()
    client:set_timeout(10000) --10s connection timeout
    local ok, err, errno, sqlstate
    if ngx.ctx.auth then
        ok, err, errno, sqlstate = client:connect(dbInfo.mysqlconn)
    else
        ok, err, errno, sqlstate = client:connect(dbInfo.mysqlconn_ro)
    end
    if not ok then
        ngx.log(ngx.ERR, "failed to connect: ", err, ": ", errno, " ", sqlstate)
        return ngx.exit(500)
    end
    ngx.ctx.mysql_pool = client
    return client
end

local function _close()
    if ngx.ctx.mysql_pool then
        local ok, err = ngx.ctx.mysql_pool:set_keepalive(dbInfo.connTimeout,dbInfo.connPoolSize)
        if not ok then
            ngx.log(ngx.ERR, "failed to set keepalive: ", err)
            -- ngx.exit(500)
        end
    end
end

local function _query(sql)
    local client = _get_conn()
    local res, err, errno, sqlstate = client:query(sql)
    if not res then
        ngx.log(ngx.ERR, "bad result #1: ", err, ": ", errno, ": ", sqlstate, ".")
        return ngx.exit(500)
    end
    -- times, err = client:get_reused_times()
    -- ngx.say("reused ",times,"times")
    ngx.print(encode(res),"\r\n")
    local i = 2
    while err == "again" do
        res, err, errno, sqlstate = client:read_result()
        if not res then
            ngx.log(ngx.ERR, "bad result #", i, ": ", err, ": ", errno, ": ", sqlstate, ".")
            return ngx.exit(500)
        end
        ngx.print(encode(res),"\r\n")
        i = i + 1
    end
    _close()
end

local function _query_result(sql)
    local client = _get_conn()
    local res, err, errno, sqlstate = client:query(sql)
    if not res then
        ngx.log(ngx.ERR, "bad result #1: ", err, ": ", errno, ": ", sqlstate, ".")
        return ngx.exit(500)
    end
    _close()
    return res
end

------------------------------------------------

function M.select(self,dbName,tbl,proj,where,returnResult)
    local cmd = nil
    if #where>0 then
        cmd = "SELECT " .. proj .. " FROM " .. dbName .. "." .. tbl .." WHERE "..where.. ";"
    else
        cmd = "SELECT " .. proj .. " FROM " .. dbName .. "." .. tbl .. ";"
    end
    if returnResult then
        return _query_result(cmd)
    else
        _query(cmd)
    end
end

------------------------------------------------

function M.insert(self,dbName,tbl,keys,values)
    local cmd = "INSERT INTO " .. dbName .. "." .. tbl .. "(" .. table.concat(keys,",") .. ") VALUES (" .. table.concat(values,",") .. ");"
    _query(cmd)
end

------------------------------------------------

function M.update(self,dbName,tbl,kvs,where)
    local cmd = "UPDATE " .. dbName .. "." .. tbl .. " SET " .. table.concat(kvs,",") .. " WHERE " .. where .. ";"
    _query(cmd)
end

------------------------------------------------

function M.upsert(self,dbName,tbl,keys,values,values2)
    local cmd = "INSERT INTO " .. dbName .. "." .. tbl .. "(" .. table.concat(keys,",") .. ") VALUES (" .. table.concat(values,",") .. ") ON DUPLICATE KEY UPDATE " .. table.concat(values2,",") .. ";"
    _query(cmd)
end

------------------------------------------------

function M.bulk_upsert(self,dbName,tbl,args)
    local result = {}
    for i,d in pairs(args) do
        local keys = {}
        local values = {}
        local values2 = {}
        for key,value in pairs(d) do
            table.insert(keys,key)
            table.insert(values,ngx.quote_sql_str(value))
            table.insert(values2,key.."=VALUES("..key..")")
        end
        table.insert(result,"INSERT INTO " .. dbName .. "." .. tbl .. "(" .. table.concat(keys,",") .. ") VALUES (" .. table.concat(values,",") .. ") ON DUPLICATE KEY UPDATE " .. table.concat(values2,",") .. ";")
    end
    _query(table.concat(result,""))
end

------------------------------------------------

function M.delete(self,dbName,tbl,where)
    local cmd = "DELETE FROM " .. dbName .. "." .. tbl .. " WHERE " .. where .. ";"
    _query(cmd)
end

function M.bulk_delete(self,dbName,tbl,args)
    local tmp1 = {}
    for i,id in pairs(args) do
        table.insert(tmp1,id)
    end
    self:delete(dbName,tbl,'_id in ('..table.concat(tmp1,",")..');')
end

------------------------------------------------

return M
