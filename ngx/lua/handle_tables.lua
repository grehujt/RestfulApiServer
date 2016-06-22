
local lbs = lbs
local find = string.find
local method = ngx.req.get_method()

if method == "GET" then
    local getArgs = ngx.ctx.qs
    if getArgs==nil then
        getArgs = ngx.req.get_uri_args()
    end
    local proj = "*"
    if getArgs.proj then
        proj = getArgs.proj
        if find(proj," ") then
            return ngx.exit(500)
        end
    end
    local where = ""
    if getArgs.where then
        where = getArgs.where
        if find(where,";") then
            return ngx.exit(500)
        end
    end
    local limit = ""
    if getArgs.limit then
        limit = getArgs.limit
        if find(limit,";") then
            return ngx.exit(500)
        end
    end
    if #limit>0 then
        where = where.." "..limit
    end
    lbs:select(ngx.var.db,ngx.var.table,proj,where)
else
    local args = ngx.ctx['body']
    if args==nil then
        local decode = decode
        ngx.req.read_body()
        local tmp = ngx.req.get_body_data()
        args = decode(tmp)
    end
    if not args then return end

    if method == "POST" then
        local tmp1 = {}
        local tmp2 = {}
        for key,value in pairs(args) do
            if key~="auth" and key~="ver" then
                table.insert(tmp1,key)
                table.insert(tmp2,ngx.quote_sql_str(value))
            end
        end
        if #tmp1==0 or #tmp2==0 or #tmp1~=#tmp2 then
            -- ngx.say("POST invalid: no para")
            return ngx.exit(500)
        end
        lbs:insert(ngx.var.db,ngx.var.table,tmp1,tmp2)
    elseif method == "PUT" then
        local tmp1 = {}
        local tmp2 = {}
        local tmp3 = {}
        local idx = 1
        for key,value in pairs(args) do
            if key~="auth" and key~="ver" then
               tmp1[idx] = key
               tmp2[idx] = ngx.quote_sql_str(value)
               tmp3[idx] = key.."=VALUES("..key..")"
               idx = idx+1
            end
        end
        if #tmp1==0 or #tmp2==0 or #tmp1~=#tmp2 then
            -- ngx.say("PUT invalid: no para")
            return ngx.exit(500)
        end
        lbs:upsert(ngx.var.db,ngx.var.table,tmp1,tmp2,tmp3)
    end
end

