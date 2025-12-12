#!/bin/bash

{ # this ensures the entire script is downloaded #

LOKI_INSTALL_DIR="${LOKI_DIR:-$HOME/.loki}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() { echo -e "$1"; }
ok() { log "${GREEN}✅ $1${NC}"; }
warn() { log "${YELLOW}⚠️ $1${NC}"; }
err() { log "${RED}❌ $1${NC}" >&2; }

remove_symlink() {
    for symlink in "/usr/local/bin/loki" "/usr/bin/loki"; do
        [ -L "$symlink" ] && (sudo rm -f "$symlink" 2>/dev/null || rm -f "$symlink" 2>/dev/null) && ok "Removed symlink"
    done
}

remove_from_profile() {
    for profile in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc"; do
        if [ -f "$profile" ] && grep -q "LOKI_DIR" "$profile" 2>/dev/null; then
            sed -i.bak '/LOKI - NGINX Machine Configurator/,/export PATH=.*loki/d; /LOKI_DIR/d' "$profile" 2>/dev/null
            rm -f "$profile.bak" 2>/dev/null
            ok "Cleaned $profile"
        fi
    done
}

remove_installation_dir() {
    [ -d "$LOKI_INSTALL_DIR" ] && rm -rf "$LOKI_INSTALL_DIR" && ok "Removed installation directory"
}

main() {
    echo "LOKI Uninstaller"
    echo "================"
    echo "Will remove: symlinks, profiles, $LOKI_INSTALL_DIR"
    
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 0
    
    remove_symlink
    remove_from_profile
    remove_installation_dir
    
    ok "Uninstall complete!"
}

main

} # this ensures the entire script is downloaded #