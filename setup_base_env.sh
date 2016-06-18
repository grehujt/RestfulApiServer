#!/bin/bash
set -e

apt-get install -y python-pip curl monit mariadb-client
curl -sSL https://get.docker.com | sudo sh
pip install -U docker-compose

git clone https://github.com/deviantony/docker-elk.git
docker-compose -f docker-elk/docker-compose.yml up -d
