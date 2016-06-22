local M = {}

M.mysqlconn_ro = {
    host = "127.0.0.1",
    port = 3306,
    user = "roUser",
    password = "roUserPasscode"
}

M.mysqlconn = {
    host = "127.0.0.1",
    port = 3306,
    user = "rwUser",
    password = "rwUserPasscode"
}

M.auth = "<auth token>"
M.connTimeout = 100000 --30s, pool idle timeout
M.connPoolSize = 100

M.allowed_dbs = {
    allowDbName0 = true,
    allowDbName1 = true,
}

M.allowed_tables = {
    allowTbl0 = true,
    allowTbl1 = true,
}

M.method_permisson = {
    GET = false,
    POST = true,
    PUT = true,
    PATCH = true,
    DELETE = true,
}

return M
