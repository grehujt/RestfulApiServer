
local lbs = lbs
local method = ngx.req.get_method()
local args = ngx.ctx.body
if args==nil then
    local decode = decode
    ngx.req.read_body()
    local tmp = ngx.req.get_body_data()
    args = decode(tmp)
end
if not args then return end

if method == "DELETE" then
    lbs:bulk_delete("lbs_"..ngx.var.db,ngx.var.table,args)
elseif method == "PUT" then
    lbs:bulk_upsert("lbs_"..ngx.var.db,ngx.var.table,args)
end
