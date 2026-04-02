#! /bin/sh
git -C /docker/caddy-portainer pull
docker compose --file /docker/caddy-portainer/compose.server-ce.yml pull
docker compose --file /docker/caddy-portainer/compose.server-ce.yml up --force-recreate --build -d
