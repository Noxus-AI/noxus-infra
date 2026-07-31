#!/usr/bin/env sh

# Load environment variables from /env.extra
. /env.extra
apt install -y certbot

cd /opt/docker-compose/spot
rm -rf /etc/letsencrypt
docker-compose kill nginx
certbot certonly --standalone -d $DOMAIN -m $ADMIN_EMAIL --agree-tos -n
cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem /certs/self-signed.crt
cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem /certs/self-signed.key
docker-compose up nginx -d
