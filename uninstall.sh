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
    local symlinks=("/usr/local/bin/loki" "/usr/bin/loki")
    
    for symlink in "${symlinks[@]}"; do
        if [ -L "$symlink" ]; then
            if sudo rm -f "$symlink" 2>/dev/null; then
                ok "Removed symlink: $symlink"
            elif rm -f "$symlink" 2>/dev/null; then
                ok "Removed symlink: $symlink"
            else
                warn "Could not remove symlink: $symlink"
            fi
        fi
    done
}

remove_from_profile() {
    local profile_files=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc")
    
    for profile in "${profile_files[@]}"; do
        if [ -f "$profile" ] && grep -q "LOKI_DIR" "$profile" 2>/dev/null; then
            # Create backup
            cp "$profile" "$profile.loki-backup" 2>/dev/null
            # Remove loki lines
            sed -i.bak '/LOKI - NGINX Machine Configurator/,/export PATH=.*loki/d' "$profile" 2>/dev/null
            sed -i.bak '/LOKI_DIR/d' "$profile" 2>/dev/null
            rm -f "$profile.bak" 2>/dev/null
            ok "Removed loki configuration from $profile"
        fi
    done
}

remove_installation_dir() {
    if [ -d "$LOKI_INSTALL_DIR" ]; then
        if rm -rf "$LOKI_INSTALL_DIR"; then
            ok "Removed installation directory: $LOKI_INSTALL_DIR"
        else
            err "Failed to remove installation directory: $LOKI_INSTALL_DIR"
        fi
    else
        warn "Installation directory not found: $LOKI_INSTALL_DIR"
    fi
}

main() {
    echo
    echo "LOKI - NGINX Machine Configurator Uninstaller"
    echo "==========================================="
    echo
    echo "This will remove:"
    echo "  - loki symlinks from /usr/local/bin"
    echo "  - loki configuration from shell profiles"
    echo "  - Installation directory: $LOKI_INSTALL_DIR"
    echo
    
    read -p "Are you sure you want to continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled"
        exit 0
    fi
    
    remove_symlink
    remove_from_profile
    remove_installation_dir
    
    echo
    ok "Uninstall complete!"
    echo
    echo "Note: You may need to restart your terminal or run:"
    echo "  exec \$SHELL"
    echo
}

main

} # this ensures the entire script is downloaded #