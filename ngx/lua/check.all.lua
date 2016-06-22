
local dbinfo = require("dbinfo")

if not (dbinfo.allowed_dbs[ngx.var.db] and dbinfo.allowed_tables[ngx.var.table]) then
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local method = ngx.req.get_method()
local needAuth = dbinfo.method_permisson[method]
if needAuth==nil then
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

if needAuth then
    local auth = dbinfo.auth
    local headers = ngx.req.get_headers()
    local qs = ngx.req.get_uri_args()
    if headers.xauth then
        if auth~=headers.xauth then
            return ngx.exit(ngx.HTTP_BAD_REQUEST)
        else
            ngx.ctx.headers = headers
            ngx.ctx.auth = true
        end
    elseif qs.auth then
        if qs.auth~=auth then
            return ngx.exit(ngx.HTTP_BAD_REQUEST)
        else
            ngx.ctx.qs = qs
            ngx.ctx.auth = true
        end
    else
        local decode = decode
        ngx.req.read_body()
        local tmp = ngx.req.get_body_data()
        if #tmp>0 then
            local args = decode(tmp)
            if args.auth~=auth then
                return ngx.exit(ngx.HTTP_BAD_REQUEST)
            else
                ngx.ctx.body = args
                ngx.ctx.auth = true
            end
        else
            return ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
    end
end
