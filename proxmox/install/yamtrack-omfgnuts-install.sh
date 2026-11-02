#!/usr/bin/env bash

# Adapted from community-scripts install/yamtrack-install.sh by MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/omfgnuts/Yamtrack

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

setup_docker

msg_info "Configuring Yamtrack"
mkdir -p /opt/yamtrack
TZ_NAME=$(readlink -f /etc/localtime 2>/dev/null | sed 's|^/usr/share/zoneinfo/||')
[[ -z "$TZ_NAME" || "$TZ_NAME" == /* ]] && TZ_NAME="Etc/UTC"

cat <<EOF >/opt/yamtrack/.env
# Passed to the Yamtrack container. Settings reference:
# https://github.com/FuzzyGrim/Yamtrack/blob/dev/docs/env-variables.md
# Apply changes with: cd /opt/yamtrack && docker compose up -d
YAMTRACK_TAG=${var_yamtrack_tag:-latest}
TZ=${TZ_NAME}
SECRET=$(openssl rand -hex 32)
URLS=http://${LOCAL_IP}:8000
DB_PASSWORD=$(openssl rand -hex 24)
EOF
chmod 600 /opt/yamtrack/.env

cat <<'EOF' >/opt/yamtrack/compose.yaml
services:
  yamtrack:
    image: ghcr.io/omfgnuts/yamtrack-omfgnuts:${YAMTRACK_TAG:-latest}
    container_name: yamtrack
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    env_file: .env
    environment:
      REDIS_URL: redis://redis:6379
      DB_HOST: db
      DB_NAME: yamtrack
      DB_USER: yamtrack
      DB_PORT: 5432
    ports:
      - "8000:8000"

  db:
    image: postgres:16-alpine
    container_name: yamtrack-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: yamtrack
      POSTGRES_USER: yamtrack
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U yamtrack -d yamtrack"]
      interval: 5s
      timeout: 5s
      retries: 20
    volumes:
      - ./db:/var/lib/postgresql/data

  redis:
    image: redis:8-alpine
    container_name: yamtrack-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data

volumes:
  redis_data:
EOF
msg_ok "Configured Yamtrack"

msg_info "Pulling Images"
cd /opt/yamtrack || exit
if ! $STD docker compose pull; then
  msg_error "Could not pull ghcr.io/omfgnuts/yamtrack-omfgnuts:${var_yamtrack_tag:-latest}"
  echo -e "${TAB}If the package is private, make it public at:"
  echo -e "${TAB}https://github.com/users/omfgnuts/packages/container/yamtrack-omfgnuts/settings"
  exit 1
fi
msg_ok "Pulled Images"

msg_info "Starting Yamtrack"
$STD docker compose up -d
for _ in $(seq 1 60); do
  [[ "$(docker inspect --format '{{.State.Health.Status}}' yamtrack 2>/dev/null)" == "healthy" ]] && break
  sleep 5
done
if [[ "$(docker inspect --format '{{.State.Health.Status}}' yamtrack 2>/dev/null)" == "healthy" ]]; then
  msg_ok "Started Yamtrack"
else
  msg_warn "Yamtrack is not healthy yet, check: docker compose -f /opt/yamtrack/compose.yaml logs yamtrack"
fi

motd_ssh
customize
cleanup_lxc
