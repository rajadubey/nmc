#!/usr/bin/env bash

# ===========================
# LOKI - NGINX Machine Configurator
# ===========================
# Author: @rajadubey
# Version: 1.0.0
# License: MIT
# ===========================

VERSION=1.0.0

LOKI_HOME="$HOME/.loki"
CONF_PATH="$LOKI_HOME/machine.json"
ACTIVE_FILE="$LOKI_HOME/active"
TMP_CONF="$LOKI_HOME/remote.conf"
LOG_FILE="$LOKI_HOME/loki.log"

mkdir -p "$LOKI_HOME"

# ---------- Colors ----------
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
ok() { echo -e "${GREEN}$1${RESET}"; }
warn() { echo -e "${YELLOW}$1${RESET}"; }
err() { echo -e "${RED}$1${RESET}" >&2; }

get_active() { [ -f "$ACTIVE_FILE" ] && cat "$ACTIVE_FILE"; }
set_active() { echo "$1" > "$ACTIVE_FILE"; }

detect_nginx_conf_dir() {
  local output nginx_conf conf_dir
  
  output=$(sudo nginx -t 2>&1) || true
  
  if echo "$output" | grep -q "configuration file"; then
    nginx_conf=$(echo "$output" | grep "configuration file" | sed -E 's/.*configuration file ([^ ]+nginx\.conf).*/\1/')
  fi
  
  if [ -n "$nginx_conf" ] && [ -f "$nginx_conf" ]; then
    conf_dir=$(dirname "$nginx_conf")
    echo "$conf_dir"
    return 0
  fi
  
  for path in "/opt/homebrew/etc/nginx" "/usr/local/etc/nginx" "/etc/nginx"; do
    if [ -d "$path" ]; then
      echo "$path"
      return 0
    fi
  done
  
  return 1
}

# ---------- Commands ----------

cmd_init() {
  cmd_refetch
  touch "$LOG_FILE"
  ok "✅ LOKI initialized successfully."
}

cmd_ls() {
  [ ! -f "$CONF_PATH" ] && { err "machine.json not found. Run 'loki init' first."; exit 1; }
  active=$(get_active)
  echo "Available machines:"
  jq -r 'keys[]' "$CONF_PATH" | while read -r key; do
    if [ "$key" = "$active" ]; then
      echo -e "  * ${GREEN}${key}${RESET}"
    else
      echo "  - $key"
    fi
  done
}

cmd_connect() {
  local name="$1"
  [ -z "$name" ] && { err "Usage: loki connect <machine>"; exit 1; }
  [ ! -f "$CONF_PATH" ] && { err "machine.json not found. Run 'loki init' first."; exit 1; }
  
  if ! jq -e ".\"$name\"" "$CONF_PATH" >/dev/null; then
    err "Machine '$name' not found in $CONF_PATH"
    exit 1
  fi
  
  set_active "$name"
  
  # Generate nginx config
  ip=$(jq -r ".\"$name\".ip" "$CONF_PATH")
  services=$(jq -r ".\"$name\".services | keys[]" "$CONF_PATH")

  {
    echo "# Auto-generated remote.conf for $name ($ip) [$(date '+%Y-%m-%d %H:%M:%S')]"
    for s in $services; do
      local_port=$(jq -r ".\"$name\".services.\"$s\".local" "$CONF_PATH")
      remote_port=$(jq -r ".\"$name\".services.\"$s\".remote" "$CONF_PATH")
      echo
      echo "upstream $s {"
      echo "    server $ip:$remote_port;"
      echo "}"
      echo "server {"
      echo "    listen $local_port;"
      echo "    proxy_pass $s;"
      echo "}"
    done
  } > "$TMP_CONF"

  # Deploy config
  local conf_dir
  if ! conf_dir=$(detect_nginx_conf_dir 2>/dev/null); then
    err "Could not detect nginx conf.d directory"
    exit 1
  fi
  
  conf_dir=$(echo "$conf_dir" | tail -1 | tr -d '[:space:]')
  dest="$conf_dir/remote.conf"
  
  sudo nginx -t >/dev/null 2>&1 || { err "Current nginx configuration has errors"; exit 1; }
  sudo cp "$TMP_CONF" "$dest" || { err "Failed to copy config"; exit 1; }
  sudo nginx -t >/dev/null 2>&1 || { err "New nginx configuration has errors"; sudo rm -f "$dest"; exit 1; }
  sudo nginx -s reload >/dev/null 2>&1 || { err "Nginx reload failed"; exit 1; }
  
  ok "✅ Connected to: $name"
}

