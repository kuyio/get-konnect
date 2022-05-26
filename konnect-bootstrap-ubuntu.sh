#!/bin/bash

INSTALL_DIR=/opt/konnect
SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 12)

apt install -qqy curl
apt install -qqy wireguard wireguard-tools wireguard-dkms
mkdir -p ${INSTALL_DIR}


cat <<EOT >> ${INSTALL_DIR}/docker-compose.yml
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
      DB_PASSWORD: ${DB_PASSWORD}
      SECRET_KEY_BASE: "${SECRET_KEY}"
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
      - "traefik.http.routers.web.tls=true"
      # Self-Signed Certificate
      - "traefik.http.routers.web.rule=HostRegexp(\`{any:.+}\`)"
      # To use a Let's Encrypt Certificate, remove the web.rule above
      # and uncomment and edit the following two lines
      # - "traefik.http.routers.web.rule=Host(\`vpn.example.com\`)"
      # - "traefik.http.routers.web.tls.certresolver=le"
    restart: always

  db:
    image: postgres:12-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${DB_PASSWORD}
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
      # Uncomment and edit the following lines to enable Let's Encrypt Certificates
      # - "--certificatesResolvers.le.acme.email=YOUR_EMAIL_ADDRESS"
      # - "--certificatesresolvers.le.acme.storage=/letsencrypt/acme.json"
      # - "--certificatesResolvers.le.acme.tlsChallenge=true"
      # - "--certificatesResolvers.le.acme.httpChallenge=true"
      # - "--certificatesResolvers.le.acme.httpChallenge.entryPoint=web"
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

docker network create konnect_wg_ingress