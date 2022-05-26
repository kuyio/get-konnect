#!/bin/bash

# This file is install-docker.sh

# Set terminal output
set -xe

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install docker-compose from Github releases
sudo curl -L "https://github.com/docker/compose/releases/download/2.5.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose