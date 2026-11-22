#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
NOMBRE_SERVIDOR=$1

apt-get update -y
apt-get install -y apache2 php libapache2-mod-php php-mysql git iptables iptables-persistent iproute2

rm -rf /var/www/html/*
git clone https://github.com /tmp/app
cp -r /tmp/app/src/* /var/www/html/
rm -rf /tmp/app

sed -i "s/localhost/172.20.2.20/g" /var/www/html/config.php
sed -i "s/database_name_here/lamp_db/g" /var/www/html/config.php
sed -i "s/username_here/javier-lamp/g" /var/www/html/config.php
sed -i "s/password_here/1234/g" /var/www/html/config.php

sed -i "s/<body>/<body><div style='background:#222;color:#fff;padding:10px;text-align:center;'>Atendido por: <strong>$NOMBRE_SERVIDOR ($(hostname))<\/strong><\/div>/g" /var/www/html/index.php

chown -R www-data:www-data /var/www/html/
service apache2 restart
# systemctl enable apache2

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -s 172.20.1.10 --dport 80 -j ACCEPT
iptables -P INPUT DROP
netfilter-persistent save

ip route del default

cat << 'EOF' > /etc/systemd/system/no-internet.service
[Unit]
Description=Eliminar ruta por defecto para aislar Capa 2
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/sbin/ip route del default
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
