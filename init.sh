#!/bin/bash
set -e

apt-get update && apt-get install -y python-pip curl mariadb-client openssl bc
curl -sSL https://get.docker.com | sudo sh
pip install -U docker-compose

openssl req -x509 -newkey rsa:4096 -keyout ./ngx/key.pem -out ./ngx/cert.pem -days 365 -subj "/C=HK/ST=HK/L=MTREC/O=LBS/OU=UST/CN=localhost" -nodes

docker-compose up -d

sleep 20

mysql -uroot -p20rootpass17 -h127.0.0.1 mysql -e "
update user set host='127.0.0.1';
flush privileges;
create user root@localhost;
grant all on *.* to root@localhost;
grant select,update,insert,delete on *.* to lbsuser@127.0.0.1;
flush privileges;
"
mysql -uroot -p20rootpass17 -h127.0.0.1 lbs_demo_site < demo_site.sql

# chmod +x server.tuning.sh && ./server.tuning.sh
rm server.tuning.sh
chmod +x rc.local && mv rc.local /etc/
rm init.sh

reboot