cmd_status() {
  active=$(get_active)
  [ -z "$active" ] && { warn "No active machine"; exit 0; }
  ip=$(jq -r ".\"$active\".ip" "$CONF_PATH")
  ok "📡 Active machine: $active (${ip})"
  jq -r ".\"$active\".services | to_entries[] | \" - \(.key): local=\(.value.local), remote=\(.value.remote)\"" "$CONF_PATH"
}

cmd_check() {
  active=$(get_active)
  [ -z "$active" ] && { err "No active machine"; exit 1; }
  echo "🔍 Checking services for $active"
  jq -r ".\"$active\".services | to_entries[] | \"\(.key) \(.value.local)\"" "$CONF_PATH" |
    while read -r name port; do
      echo -n "  $name (localhost:$port): "
      
      response=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port" 2>/dev/null)
      
      if [ $? -eq 0 ] && [ "$response" = "200" ]; then
        ok "Up"
      else
        err "Down"
      fi
    done
}

cmd_refresh() {
  local withConfig=true
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --no-withConfig) withConfig=false; shift ;;
      *) break ;;
    esac
  done

  active=$(get_active)
  [ -z "$active" ] && { err "No active machine"; exit 1; }
  [ ! -f "$CONF_PATH" ] && { err "machine.json not found"; exit 1; }

  ip=$(jq -r ".\"$active\".ip" "$CONF_PATH")
  services=$(jq -r ".\"$active\".services | keys[]" "$CONF_PATH")

  {
    echo "# Auto-generated remote.conf for $active ($ip) [$(date '+%Y-%m-%d %H:%M:%S')]"
    
    if [ "$withConfig" = true ]; then
      for s in $services; do
        local_port=$(jq -r ".\"$active\".services.\"$s\".local" "$CONF_PATH")
        remote_port=$(jq -r ".\"$active\".services.\"$s\".remote" "$CONF_PATH")
        
        if [ -n "$local_port" ] && [ "$local_port" != "null" ] && [ -n "$remote_port" ] && [ "$remote_port" != "null" ]; then
          echo
          echo "upstream $s {"
          echo "    server $ip:$remote_port;"
          echo "}"
          echo "server {"
          echo "    listen $local_port;"
          echo "    proxy_pass $s;"
          echo "}"
        fi
      done
    fi
  } > "$TMP_CONF"

  local conf_dir
  if ! conf_dir=$(detect_nginx_conf_dir 2>/dev/null); then
    err "Could not detect nginx conf.d directory"
    exit 1
  fi
  
  conf_dir=$(echo "$conf_dir" | tail -1 | tr -d '[:space:]')
  dest="$conf_dir/remote.conf"
  
  sudo nginx -t >/dev/null 2>&1 || warn "Current nginx configuration has issues"
  sudo cp "$TMP_CONF" "$dest"
  
  if ! sudo nginx -t >/dev/null 2>&1; then
    err "New nginx configuration has errors, removing remote.conf"
    sudo rm -f "$dest"
    exit 1
  fi
  
  sudo nginx -s reload >/dev/null 2>&1
  ok "✅ Reloaded NGINX config for $active"
}

cmd_refetch() {
  ssh_user="${LOKI_SSH_USER:-root}"
  ssh_host="${LOKI_SSH_HOST:?Please set LOKI_SSH_HOST in .bashrc/.zshrc}"
  ssh_port="${LOKI_SSH_PORT:-22}"
  remote_path="${LOKI_REMOTE_MACHINES_JSON:-/mnt/machines.json}"

  scp -P "$ssh_port" "$ssh_user@$ssh_host:$remote_path" "$CONF_PATH" >/dev/null 2>&1
  ok "✅ Updated machines.json"
  cmd_refresh
}

cmd_break() {
  cmd_refresh --no-withConfig
  #delete active file
  rm -rf "$ACTIVE_FILE"
}


# ---------- CLI Dispatcher ----------

cmd="$1"; shift || true
case "$cmd" in
  init) cmd_init ;;
  ls) cmd_ls ;;
  connect) cmd_connect "$@" ;;
  status) cmd_status ;;
  check) cmd_check ;;
  refresh) cmd_refresh ;;
  break) cmd_break ;;
  refetch) cmd_refetch "$@" ;;
  *)
    echo "Usage: loki <command>"
    echo
    echo "Commands:"
    echo "  init                     Initialize ~/.loki"
    echo "  ls                       List all machines"
    echo "  connect <machine>         Set active machine"
    echo "  status                   Show active machine and ports"
    echo "  check                    Curl-check services on localhost"
    echo "  refresh                  Generate & reload remote.conf"
    echo "  break                    Break connection from machine"
    echo "  refetch                  Fetch machine.json via SSH using env variable"
    echo
    ok "-------------------------\nversion:$VERSION\n-------------------------"
    echo
    ;;
esac
