#!/usr/bin/env bash

# ===========================
# LOKI - NGINX Machine Configurator
# ===========================

VERSION=1.1.0

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

log() { echo -e "${BLUE}[loki]${RESET} $1"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
ok() { echo -e "${GREEN}$1${RESET}"; }
warn() { echo -e "${YELLOW}$1${RESET}"; }
err() { echo -e "${RED}$1${RESET}" >&2; }

get_active() { [ -f "$ACTIVE_FILE" ] && cat "$ACTIVE_FILE"; }
set_active() { echo "$1" > "$ACTIVE_FILE"; }

detect_nginx_conf_dir() {
  log "Detecting nginx configuration directory..."
  
  # Run nginx -t and capture output
  if ! output=$(sudo nginx -t 2>&1); then
    log "nginx -t returned error, but will try to parse config path anyway"
  fi
  
  log "nginx -t output: $output"
  
  # Parse the configuration file path from output
  local nginx_conf=""
  if echo "$output" | grep -q "configuration file"; then
    nginx_conf=$(echo "$output" | grep "configuration file" | sed -E 's/.*configuration file ([^ ]+nginx\.conf).*/\1/')
  fi
  
  if [ -n "$nginx_conf" ] && [ -f "$nginx_conf" ]; then
    conf_dir=$(dirname "$nginx_conf")
    log "Found nginx config: $nginx_conf"
    log "Resolved conf directory: $conf_dir"
    # ONLY output the directory path, no logs
    echo "$conf_dir"
    return 0
  fi
  
  # Fallback to common paths
  warn "Could not detect nginx config path automatically, trying common paths"
  for path in "/opt/homebrew/etc/nginx" "/usr/local/etc/nginx" "/etc/nginx"; do
    if [ -d "$path" ]; then
      log "Using fallback path: $path"
      # ONLY output the directory path, no logs
      echo "$path"
      return 0
    fi
  done
  
  err "Could not detect nginx conf.d directory"
  return 1
}

# ---------- Commands ----------

cmd_init() {
  log "Initializing LOKI home at $LOKI_HOME"

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
  echo "DEBUG: cmd_connect called with argument: '$1'"
  local name="$1"
  [ -z "$name" ] && { err "Usage: loki connect <machine>"; exit 1; }
  [ ! -f "$CONF_PATH" ] && { err "machine.json not found. Run 'loki init' first."; exit 1; }
  
  log "Attempting to connect to machine: $name"
  log "Checking if machine exists in config..."
  
  if jq -e ".\"$name\"" "$CONF_PATH" >/dev/null; then
    log "Machine found in config, proceeding with connection..."
    set_active "$name"
    
    # Generate nginx config for the connected machine
    ip=$(jq -r ".\"$name\".ip" "$CONF_PATH")
    services=$(jq -r ".\"$name\".services | keys[]" "$CONF_PATH")

    log "Generating NGINX config for $name ($ip)"
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

    log "✅ Generated NGINX config for $name ($ip)"
    echo "DEBUG: This should appear on console - Generated config for $name"

    # Detect nginx conf directory and copy config
    echo "DEBUG: About to detect nginx conf dir..."
    local conf_dir
    if ! conf_dir=$(detect_nginx_conf_dir 2>/dev/null); then
      err "Could not detect nginx conf.d directory"
      exit 1
    fi
    echo "DEBUG: detect_nginx_conf_dir returned: '$conf_dir'"
    
    # Clean up the conf_dir - remove any log messages that might have been captured
    conf_dir=$(echo "$conf_dir" | tail -1 | tr -d '[:space:]')
    log "Detected nginx conf directory: $conf_dir"
    dest="$conf_dir/remote.conf"
    
    # Test nginx config before copying
    log "Testing current nginx configuration..."
    if ! sudo nginx -t; then
      err "Current nginx configuration has errors"
      exit 1
    fi
    
    # Copy new config and test
    log "Copying remote.conf to: $dest"
    echo "DEBUG: Source file: $TMP_CONF"
    echo "DEBUG: Destination: $dest"
    echo "DEBUG: Source file exists: $([ -f "$TMP_CONF" ] && echo "YES" || echo "NO")"
    echo "DEBUG: Destination directory exists: $([ -d "$conf_dir" ] && echo "YES" || echo "NO")"
    
    if sudo cp "$TMP_CONF" "$dest"; then
        echo "DEBUG: Copy successful"
    else
        echo "DEBUG: Copy failed with exit code: $?"
        exit 1
    fi
    
    log "Testing nginx configuration with new remote.conf..."
    if ! sudo nginx -t; then
      err "New nginx configuration has errors, removing remote.conf"
      sudo rm -f "$dest"
      exit 1
    fi
    
    # Restart nginx and test again
    log "Reloading nginx..."
    if sudo nginx -s reload; then
      log "Nginx reload successful"
    else
      err "Nginx reload failed"
      exit 1
    fi
    
    log "Final nginx configuration test..."
    if sudo nginx -t; then
      ok "✅ Connected to: $name and nginx reloaded successfully"
    else
      err "Nginx configuration test failed after reload"
      exit 1
    fi
  else
    err "Machine '$name' not found in $CONF_PATH"
    exit 1
  fi
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
  log "🔍 Checking services for $active"
  jq -r ".\"$active\".services | to_entries[] | \"\(.key) \(.value.local)\"" "$CONF_PATH" |
    while read -r name port; do
      echo -n "  $name (localhost:$port): "
      
      # Use curl with more options to get detailed status
      response=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port" 2>/dev/null)
      curl_exit_code=$?
      
      if [ $curl_exit_code -eq 0 ]; then
        if [ "$response" = "200" ]; then
          ok "Up (HTTP $response)"
        else
          warn "Up (HTTP $response)"
        fi
      else
        case $curl_exit_code in
          6)  err "Down (Cannot resolve host)" ;;
          7)  err "Down (Connection refused)" ;;
          28) err "Down (Timeout)" ;;
          52) err "Down (Empty reply from server)" ;;
          56) err "Down (Connection reset)" ;;
          *)  err "Down (curl error: $curl_exit_code)" ;;
        esac
      fi
    done
}

