
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
