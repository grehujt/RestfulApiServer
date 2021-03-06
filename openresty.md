
[ref](https://www.gitbook.com/book/moonbingbing/openresty-best-practices/details)

- 缓存失效风暴(dog-pile effect)
    + 发现缓存失效后,加一把锁来控制数据库的请求
    + [lua-resty-lock](https://github.com/openresty/lua-resty-lock#for-cache-locks)

- 压力测试
    + ab(apache bench)
        * ab 的使用超级简单,简单的有点弱了。在上面的例子中,我们发起了 10 个请 求,每个请求都是一样的,如果每个请求有差异,ab 就无能为力。
        
        ```sh
        $ ab -n10 -c2 http://abc.com/
        -- output:
        ...
        Complete requests:
        Failed requests:
        Non-2xx responses:
        Total transferred:
        HTML transferred:
        Requests per second:
        Time per request:
        Time per request:
        Transfer rate:
        ...
        10
        0
        10
        3620 bytes
        1780 bytes
        22.00 [#/sec] (mean)
        90.923 [ms] (mean)
        45.461 [ms] (mean, across all concurrent requests)
        7.78 [Kbytes/sec] received
        ```

    + wrk
        * 满足每个请求或部分请求有差异:
        scripts/counter.lua:
        ```lua
        
         
        -- example dynamic request script which demonstrates changing -- the request path and a header for each request ------------------------------------------------------------- -- NOTE: each wrk thread has an independent Lua scripting
        -- context and thus there will be one counter per thread
        counter = 0
        request = function()
           path = "/" .. counter
           wrk.headers["X-Counter"] = counter
           counter = counter + 1
           return wrk.format(nil, path)
        end
        ```

        ```sh
        $ ./wrk -c10 -d1 -s scripts/counter.lua http://baidu.com
        Running 1s test @ http://baidu.com
          2 threads and 10 connections
          Thread Stats   Avg      Stdev     Max   +/- Stdev
            Latency    20.44ms    3.74ms  34.87ms   77.48%
            Req/Sec   226.05     42.13   270.00     70.00%
          453 requests in 1.01s, 200.17KB read
          Socket errors: connect 0, read 9, write 0, timeout 0
        Requests/sec:    449.85
        Transfer/sec:    198.78KB
        ```

- 连接池
    + 在 OpenResty 中,所有具备 set_keepalive 的类、库函数,说明他都是支持连接池的。
    
    ```lua
    server {
    location /test {
        content_by_lua_block {
            local redis = require "resty.redis"
            local red = redis:new()
            local ok, err = red:connect("127.0.0.1", 6379)
            if not ok then
                ngx.say("failed to connect: ", err)
            return end
            ok, err = red:set("dog", "an animal")
            if not ok then
                -- red:set_keepalive(10000, 100) cannot
                return 
            end
            red:set_keepalive(10000, 100) -- correct
            }
        }
    }

    ```

- 火焰图
    + 火焰图是定位疑难杂症的神器,比如 CPU 占用高、内存泄漏等问题。特别是 Lua 级别的火焰 图,可以定位到函数和代码级别。
    + [example](http://openresty.org/download/user-flamegraph.svg)
    + 颜色是随机选取的,并没有特殊含义
    + 火焰图的数据来源,是通过systemtap定期收集
    + 定位问题
        * 安装SystemTap
        * 获取 CPU 异常的 worker 的进程 ID
        * 使用 lj-lua-stacks.sxx抓取栈信息,并用 fix-lua-bt 工具处理
        * 使用 stackcollapse-stap.pl 和 flamegraph.pl
    + 一般来说一个正常的火焰图看起来像一座座连绵起伏的“山峰”,而一个异常的火焰图看 起来像一座“平顶山”

- ngx.location.capture_multi
    + 利用 ngx.location.capture_multi 函数,直接完成了两个子请求并行执行。当两个请求没有 相互依赖,这种方法可以极大提高查询效率。
    + 假设两个无依赖请求,各自是100ms,顺序执行需要200ms,但通过并行执行可以在100ms 完成两个请求。
    
```lua
location = /sum {
    internal;
    content_by_lua_block {
        ngx.sleep(0.1)
        local args = ngx.req.get_uri_args()
        ngx.print(tonumber(args.a) + tonumber(args.b))
    }
}

location = /subduction {
    internal;
    content_by_lua_block {
        ngx.sleep(0.1)
        local args = ngx.req.get_uri_args()
        ngx.print(tonumber(args.a) - tonumber(args.b))
    }
}

location = /app/test_parallels {
    content_by_lua_block {
        local start_time = ngx.now()
        local res1, res2 = ngx.location.capture_multi( {
                        {"/sum", {args={a=3, b=8}}},
                        {"/subduction", {args={a=3, b=8}}}
                    })
        ngx.say("status:", res1.status, " response:", res1.body)
        ngx.say("status:", res2.status, " response:", res2.body)
        ngx.say("time used:", ngx.now() - start_time)
    }
}

location = /app/test_queue {
    content_by_lua_block {
        local start_time = ngx.now()
        local res1 = ngx.location.capture_multi( {
                        {"/sum", {args={a=3, b=8}}}
                    })
        local res2 = ngx.location.capture_multi( {
                        {"/subduction", {args={a=3, b=8}}}
                    })
        ngx.say("status:", res1.status, " response:", res1.body)
        ngx.say("status:", res2.status, " response:", res2.body)
        ngx.say("time used:", ngx.now() - start_time)
    }
}
```

```sh
➜ ~ curl 127.0.0.1/app/test_parallels status:200 response:11
status:200 response:-5
time used:0.10099983215332
➜ ~ curl 127.0.0.1/app/test_queue status:200 response:11
status:200 response:-5
time used:0.20199990272522
```

- ngx.req.read_body()
```lua
location /print_param {
   content_by_lua_block {
       local arg = ngx.req.get_uri_args()
       for k,v in pairs(arg) do
           ngx.say("[GET ] key:", k, " v:", v)
       end
    ngx.req.read_body() -- 解析 body 参数之前一定要先读取 body
    local arg = ngx.req.get_post_args()
    for k,v in pairs(arg) do
                   ngx.say("[POST] key:", k, " v:", v)
               end
    }
}
```

- ngx.encode_args()
```lua
location /test {
    content_by_lua_block {
        local res = ngx.location.capture(
                 '/print_param',
                {
                    method = ngx.HTTP_POST,
                    args = ngx.encode_args({a = 1, b = '2&'}),
                    body = ngx.encode_args({c = 3, d = '4&'})
                })
        ngx.say(res.body)
    }
}
```

- ngx.req.get_body_data() 读请求体,会偶尔出现读取不到直接返回 nil 的情况, 如果请求体尚未被读取,请先调用 ngx.req.read_body (或打开 lua_need_request_body 选项 强制本模块读取请求体,此方法不推荐)。如需要强制在内存中保存请求体,请设置 client_body_buffer_size 和 client_max_body_size 为同样大小。

- ngx.say 与 ngx.print 均为异步输出
```lua
server {
    listen    80;
    location /test {
        content_by_lua_block {
            ngx.say("hello")
            ngx.sleep(3)
            ngx.say("the world")
        } 
    }
    location /test2 {
        content_by_lua_block {
            ngx.say("hello")
            ngx.flush() -- 显式的向客户端刷新响应输出 ngx.sleep(3)
            ngx.say("the world")
        }
    }
}
```

    + 测试接口可以观察到, /test响应内容实在触发请求3s后一起接收到响应体
    + /test2 则是先收到一个 hello 停顿 3s 后又接收到后面的 the world

- 利用HTTP1.1特性CHUNKED编码来完成响应体过大的输出
```lua
location /test {
    content_by_lua_block {
        -- ngx.var.limit_rate = 1024*1024
        local file, err = io.open(ngx.config.prefix() .. "data.db","r")
        if not file then
            ngx.log(ngx.ERR, "open file error:", err)
            ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
        end
        local data
        while true do
            data = file:read(1024)
            if nil == data then break end
            ngx.print(data)
            ngx.flush(true)
        end
        file:close()
    }
}
```

- ngx.print,它的输入参数可以是单个或多个字符串参数,也可以是table对象

- ngx.log
    + ngx.log(log_level, msg)
    + ngx.STDERR  -- 标准输出
    + ngx.EMERG  -- 紧急报错
    + ngx.ALERT  -- 报警
    + ngx.CRIT  -- 严重,系统故障,触发运维告警系统
    + ngx.ERR  -- 错误,业务不可恢复性错误
    + ngx.WARN  -- 警告,业务中可忽略错误
    + ngx.NOTICE  -- 提醒,业务比较重要信息
    + ngx.INFO  -- 信息,业务琐碎日志信息,包含不同情况判断等
    + ngx.DEBUG  -- 调试

- lua-resty-logger-socket 
    + lua-resty-logger-socket 的目标是替代Nginx标准的 ngx_http_log_module 以非阻塞IO 方式推送access log到远程服务器上
    + 对远程服务器的要求是支持 syslog-ng 的日志服务
    + 基于 cosocket 非阻塞 IO 实现
    + 日志累计到一定量,集体提交,增加网络传输利用率
    + 短时间的网络抖动,自动容错
    + 日志累计到一定量,如果没有传输完毕,直接丢弃
    + 日志传输过程完全不落地,没有任何磁盘 IO 消耗

```lua
server {
    location / {
        log_by_lua '
            local logger = require "resty.logger.socket"
            if not logger.initted() then
                local ok, err = logger.init{
                    host = 'xxx',
                    port = 1234,
                    flush_limit = 1234,
                    drop_limit = 5678,
                }
                if not ok then
                    ngx.log(ngx.ERR, "failed to initialize the logger: ",
                            err)
                return end
            end
            -- construct the custom access log message in
            -- the Lua variable "msg"
            local bytes, err = logger.log(msg)
            if err then
                ngx.log(ngx.ERR, "failed to log message: ", err)
            return end
        ';
    }
}
```

- simple blacklist
```lua
access_by_lua_block {
    local black_ips = {["127.0.0.1"]=true}
    local ip = ngx.var.remote_addr
    if true == black_ips[ip] then
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
};
```

- limit_rate
    + 能完成传输速率限制,并且它的影响是单个请求级别

```lua
location /download {
    access_by_lua_block {
        ngx.var.limit_rate = 1000
    };
}
```

- ngx.location.capture & ngx.location.capture_multi 
    + 可以发起非阻塞的内部请求访问目标 location
    + 子请求只是模拟 HTTP 接口的形式, 没有额外的 HTTP/TCP 流量,也没有 IPC (进程间通信) 调用
    + 所有工作在内部高效地在 C 语言级别完成
    + 总是缓冲整个请求体到内存中。因此,当需要处理一个大的子请求响应,用户程序应使用 cosockets 进行流式处理
    + 默认继承当前请求的所有请求头信息, 通过设置 proxy_pass_request_headers 为 off ,在子请求 location 中忽略原始请求头
    + 子请求不允许类似 @foo 命名 location。请使用标准 location,并设置 internal 指令,仅服务内部请求
    + 无法抓取包含以下指令的 location: 
        * add_before_body
        * add_after_body
        * auth_request
        * echo_location
        * echo_location_async
        * echo_subrequest
        * echo_subrequest_async

```lua
res = ngx.location.capture(uri)
-- 返回一个包含四个元素的 Lua 表 ( res.status, res.header, res.body 和 res.truncated)

res = ngx.location.capture(
    '/foo/bar',
    { method = ngx.HTTP_POST, body = 'hello, world' }
)

ngx.location.capture('/foo?a=1',
    { args = { b = 3, c = ':' } }
)
```

- 不同阶段共享变量: ngx.ctx 表
    + 单个请求内的 rewrite (重写),access (访问),和 content (内容) 等各处理阶段是保持一致的
    + 每个请求,包括子请求,都有一份自己的 ngx.ctx 表
    + ngx.ctx 表查询需要相对昂贵的元方法调用,这比通过用户自己的函数参数直接传递基于请求的数据要慢得多
    + 不要为了节约用户函数参数而滥用此 API,因为它可能对性能有明显影响

- 防止 SQL 注入
    + MySQL,调用 ndk.set_var.set_quote_sql_str
    + PostgreSQL,调用 ndk.set_var.set_quote_pgsql_str

- 高效的与其他 HTTP Server 调用
    + ngx.location.capture + proxy_pass
    
    ```
    server {
        listen    80;
        location /test {
            content_by_lua_block {
                ngx.req.read_body()
                local args, err = ngx.req.get_uri_args()
                local res = ngx.location.capture('/spe_md5',
                {
                    method = ngx.HTTP_POST,
                    body = args.data
                })
                if 200 ~= res.status then
                    ngx.exit(res.status)
                end
                if args.key == res.body then
                    ngx.say("valid request")
                else
                    ngx.say("invalid request")
                end
            }
        }
        location /spe_md5 {
            proxy_pass http://md5_server;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }
    }

    server {
        listen 81;
        location /spe_md5 {
            content_by_lua_block {
                ngx.req.read_body()
                local data = ngx.req.get_body_data()
                ngx.print(ngx.md5(data .. "*&^%$#$^&kjtrKUYG"))
            }
        }
    }
    ```
    + cosocket
    
    ```lua
    http {
        server {
            listen 80;
            location /test {
                content_by_lua_block {
                    ngx.req.read_body()
                    local args, err = ngx.req.get_uri_args()
                    local http = require "resty.http" -- 1 local httpc = http.new()
                    local res, err = httpc:request_uri( -- 2
                        "http://127.0.0.1:81/spe_md5",
                            {
                            method = "POST",
                            body = args.data,
                          })
                    if 200 ~= res.status then
                        ngx.exit(res.status)
                    end
                    if args.key == res.body then
                        ngx.say("valid request")
                    else
                        ngx.say("invalid request")
                    end
                }
            }
        }

        server {
            listen    81;
            location /spe_md5 {
                content_by_lua_block {
                    ngx.req.read_body()
                    local data = ngx.req.get_body_data()
                    ngx.print(ngx.md5(data .. "*&^%$#$^&kjtrKUYG"))
                }
            }
        }
    }
    ```
    + 如果你的内部请求比较少,使用 ngx.location.capture + proxy_pass 的方式还没什么问题
    + 如果你的请求数量比较多,或者需要频繁的修改上游地址,那么 resty.http 就更适合你

－ 有授权验证的 Redis 池
    + 从连接池中获取的连接都是经过授权认证的,只有新创建的连接才需要进行授权认证
    + getreusedtimes() 方法,如果当前连接不是从内建连接池中获取的, 该方法总是返回 0; 如果连接来自连接池,那么返回值永远都是非零

```lua
server {
    location /test {
        content_by_lua_block {
            local redis = require "resty.redis"
            local red = redis:new()
            red:set_timeout(1000) -- 1 sec
            local ok, err = red:connect("127.0.0.1", 6379)
            if not ok then
                ngx.say("failed to connect: ", err)
            return end
            
            -- 请注意这里 auth 的调用过程
            local count
            count, err = red:get_reused_times()
            if 0 == count then
                ok, err = red:auth("password")
                if not ok then
                    ngx.say("failed to auth: ", err)
                return end
            elseif err then
                ngx.say("failed to get reused times: ", err)
                return
            end
            
            ok, err = red:set("dog", "an animal")
            if not ok then
                ngx.say("failed to set dog: ", err)
            return end
            ngx.say("set result: ", ok)
            
            -- 连接池大小是100个,并且设置最大的空闲时间是 10 秒 
            local ok, err = red:set_keepalive(10000, 100)
            if not ok then
                ngx.say("failed to set keepalive: ", err)
            return end
        }
    }
}
```

- redis pipeline
    + pipeline 机制将多个命令汇聚到一个请求中,可以有效减少请求数量,减少网络延时
    + 正确使用 pipeline 对性能的提升十分明显

```lua
server {
    location /withoutpipeline {
       content_by_lua_block {
            local redis = require "resty.redis"
            local red = redis:new()
            red:set_timeout(1000) -- 1 sec
            -- or connect to a unix domain socket file listened
            -- by a redis server:
            --     local ok, err = red:connect("unix:/path/to/redis.sock")
            local ok, err = red:connect("127.0.0.1", 6379)
            if not ok then
                ngx.say("failed to connect: ", err)
                return 
            end
            local ok, err = red:set("cat", "Marry")
            ngx.say("set result: ", ok)
            local res, err = red:get("cat")
            ngx.say("cat: ", res)
            ok, err = red:set("horse", "Bob")
            ngx.say("set result: ", ok)
            res, err = red:get("horse")
            ngx.say("horse: ", res)
            -- put it into the connection pool of size 100,
            -- with 10 seconds max idle time
            local ok, err = red:set_keepalive(10000, 100)
            if not ok then
                ngx.say("failed to set keepalive: ", err)
                return
            end
        }
    }

    location /withpipeline {
        content_by_lua_block {
            local redis = require "resty.redis"
            local red = redis:new()
            red:set_timeout(1000) -- 1 sec
            -- or connect to a unix domain socket file listened
            -- by a redis server:
            --     local ok, err = red:connect("unix:/path/to/redis.sock")
            local ok, err = red:connect("127.0.0.1", 6379)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end
            red:init_pipeline()
            red:set("cat", "Marry")
            red:set("horse", "Bob")
            red:get("cat")
            red:get("horse")
            local results, err = red:commit_pipeline()
            if not results then
                ngx.say("failed to commit the pipelined requests: ", err)
                return
            end

            for i, res in ipairs(results) do
                if type(res) == "table" then
                    if not res[1] then
                        ngx.say("failed to run command ", i, ": ", res[2])
                    else
                        -- process the table value
                    end
                else
                        -- process the scalar value
                end
            end
            -- put it into the connection pool of size 100,
            -- with 10 seconds max idle time
            local ok, err = red:set_keepalive(10000, 100)
            if not ok then
                ngx.say("failed to set keepalive: ", err)
                return
            end
        }
    }
}
```

- 从pipeline,我们知道对于多个简单的 Redis 命令可以汇聚到一个请求中,提升服务端的并发能力。然而,在有些场景下,我们每次命令的输入需要引用上个命令的输出,甚至可能还要对第一个命令的输出做一些加工,再把加工结果当成第二个命令的输入。pipeline 难以处 理这样的场景。庆幸的是,我们可以用Redis 里的 script 来压缩这些复杂命令, 核心思想是在 Redis 命令里嵌入 Lua脚本,来实现一些复杂操作:
```lua
server {
    location /usescript {
        content_by_lua_block {
            local redis = require "resty.redis"
            local red = redis:new()
            red:set_timeout(1000) -- 1 sec
            -- or connect to a unix domain socket file listened
            -- by a redis server:
            --     local ok, err = red:connect("unix:/path/to/redis.sock")
            local ok, err = red:connect("127.0.0.1", 6379)
            if not ok then
                ngx.say("failed to connect: ", err)
            return end
            --- use scripts in eval cmd
            local id = "1"
            ok, err = red:eval([[
                local info = redis.call('get', KEYS[1])
                info = json.decode(info)
                local g_id = info.gid
                local g_info = redis.call('get', g_id)
                return g_info
                ]], 1, id)
            if not ok then
               ngx.say("failed to get the group info: ", err)
               return
            end
            -- put it into the connection pool of size 100,
            -- with 10 seconds max idle time
            local ok, err = red:set_keepalive(10000, 100)
            if not ok then
                ngx.say("failed to set keepalive: ", err)
            return end
            -- or just close the connection right away:
            -- local ok, err = red:close()
            -- if not ok then
            --     ngx.say("failed to close: ", err)
            --     return
            -- end
        }
    }
}
```

- cjson.safe
    + 该接口兼容 cjson 模块,并且在解析错误时不抛出异常,而是返回 nil 
```lua
local json = require("cjson.safe")
local str  = [[ {"key:"value"} ]]
local t    = json.decode(str)
if t then
    ngx.say(" --> ", type(t))
end
```

- cjson handles empty
```lua
-- 内容节选lua-cjson-2.1.0.2/tests/agentzh.t
=== TEST 1: empty tables as objects
--- lua
local cjson = require "cjson"
print(cjson.encode({}))
print(cjson.encode({dogs = {}}))
--- out
{}
{"dogs":{}}
=== TEST 2: empty tables as arrays
--- lua
local cjson = require "cjson"
cjson.encode_empty_table_as_object(false)
print(cjson.encode({}))
print(cjson.encode({dogs = {}}))
--- out
[]
{"dogs":[]}
```

- lua sparse table
```lua
local json = require("cjson")
local data = {1, 2}
data[1000] = 99
-- ... do the other things
ngx.say(json.encode(data)) -- exception!!
```
如果把 data 的数组下标修改成5,那么这个 json.encode 就会是成功的。 结果是:[1, 2,null, null, 99], 为什么下标是1000就失败呢?实际上这么做是cjson想保护你的内存资源。她担心这个下标 过大直接撑爆内存(贴心小棉袄啊)。如果我们一定要让这种情况下可以 encode,就要尝试 **encode_sparse_array** api 了。

- ngx_postgres 模块使用方法
```
upstream pg_server {
    postgres_server 192.168.1.2:5432 dbname=pg_database user=postgres password=postgres;
    postgres_keepalive max=800 mode=single overflow=reject;
}

location /postgres {
    internal;
    default_type text/html;
    set_by_lua $query_sql 'return ngx.unescape_uri(ngx.var.arg_sql)';
    postgres_pass   pg_server;
    rds_json          on;
    rds_json_buffer_size 16k;
    postgres_query  $query_sql;
    postgres_connect_timeout 1s;
    postgres_result_timeout 2s;
}
```

```lua
local json = require "cjson"
function test()
    local res = ngx.location.capture('/postgres',
        { args = {sql = "SELECT * FROM test" } }
    )
    local status = res.status
    local body = json.decode(res.body)
    if status == 200 then
        status = true
    else
        status = false
    end
    return status, body
end
```

警示,能转到 lua-resty- 这个方向的,就千万不要和 ngx_c_module玩, ngx_c_module的扩展性、可维护性、升级等各方面都没有 lua-resty- 好

WRONG example:
```lua
    local json = require "cjson"
    function db_exec(sql_str)
        local res = ngx.location.capture('/postgres',
            { args = {sql = sql_str } }
        )
        local status = res.status
        local body = json.decode(res.body)
        if status == 200 then
            status = true
        else
            status = false
        end
        return status, body
    end
-- 转账操作,对ID=100的用户加10,同时对ID=200的用户减10。
?    local status
?    status = db_exec("BEGIN")
?    ...
?    db_exec("COMMIT")
```
- 数据库的事物成功执行,事物相关的所有操作是必须执行在一条连接上的
- 高并发下这个事物的每个 SQL 语句都可能落在不同的连接上, 因为通过 ngx.location.capture 跳转到 /postgres 小节后 Nginx 每次都会从连接池中挑选一条空闲连接,而当时哪条连接是空闲的,完全没法预估。
- 同样的道理,我们推理到 DrizzleNginxModule、RedisNginxModule、Redis2NginxModule ,他们都是无法做到在两次连续请求落到同一个连接上的
- 生产中最好用 lua-resty-* 这类的库

- Openresty 执行阶段
```lua
location /mixed {
    set_by_lua $a 'ngx.log(ngx.ERR, "set_by_lua")';
    rewrite_by_lua 'ngx.log(ngx.ERR, "rewrite_by_lua")'; 
    access_by_lua 'ngx.log(ngx.ERR, "access_by_lua")'; 
    header_filter_by_lua 'ngx.log(ngx.ERR, "header_filter_by_lua")'; body_filter_by_lua 'ngx.log(ngx.ERR, "body_filter_by_lua")';
    log_by_lua 'ngx.log(ngx.ERR, "log_by_lua")';
    content_by_lua 'ngx.log(ngx.ERR, "content_by_lua")';
}

-- logs:
set_by_lua
rewrite_by_lua
access_by_lua
content_by_lua
header_filter_by_lua
body_filter_by_lua
log_by_lua
```

set_by_lua: 流程分支处理判断变量初始化
rewrite_by_lua: 转发、重定向、缓存等功能(例如特定请求代理到外网)
access_by_lua: IP 准入、接口权限等情况集中处理(例如配合 iptable 完成简单防火墙) content_by_lua: 内容生成
header_filter_by_lua: 应答 HTTP 过滤处理(例如添加头部信息)
body_filter_by_lua: 应答 BODY 过滤处理(例如完成应答内容统一成大写)
log_by_lua: 会话完成后本地异步完成日志记录(日志可以记录在本地,还可以同步到其他机器)

实际上我们只使用其中一个阶段 content_by_lua,也可以完成所有的处理。但这样做,会让 我们的代码比较臃肿,越到后期越发难以维护。把我们的逻辑放在不同阶段,分工明确,代码独立,后期发力可以有很多有意思的玩法。举一个例子,如果在最开始的开发中,使用的是 http 明文协议,后面需要修改为 aes 加密协 议,利用不同的执行阶段,我们可以非常简单的实现:
```lua
-- 明文协议版本 
location /mixed {
    content_by_lua '...';
}

-- 加密协议版本
location /mixed {
    access_by_lua '...';  -- 请求加密解码
    content_by_lua '...';  -- 请求处理,不需要关心通信协议
    body_filter_by_lua '...';  -- 应答加密编码
}
```

- 在 OpenResty 里面选择使用库的时候,有一个基本的原则:尽量使用 OpenResty 的库函
数,尽量不用 Lua 的库函数,因为 Lua 的库都是同步阻塞的。

- FFI
    + The FFI library allows calling external C functions and using C data structures from pure Lua code.

```lua
local ffi = require("ffi")
if ffi.os == "Windows" then
    print("windows")
elseif ffi.os == "OSX" then
    print("MAC OS X")
else
    print(ffi.os)
end
```

```lua
local ffi = require("ffi")
ffi.cdef[[
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen,
          const uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen,
           const uint8_t *source, unsigned long sourceLen);
]]
local zlib = ffi.load(ffi.os == "Windows" and "zlib1" or "z")

local function compress(txt)
  local n = zlib.compressBound(#txt)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.compress2(buf, buflen, txt, #txt, 9)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

local function uncompress(comp, n)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.uncompress(buf, buflen, comp, #comp)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

-- Simple test code.
local txt = string.rep("abcd", 1000)
print("Uncompressed size: ", #txt)
local c = compress(txt)
print("Compressed size: ", #c)
local txt2 = uncompress(c, #txt)
assert(txt2 == txt)
```

- ngx_lua 的三种变量范围
     + 进程间:所有 Nginx 的工作进程共享变量,使用指令 lua_shared_dict 定义, ngx.shared.DICT 的实现是采用红黑树实现,当申请的缓存被占用完后如果有新数据需要存储 则采用 LRU 算法淘汰掉“多余”数据。
     + 进程内: Lua 源码中声明为全局变量,就是声明变量的时候不使用 local 关键字,这样的变量在同一个进程内的所有请求都是共享的. 关于进程的变量,有两个前提条件,一是 ngx_lua 使用 LuaJIT 编译,二是声明全局变量的模块是 require 引用。LuaJIT 会缓存模块中的全局变量. **建议不要使用模块中的全局变量，最好使用 ngx.ctx 或 shared dict 替代**
     + 每个请求: Lua 源码中声明变量的时候使用 local 关键字,和 ngx.ctx 类似,变量的生命周期只存在同一个请求中

- 如何引用第三方 resty 库
    + OpenResty 引用第三方 resty 库非常简单,只需要将相应的文件拷贝到 resty 目录下即可。
    + 我们以 resty.http ( pintsized/lua-resty-http) 库为例。只要将 lua-resty-http/lib/resty/ 目录下的 http.lua 和 http_headers.lua 两个文件拷贝到 /usr/local/openresty/lualib/resty 目录下即可(假设你的 OpenResty 安装目录为 /usr/local/openresty )。

    验证代码如下:

    ```lua
    server {
        listen       8080 default_server;
        server_name  _;
        resolver 8.8.8.8;
        location /google {
            content_by_lua_block {
                local http = require "resty.http"
                local httpc = http.new()
                local res, err = httpc:request_uri("http://www.google.com")
                if res.status == ngx.HTTP_OK then
                    ngx.say(res.body)
                else
                    ngx.exit(res.status)
                end
            }
        }
    }
    ```

    + 访问 http://127.0.0.1:8080/google, 如果出现的是google的首页,说明你配置成功了。当然这里也可以自定义 lua_package_path 指定 Lua 的查找路径,这样就可以把第三方代码放到相应的位置下,这么做更加方便归类文件,明确什么类型的文件放到什么地方(比如: 公共文件、业务文件)。

- cosocket example
    + 同步: 做完一件事再去做另一件; 异步:同时做多件事情,某个事情有结果了再去处理
    + 非阻塞: 有结果我就带走, 没结果我就空手而回; 阻塞:不等到想要的结果我就不走了
    + 全双工
```lua
location /test {
    resolver 8.8.8.8;
    content_by_lua_block {
        local sock = ngx.socket.tcp()
        local ok, err = sock:connect("www.google.com", 80)
        if not ok then
            ngx.say("failed to connect to google: ", err)
        return end
        local req_data = "GET / HTTP/1.1\r\nHost: www.google.com\r\n\r\n"
        local bytes, err = sock:send(req_data)
        if err then
            ngx.say("failed to send to google: ", err)
        return end
        local data, err, partial = sock:receive()
        if err then
            ngx.say("failed to recieve to google: ", err)
        return end
        sock:close()
        ngx.say("successfully talk to google! response first line: ", data)
    }
}
 
```
