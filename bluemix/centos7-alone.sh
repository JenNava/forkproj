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
mkdir ss
cd ss

cat << _EOF2_ > supervisor.sh

#!/bin/bash
easy_install supervisor
mkdir /etc/supervisord.d
echo_supervisord_conf > /etc/supervisord.conf
echo '[include]' >> /etc/supervisord.conf
echo 'files = supervisord.d/*.ini' >> /etc/supervisord.conf

cat << _EOF_ >"/etc/supervisord.d/shadowsocks.ini"
[program:shadowsocks]
command=/usr/bin/ssserver -p 443 -k ${passwd} -m aes-256-cfb
autorestart = true
_EOF_

_EOF2_


cat << _EOF_ >Dockerfile
FROM centos:centos7
RUN easy_install pip
RUN pip install shadowsocks
ADD server_linux_amd64 /usr/local/bin/server_linux_amd64
RUN chmod +x /usr/local/bin/server_linux_amd64
ADD supervisor.sh /tmp/supervisor.sh
RUN bash /tmp/supervisor.sh
EXPOSE 443
CMD ["supervisord", "-nc", "/etc/supervisord.conf"]
_EOF_

cf ic build -t ss:v1 . 

# 运行容器
cf ic ip bind $(cf ic ip request | cut -d \" -f 2 | tail -1) $(cf ic run -m 1024 --name=ss -p 443 registry.ng.bluemix.net/`cf ic namespace get`/ss:v1)

# 显示信息
while ! cf ic inspect ss | grep PublicIpAddress | awk -F\" '{print $4}' | grep -q .
do
	echo -e "\n"
	curl https://api.lwl12.com/hitokoto/main/get
	sleep 5
done
clear
echo $(echo -e "IP:"
cf ic inspect ss | grep PublicIpAddress | awk -F\" '{print $4}'
echo -e "\nPassword:\n"${passwd}"\nPort:\n443\nMethod:\nAES-256-CFB") | /usr/games/cowsay -n
