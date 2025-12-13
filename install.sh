#!/bin/bash

{ # this ensures the entire script is downloaded #

LOKI_INSTALL_DIR="${LOKI_DIR:-$HOME/.loki}"
LOKI_REPO="rajadubey/loki"
LOKI_RAW_URL="https://raw.githubusercontent.com/$LOKI_REPO/1.0.1/loki.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[loki]${NC} $1"; }
ok() { echo -e "${GREEN}✅${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
err() { echo -e "${RED}❌${NC} $1" >&2; }
fatal() { err "$1"; exit 1; }

check_deps() {
  local deps=("curl" "jq") missing=()
  
  for dep in "${deps[@]}"; do
    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    warn "Missing: ${missing[*]} (install with: brew install ${missing[*]})"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || fatal "Installation aborted"
  fi
}

# Detect shell profile
detect_profile() {
  local detected_profile
  detected_profile=''
  
  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    detected_profile="${PROFILE}"
    return
  fi

  if [ -n "${BASH_VERSION-}" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      detected_profile="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      detected_profile="$HOME/.bash_profile"
    fi
  elif [ -n "${ZSH_VERSION-}" ]; then
    detected_profile="$HOME/.zshrc"
  fi

  if [ -z "$detected_profile" ]; then
    for profile in ".profile" ".bashrc" ".bash_profile" ".zshrc"; do
      if [ -f "$HOME/$profile" ]; then
        detected_profile="$HOME/$profile"
        break
      fi
    done
  fi

  echo "$detected_profile"
}

download_loki() {
  curl -fsSL -o "$LOKI_INSTALL_DIR/loki" "$LOKI_RAW_URL" || fatal "Download failed"
  chmod +x "$LOKI_INSTALL_DIR/loki"
  ok "Downloaded loki"
}

create_symlink() {
  local symlink_path="/usr/local/bin/loki"
  
  if [ -w "/usr/local/bin" ]; then
    ln -sf "$LOKI_INSTALL_DIR/loki" "$symlink_path" && ok "Created symlink"
  else
    sudo ln -sf "$LOKI_INSTALL_DIR/loki" "$symlink_path" 2>/dev/null && ok "Created symlink" || warn "Symlink failed"
  fi
}

setup_profile() {
  local profile
  profile=$(detect_profile)
  
  [ -z "$profile" ] && { warn "No shell profile found"; return; }
  
  echo ":$PATH:" | grep -q ":$LOKI_INSTALL_DIR:" && { ok "Already in PATH"; return; }
  grep -q "LOKI_DIR" "$profile" 2>/dev/null && { ok "Already configured"; return; }
  
  cat >> "$profile" << EOF

# LOKI - NGINX Machine Configurator
export LOKI_DIR="$LOKI_INSTALL_DIR"
export PATH="\$LOKI_DIR:\$PATH"
EOF

  ok "Added to $profile"
}

verify_installation() {
  [ -f "$LOKI_INSTALL_DIR/loki" ] || fatal "Installation failed"
  [ -x "$LOKI_INSTALL_DIR/loki" ] || fatal "Script not executable"
  
  command -v loki >/dev/null 2>&1 && ok "Available in PATH" || warn "Restart terminal"
}

main() {
  echo -e "${BOLD}LOKI Installer${NC}"
  echo "==============="
  
  if [ -d "$LOKI_INSTALL_DIR" ]; then
    read -p "Directory exists. Continue? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || fatal "Aborted"
  else
    mkdir -p "$LOKI_INSTALL_DIR" || fatal "Failed to create directory"
  fi
  
  check_deps
  download_loki
  create_symlink
  setup_profile
  verify_installation
  
  echo
  ok "Installation complete!"
  echo "Run: loki init"
}

# Run main function
main

} # this ensures the entire script is downloaded #
