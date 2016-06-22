
local lbs = lbs
local find = string.find

if ngx.req.get_method() == "GET" then
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
    lbs:select(ngx.var.db,ngx.var.table,proj,"_id in ("..ngx.var.ids .. ")")
end

