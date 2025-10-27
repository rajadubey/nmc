#!/bin/bash

{ # this ensures the entire script is downloaded #

NMC_INSTALL_DIR="${NMC_DIR:-$HOME/.nmc}"

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
    local symlinks=("/usr/local/bin/nmc" "/usr/bin/nmc")
    
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
        if [ -f "$profile" ] && grep -q "NMC_DIR" "$profile" 2>/dev/null; then
            # Create backup
            cp "$profile" "$profile.nmc-backup" 2>/dev/null
            # Remove nmc lines
            sed -i.bak '/NMC - NGINX Machine Configurator/,/export PATH=.*nmc/d' "$profile" 2>/dev/null
            sed -i.bak '/NMC_DIR/d' "$profile" 2>/dev/null
            rm -f "$profile.bak" 2>/dev/null
            ok "Removed nmc configuration from $profile"
        fi
    done
}

remove_installation_dir() {
    if [ -d "$NMC_INSTALL_DIR" ]; then
        if rm -rf "$NMC_INSTALL_DIR"; then
            ok "Removed installation directory: $NMC_INSTALL_DIR"
        else
            err "Failed to remove installation directory: $NMC_INSTALL_DIR"
        fi
    else
        warn "Installation directory not found: $NMC_INSTALL_DIR"
    fi
}

main() {
    echo
    echo "NMC - NGINX Machine Configurator Uninstaller"
    echo "==========================================="
    echo
    echo "This will remove:"
    echo "  - nmc symlinks from /usr/local/bin"
    echo "  - nmc configuration from shell profiles"
    echo "  - Installation directory: $NMC_INSTALL_DIR"
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