cmd_refresh() {
  local withConfig=true
  # Parse flags
  while [[ $# -gt 0 ]]; do
    case $1 in
      --no-withConfig)
        withConfig=false
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  active=$(get_active)
  [ -z "$active" ] && { err "No active machine"; exit 1; }
  [ ! -f "$CONF_PATH" ] && { err "machine.json not found"; exit 1; }

  ip=$(jq -r ".\"$active\".ip" "$CONF_PATH")
  services=$(jq -r ".\"$active\".services | keys[]" "$CONF_PATH")

  log "Generating NGINX config for $active ($ip)"
  {
    # Always generate the header comment
    echo "# Auto-generated remote.conf for $active ($ip) [$(date '+%Y-%m-%d %H:%M:%S')]"
    
    # Only generate service configs if withConfig is true
    if [ "$withConfig" = true ]; then
      for s in $services; do
        local_port=$(jq -r ".\"$active\".services.\"$s\".local" "$CONF_PATH")
        remote_port=$(jq -r ".\"$active\".services.\"$s\".remote" "$CONF_PATH")
        
        # Only add config if ports are valid
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
  
  # Test nginx config before copying
  log "Testing nginx configuration..."
  if ! sudo nginx -t >/dev/null 2>&1; then
    err "Current nginx configuration has errors"
    # exit 1
  fi
  
  sudo cp "$TMP_CONF" "$dest"
  
  # Test nginx config after copying
  log "Testing nginx configuration with new remote.conf..."
  if ! sudo nginx -t >/dev/null 2>&1; then
    err "New nginx configuration has errors, removing remote.conf"
    sudo rm -f "$dest"
    exit 1
  fi
  
  sudo nginx -s reload >/dev/null 2>&1
  ok "✅ Reloaded NGINX with new config for $active"
}

cmd_refetch() {
  ssh_user="${LOKI_SSH_USER:-root}"
  ssh_host="${LOKI_SSH_HOST:?Please set LOKI_SSH_HOST in .bashrc/.zshrc}"
  ssh_port="${LOKI_SSH_PORT:-22}"
  remote_path="${LOKI_REMOTE_MACHINES_JSON:-/mnt/machines.json}"

  log "Fetching machines.json from $ssh_user@$ssh_host:$remote_path ..."
  scp -P "$ssh_port" "$ssh_user@$ssh_host:$remote_path" "$CONF_PATH"
  ok "✅ Updated local machines.json"
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
