# Restful Api Server

### Components
- docker: virtualization and isolation
- Nginx (Openresty) docker container: https web server, load balancer
- Redis docker container: cache
- MariaDB docker container: database
- ELK docker containers: aggregate & analyze dockers' log
- monit: process monitor
- fail2ban

### Overview
> TODO

### Features
> TODO

### Project files

- [server_para_tuning.sh](./server_para_tuning.sh): Basic TCP & OS kernel parameters tunings.

- [setup_base_env.sh](./setup_base_env.sh): Setup the basic docker host environment and install ELK contains.

### Setup
> TODO

### Production environment considerations
> TODO
