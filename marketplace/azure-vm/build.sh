#!/usr/bin/env bash
# Azure Marketplace VM image build. Runs as root on the build VM.
#
# Required in the build environment — none of these may be baked into the image
# source, and the build fails loudly rather than silently shipping a placeholder:
#
#   DOMAIN                 hostname the appliance will be served on
#   DOCKER_HUB_USERNAME    registry account used to pull the platform images
#   DOCKER_HUB_TOKEN       access token for that account
#   AUTH0_CLIENT_ID        Auth0 application for this deployment
#   AUTH0_CLIENT_SECRET    matching client secret
set -euo pipefail

: "${DOMAIN:?DOMAIN must be set}"
: "${DOCKER_HUB_USERNAME:?DOCKER_HUB_USERNAME must be set}"
: "${DOCKER_HUB_TOKEN:?DOCKER_HUB_TOKEN must be set}"
: "${AUTH0_CLIENT_ID:?AUTH0_CLIENT_ID must be set}"
: "${AUTH0_CLIENT_SECRET:?AUTH0_CLIENT_SECRET must be set}"

apt-get update
apt-get -y install \
    git curl wget \
    apt-transport-https \
    ca-certificates \
    curl \
    jq vim \
    docker.io \
    docker-buildx \
    bash-completion \
    openssl \
    openssh-server
curl -o /usr/local/bin/docker-compose -L https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64
chmod +x /usr/local/bin/docker-compose
printf '%s' "${DOCKER_HUB_TOKEN}" | docker login -u "${DOCKER_HUB_USERNAME}" --password-stdin

mkdir -p /certs
if [ ! -f /certs/self-signed.key ]; then
  openssl req -x509 -nodes -days 730 -newkey rsa:2048 \
    -keyout /certs/self-signed.key \
    -out /certs/self-signed.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=test-vm.noxus.ai"
fi

# BOOTSTRAP DOCKER-COMPOSE
mkdir -p /tmp/bootstrap
mkdir -p /local

curl https://storage.googleapis.com/noxus-azure-install/docker-compose@.service -o /tmp/bootstrap/docker-compose@.service
curl https://storage.googleapis.com/noxus-azure-install/env.vm -o /local/env.vm
curl https://storage.googleapis.com/noxus-azure-install/nginx.conf -o /local/nginx.conf
curl https://storage.googleapis.com/noxus-azure-install/start-azure.sh -o /local/start-azure.sh
chmod +x /local/start-azure.sh

mkdir -p /opt/docker-compose/spot
sed -i 's/start.sh/start-azure.sh/g' /tmp/bootstrap/docker-compose@.service
cp -a /tmp/bootstrap/compose/* /opt/docker-compose
cp -a /tmp/bootstrap/*.service /lib/systemd/system/
if [ -f /env.vm ]; then
  AUTH0_SECRET=$(grep AUTH0_SECRET /env.vm | cut -d= -f2 | tail -n1)
else
  AUTH0_SECRET=$(openssl rand -hex 32)
fi
cat <<EOF > /env.vm
ADMIN_EMAIL=admin@noxus.ai
AUTH0_DOMAIN=noxus-oncloud.eu.auth0.com
AUTH0_BASE_URL=https://${DOMAIN}
AUTH0_ISSUER_BASE_URL=https://noxus-oncloud.eu.auth0.com
AUTH0_API_AUDIENCE=https://oncloud.noxus.ai
AUTH0_CLIENT_ID=${AUTH0_CLIENT_ID}
AUTH0_CLIENT_SECRET=${AUTH0_CLIENT_SECRET}
AUTH0_SECRET=$AUTH0_SECRET
FRONTEND_URL=https://${DOMAIN}
POSTGRESQL_URL=postgres:password@postgres:5432/spot
ON_PREM=true
BUCKET_CLIENT=azure
EOF
ln -s /env.vm /frontend.local
touch /env.extra
curl https://storage.googleapis.com/noxus-azure-install/docker-compose.yml -o /opt/docker-compose/spot/docker-compose.yml

for i in $(find /opt/docker-compose -mindepth 1 -maxdepth 1 -type d); do
  pushd "$i"
  docker-compose pull
  popd

  svc=$(basename "$i")
  systemctl enable docker-compose@$svc
  systemctl start docker-compose@$svc
done
