
local lbs = lbs
local find = string.find
local method = ngx.req.get_method()
local getArgs = ngx.ctx.qs
if getArgs==nil then
    getArgs = ngx.req.get_uri_args()
end
local where = ""
if getArgs.where then
    where = getArgs.where
    if find(where," ") then
        return ngx.exit(500)
    end
end
local cnd = "_id="..ngx.quote_sql_str(ngx.var.id)
if #where>0 then
    cnd = cnd.." and "..where
end

if method == "GET" then
    local proj = "*"
    if getArgs.proj then
        proj = getArgs.proj
        if find(proj," ") then
            return ngx.exit(500)
        end
    end
    lbs:select("lbs_"..ngx.var.db,ngx.var.table,proj,cnd)
elseif method == "PATCH" then
    local args = ngx.ctx['body']
    if args==nil then
        local decode = decode
        ngx.req.read_body()
        local tmp = ngx.req.get_body_data()
        args = decode(tmp)
    end
    if not args then return end
    local tmp = {}
    local idx = 1
    for key,value in pairs(args) do
        if key~="auth" and key~="ver" then
            tmp[idx] = key.."="..ngx.quote_sql_str(value)
            idx = idx+1
        end
    end
    if #tmp==0 then
        ngx.say("PATCH invalid: no para")
        return
    end
    lbs:update("lbs_"..ngx.var.db,ngx.var.table,tmp,cnd)
elseif method == "DELETE" then
    lbs:delete("lbs_"..ngx.var.db,ngx.var.table,cnd)
end

