#!/bin/bash

echo " "
read -p "This script will install KUY.io Konnect™ access server on your system. Continue? (Y/n): " choice
case $choice in
  [Nn]* ) exit;;
esac

echo " "
echo "Checking for quickstart dependencies ..."

if ! command -v curl &> /dev/null
then
  echo " "
  echo "Curl not found on the system, installing ..."
  apt install -y curl
fi

echo " "
echo "Checking for WireGuard® kernel support ..."
apt install -y wireguard wireguard-tools wireguard-dkms


echo " "
if ! command -v docker &> /dev/null
then
  echo "Docker not found on the system, installing ..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
else
  echo "Docker is present on this system, skipping installation."
fi

echo " "
if ! command -v docker-compose &> /dev/null
then
  echo "Docker Compose not found on the system, installing ..."
  curl -L "https://github.com/docker/compose/releases/download/2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
else
  echo "Docker Compose is present on this system, skipping installation."
fi

echo " "
read -p "Installation directory (/opt/konnect): " installdir
installdir=${installdir:-/opt/konnect}

echo ${installdir}
mkdir -p ${installdir}

while true; do
  echo " "
  read -p "Full-qualified hostname for this installation: " hostname
  read -p "Administrator email address: " email

  echo " "
  echo " "
  echo "Hostname:    ${hostname}"
  echo "Email:       ${email}"

  echo " "
  read -p "Is this information correct? (y/N): " yn
  case $yn in
    [Yy]* ) break;;
  esac
done

secret_key=$(openssl rand -hex 32)
db_password=$(openssl rand -hex 12)

cat <<EOT >> ${installdir}/docker-compose.yml
version: "3"
services:
  web:
    image: ghcr.io/kuyio/konnect:latest
    ports:
      - "5000:5000"
      - "51820:51820/udp"
    links:
      - db
    environment:
      PORT: 5000
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: ${db_password}
      SECRET_KEY_BASE: "${secret_key}"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv6.conf.all.disable_ipv6=0
    networks:
      - wg_internal
    volumes:
      - ./conf:/app/config/wireguard
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=wg_internal"
      - "traefik.http.services.web.loadbalancer.server.port=5000"
      - "traefik.http.routers.web.rule=Host(\`${hostname}\`)"
      - "traefik.http.routers.web.tls=true"
      - "traefik.http.routers.web.tls.certresolver=le"
    restart: always

  db:
    image: postgres:12-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${db_password}
    expose:
      - "5432"
    volumes:
      - "database:/var/lib/postgresql/data"
    networks:
      - wg_internal
    restart: always

  traefik:
    container_name: traefik
    image: traefik:v2.2
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entryPoints.web.address=:80"
      - "--entryPoints.websecure.address=:443"
      - "--certificatesResolvers.le.acme.email=${email}"
      - "--certificatesresolvers.le.acme.storage=/letsencrypt/acme.json"
      - "--certificatesResolvers.le.acme.tlsChallenge=true"
      - "--certificatesResolvers.le.acme.httpChallenge=true"
      - "--certificatesResolvers.le.acme.httpChallenge.entryPoint=web"
    restart: always
    ports:
      - 80:80
      - 443:443
      - 8080:8080
    networks:
      - wg_internal
      - konnect_wg_ingress
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./letsencrypt:/letsencrypt
    labels:
      # Redirect all HTTP to HTTPS permanently
      - traefik.http.routers.http_catchall.rule=HostRegexp(\`{any:.+}\`)
      - traefik.http.routers.http_catchall.entrypoints=web
      - traefik.http.routers.http_catchall.middlewares=https_redirect
      - traefik.http.middlewares.https_redirect.redirectscheme.scheme=https
      - traefik.http.middlewares.https_redirect.redirectscheme.permanent=true

volumes:
  database:

networks:
  wg_internal:
    external: false
  konnect_wg_ingress:
    external: true
EOT

echo " "
echo "Creating ingress routing network"
docker network create konnect_wg_ingress

echo " "
echo "Quickstart setup complete!"

echo " "
echo "You can now start your KUY.io Konnect™ VPN access server instance with:"
echo "    cd ${installdir}"
echo "    docker-compose up -d"
echo " "
