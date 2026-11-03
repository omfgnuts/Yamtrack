#!/usr/bin/env bash
export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/omfgnuts/Yamtrack/dev/proxmox}"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

# Adapted from community-scripts ct/yamtrack.sh by MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/omfgnuts/Yamtrack

APP="Yamtrack-omfgnuts"
var_tags="${var_tags:-media;tracker;docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"
# Only exported variables reach the install script through lxc-attach
export var_yamtrack_tag="${var_yamtrack_tag:-latest}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/yamtrack/compose.yaml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  cd /opt/yamtrack || exit

  msg_info "Pulling Images"
  for attempt in 1 2 3; do
    $STD docker compose pull && break
    if ((attempt == 3)); then
      if ! getent ahostsv4 ghcr.io >/dev/null; then
        msg_error "DNS resolution failed for ghcr.io in the container"
      else
        msg_error "Could not pull the Docker images. To see Docker's error, run:"
        echo -e "${TAB}docker compose -f /opt/yamtrack/compose.yaml pull"
      fi
      echo -e "${TAB}Troubleshooting: https://github.com/omfgnuts/Yamtrack/tree/dev/proxmox#pull-errors"
      exit 1
    fi
    sleep 15
  done
  msg_ok "Pulled Images"

  msg_info "Restarting Yamtrack"
  $STD docker compose up -d --remove-orphans
  $STD docker image prune -f
  msg_ok "Restarted Yamtrack"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:8000${CL}"
