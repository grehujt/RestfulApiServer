
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
