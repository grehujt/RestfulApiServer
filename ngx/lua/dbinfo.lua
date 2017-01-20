local M = {}

M.mysqlconn = {
    host = "127.0.0.1",
    port = 3306,
    user = "lbsuser",
    password = "20lbsuserpass17"
}

M.connTimeout = 100000 -- 30s, pool idle timeout
M.connPoolSize = 100

return M
