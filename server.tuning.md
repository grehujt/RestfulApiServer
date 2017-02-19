- fs.file-max
    + /etc/security/limits.conf

    ```sh
    * hard nofile 1025500
    * soft nofile 1025500
    ```

    + /etc/sysctl.conf

    ```sh
    fs.file-max = 1025500
    ```

    + sysctl -p
    + reboot

- net.core.somaxconn & net.core.tcp_max_syn_backlog
    + 如果有高并发的请求来进行连接,而我们的队列过小,客户端就直接连接失败。如果我们把队列扩大,那么我们的服务器 就有机会把暂时处理不了的请求,暂存起来,慢慢处理
    + 使用 ss –n –l 命令,检查 Send-Q 那一列,你就知道是否已经生效了
- tcp_syncookies
    + 开启 tcp_syncookie 可以防止syn flood攻击,同时在syn_backlog 已满的情况下,不会抛弃syn包。
    + 推荐打开
- tcp_max_tw_buckets
    + 系统中处于 timewait 状态的连接的数目
    + 建议10000
- tcp_tw_recycle
    + 用于快速回收处于 timewait 的连接。但是它和 timestamp 一起作用时可能会导致同一个 NAT 过来的连接失败。
    + 建议关闭
- timestamps
    + 为了避免它和 tcp_tw_recycle 一起导致问题, 建议关闭
- tcp_tw_reuse
    + 允许将 TIME-WAIT sockets 重新用于新的 TCP 连接
    + 建议开启
- tcp_fin_timeout
    + 如果本方关闭连接,则它在 FIN_WAIT_2 状态的时间
    + 建议改为10
- tcp_synack_retries
    + 对于远端的连接请求 SYN,服务器对应的 ack 响应的数目
    + 建议改为10
- tcp_keepalive_time tcp_keepalive_intvl tcp_keepalive_probes
    + 为了解决 TCP 的 CLOSE_WAIT 问题
    + tcp_keepalive_time:防止空连接攻击,可以缩小该值, 建议改为180
    + tcp_keepalive_intvl:当探测没有确认时,重新发送探测的频度。缺省是75秒。建议改为30秒
    + tcp_keepalive_probes:进行多少次探测,因为探测的间隔是按照指数级别增长,默认为9次。建议改为 5 次。

```sh
# sysctl -p
fs.file-max = 1025500
net.core.netdev_max_backlog = 30000
net.core.somaxconn = 10000
net.core.rps_sock_flow_entries = 32768
net.ipv4.tcp_max_syn_backlog = 10000
net.ipv4.tcp_max_tw_buckets = 10000
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_synack_retries = 10
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_keepalive_time = 180
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.ip_local_port_range = 1024 65535
```
