#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx iptables iptables-persistent iproute2

cat << 'EOF' > /etc/nginx/sites-available/balanceador
upstream backend_webs {
    server 172.20.1.21;
    server 172.20.1.22;
}

server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://backend_webs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF


rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/balanceador /etc/nginx/sites-enabled/

nginx -t
service nginx restart

# Seguridad / Grupo de Seguridad: Solo permitir puertos 22, 80 y 443
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -P INPUT DROP
netfilter-persistent save
