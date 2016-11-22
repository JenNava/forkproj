#!/bin/bash

sudo apt-get update

# 安装依赖
sudo apt-get install docker.io wget fortune cowsay -y 
wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
echo "deb http://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
apt-get update
apt-get install cf-cli
cf install-plugin https://static-ice.ng.bluemix.net/ibm-containers-linux_x64

# 初始化环境
org=$(openssl rand -base64 8 | md5sum | head -c8)
cf login -a https://api.ng.bluemix.net
bx iam org-create $org
sleep 3
cf target -o $org
bx iam space-create dev
sleep 3
cf target -s dev
cf ic namespace set $(openssl rand -base64 8 | md5sum | head -c8)
sleep 3
cf ic init

# 生成密码
passwd=$(openssl rand -base64 8 | md5sum | head -c12)

# 创建镜像

cat << _EOF_ >Dockerfile
FROM ubuntu:14.04
RUN apt-get update && apt-get install -y \
    python-software-properties \
    software-properties-common \
 && add-apt-repository ppa:chris-lea/libsodium \
 && echo "deb http://ppa.launchpad.net/chris-lea/libsodium/ubuntu trusty main" >> /etc/apt/sources.list \
 && echo "deb-src http://ppa.launchpad.net/chris-lea/libsodium/ubuntu trusty main" >> /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y libsodium-dev python-pip

RUN pip install shadowsocks

ENTRYPOINT ["/usr/local/bin/ssserver"]
_EOF_

cf ic build -t ub:v1 . 

# 运行容器
cf ic ip bind $(cf ic ip request | cut -d \" -f 2 | tail -1) $(cf ic run -m 1024 -p 443:443 registry.ng.bluemix.net/`cf ic namespace get`/ub:v1 -p 443 -k ${passwd} -m aes-256-cfb)
