#! /bin/sh
git -C /docker/caddy-portainer pull
docker compose --file /docker/caddy-portainer/compose.agent.yml pull
docker compose --file /docker/caddy-portainer/compose.agent.yml up --force-recreate --build -d
