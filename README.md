# Restful Api Server

### Overview
![overview](./pics/overview.png)

### Main Components
- docker: virtualization and isolation
- Nginx (Openresty) docker container: https web server, load balancer
- Redis docker container: cache
- MariaDB docker container: database
- ELK docker containers: aggregate & analyze dockers' log
- monit: process monitors

### Features
> TODO

### Project files

- [server_para_tuning.sh](./server_para_tuning.sh): Basic TCP & OS kernel parameters tunings.
- [setup_base_env.sh](./setup_base_env.sh): Setup the basic docker host environment and install ELK contains.
- [mariadb.cnf](./mariadb.cnf): the conf file for mariadb.
- [redis.conf](./redis.conf): the conf file for redis.
- [ngx](./ngx): folder containing Dockerfile & confs for nginx container.
    + [Dockerfile](./ngx/Dockerfile): the dockerfile for building the openresty image.
    + [conf](./ngx/conf): containing the conf files.
        * [nginx.conf](./ngx/conf/nginx.conf): the nginx conf file.
        * [loc.basic.conf](./ngx/conf/loc.basic.conf): some test locations for nginx.
        * [loc.cache.conf](./ngx/conf/loc.cache.conf): internal cache locations.
        * [basic.cache.conf](./ngx/conf/basic.cache.conf): shortcuts to get/put data from/to cache.
        * [loc.rest.conf](./ngx/conf/loc.rest.conf): some restful api locations
        * [loc.rest.cors.conf](./ngx/conf/loc.rest.cors.conf): restful api locations with CORS support
    + [lua](./ngx/lua): containing the lua scripts.
        * [dbinfo.lua](./ngx/lua/dbinfo.lua): module that defines the user account and related access patterns.
        * [check.all.lua](./ngx/lua/check.all.lua): checks if coming requests are legal based on the policies defined in dbinfo.lua.
        * [handle_tables.lua](./ngx/lua/handle_tables.lua): handles the (whole)table query requests.
        * [handle_tables_with_id.lua](./ngx/lua/handle_tables_with_id.lua): handles the table quert request with id.
        * [handle_tables_with_ids.lua](./ngx/lua/handle_tables_with_ids.lua): handles the table quert request with ids (more than 1 id).
        * [init.lua](./ngx/lua/init.lua): init script
        * [lbs.lua](./ngx/lua/lbs.lua): mysql connection pool and midware for mysql operations.
- [docker-lbs.yml](./docker-lbs.yml): docker-compose yml file
- [monit.conf](./monit.conf): systemd minit conf file.
- [monitrc](./monitrc): monit monitoring conf file.

### Setup
> TODO

### Production environment considerations
> TODO
