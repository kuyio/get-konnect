# KUY.io Konnect™ (OSS)

This repository contains open-source components for KUY.io Konnect™ VPN access server.

- `install-docker.sh` is a shell script to install Docker and `docker-compose`
- `konnect-bootstrap-ubuntu.sh` is a shell script that (if you already have Docker and `docker-compose` installed) installs Konnect™ to `/opt/konnect` on a Ubuntu 20.04 or 22.04 host
- `konnect-quickstart-ubuntu.sh` is a shell script that installs all dependencies (Docker, `docker-compose`,`wireguard` kernel modules), as well as Konenct™ to `/opt/konnect` on a blank Ubuntu 20.04 or 22.04 cloud VM
