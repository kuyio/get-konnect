#!/bin/bash

# Docker Compose Version
DOCKER_COMPOSE_VERSION=2.21.0
DOCKER_PLATFORM=$(uname -s)
DOCKER_ARCH=$(uname -m)

# Set terminal output
set -xe

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install docker-compose from Github releases
sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-${DOCKER_PLATFORM,,}-${DOCKER_ARCH}" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose