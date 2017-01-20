
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
    local tmp = {}
    for id in string.gmatch(ngx.var.ids, '([^,]+)') do
        table.insert(tmp, ngx.quote_sql_str(id))
    end
    lbs:select("lbs_"..ngx.var.db,ngx.var.table,proj,"_id in (".. table.concat(tmp,",") .. ")")
end

