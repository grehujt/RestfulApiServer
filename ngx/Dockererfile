FROM ubuntu

MAINTAINER grehujt kidd4212@gmail.com

ENV \
  DEBIAN_FRONTEND=noninteractive \
  TERM=xterm-color \
  OPENRESTY_VERSION=1.9.15.1

# COPY entrypoint.sh /entrypoint.sh

RUN apt-get update && \
    apt-get install -y build-essential curl git libpcre3-dev zlib1g-dev openssl libssl-dev libaio1
RUN cd /tmp && \
    git clone https://github.com/replay/ngx_http_lower_upper_case.git && \
    curl -sSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | \
    tar -xvz && \
    cd openresty-* && \
    groupadd www-nginx && useradd -s /sbin/nologin -g www-nginx www-nginx && \
    ./configure --user=www-nginx --group=www-nginx --prefix=/usr/local/openresty --with-pcre-jit --with-luajit --with-http_stub_status_module --add-module=../ngx_http_lower_upper_case && \
    make && make install && make clean && \
    cd / && rm -rf /tmp/openresty-* && \
    ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx && \
    ldconfig && \
    apt-get purge -y build-essential && apt-get autoremove -y && apt-get clean all && \
    mkdir /usr/local/openresty/nginx/lua

# ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 443 80
CMD ["/usr/local/openresty/nginx/sbin/nginx","-c","/usr/local/openresty/nginx/conf/nginx.conf"]
