#!/bin/bash

{ # this ensures the entire script is downloaded #

NMC_INSTALL_DIR="${NMC_DIR:-$HOME/.nmc}"
NMC_REPO="rajadubey/nmc"
NMC_RAW_URL="https://raw.githubusercontent.com/$NMC_REPO/master/nmc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging functions
log() {
  echo -e "${BLUE}[nmc]${NC} $1"
}

ok() {
  echo -e "${GREEN}✅${NC} $1"
}

warn() {
  echo -e "${YELLOW}⚠️${NC} $1"
}

err() {
  echo -e "${RED}❌${NC} $1" >&2
}

fatal() {
  err "$1"
  exit 1
}

# Check dependencies
check_deps() {
  local deps=("curl" "jq")
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    warn "Missing dependencies: ${missing[*]}"
    echo "Please install them using your package manager:"
    echo "  macOS: brew install ${missing[*]}"
    echo "  Ubuntu/Debian: sudo apt install ${missing[*]}"
    echo
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      fatal "Installation aborted"
    fi
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

# Download nmc script
download_nmc() {
  log "Downloading nmc..."
  
  if ! curl -fsSL -o "$NMC_INSTALL_DIR/nmc" "$NMC_RAW_URL"; then
    fatal "Failed to download nmc from $NMC_RAW_URL"
  fi
  
  chmod +x "$NMC_INSTALL_DIR/nmc"
  ok "Downloaded nmc to $NMC_INSTALL_DIR/nmc"
}

# Create symlink
create_symlink() {
  local symlink_dir="/usr/local/bin"
  local symlink_path="$symlink_dir/nmc"
  
  # Check if we can write to /usr/local/bin
  if [ ! -w "$symlink_dir" ]; then
    warn "Cannot write to $symlink_dir, need sudo access"
    if sudo ln -sf "$NMC_INSTALL_DIR/nmc" "$symlink_path" 2>/dev/null; then
      ok "Created symlink with sudo: $symlink_path -> $NMC_INSTALL_DIR/nmc"
    else
      warn "Failed to create system symlink, using local installation"
      echo "You can manually create a symlink later:"
      echo "  sudo ln -sf $NMC_INSTALL_DIR/nmc /usr/local/bin/nmc"
      echo "Or add $NMC_INSTALL_DIR to your PATH"
      return
    fi
  else
    if ln -sf "$NMC_INSTALL_DIR/nmc" "$symlink_path" 2>/dev/null; then
      ok "Created symlink: $symlink_path -> $NMC_INSTALL_DIR/nmc"
    else
      warn "Failed to create symlink"
    fi
  fi
}

# Setup shell profile
setup_profile() {
  local profile
  profile=$(detect_profile)
  
  if [ -z "$profile" ]; then
    warn "No shell profile found. Please add $NMC_INSTALL_DIR to your PATH manually"
    return
  fi
  
  log "Detected shell profile: $profile"
  
  # Check if already in PATH
  if echo ":$PATH:" | grep -q ":$NMC_INSTALL_DIR:"; then
    ok "nmc directory already in PATH"
    return
  fi
  
  # Add to PATH in profile
  if grep -q "NMC_DIR" "$profile" 2>/dev/null; then
    ok "nmc configuration already exists in $profile"
    return
  fi
  
  cat >> "$profile" << EOF

# NMC - NGINX Machine Configurator
export NMC_DIR="$NMC_INSTALL_DIR"
export PATH="\$NMC_DIR:\$PATH"
EOF

  ok "Added nmc to $profile"
  echo "Please restart your terminal or run: source $profile"
}

# Verify installation
verify_installation() {
  log "Verifying installation..."
  
  if [ ! -f "$NMC_INSTALL_DIR/nmc" ]; then
    fatal "nmc script not found at $NMC_INSTALL_DIR/nmc"
  fi
  
  if ! [ -x "$NMC_INSTALL_DIR/nmc" ]; then
    fatal "nmc script is not executable"
  fi
  
  # Test if nmc is available in PATH
  if command -v nmc >/dev/null 2>&1; then
    ok "nmc command is available in PATH"
  else
    warn "nmc command not in PATH. Please restart your terminal or add $NMC_INSTALL_DIR to your PATH"
  fi
  
  # Test basic functionality
  if "$NMC_INSTALL_DIR/nmc" --version >/dev/null 2>&1; then
    ok "nmc basic functionality test passed"
  else
    warn "nmc basic functionality test failed"
  fi
}

# Main installation
main() {
  echo
  echo -e "${BOLD}NMC - NGINX Machine Configurator Installer${NC}"
  echo "=============================================="
  echo
  
  log "Installation directory: $NMC_INSTALL_DIR"
  
  # Create installation directory
  if [ ! -d "$NMC_INSTALL_DIR" ]; then
    mkdir -p "$NMC_INSTALL_DIR" || fatal "Failed to create directory $NMC_INSTALL_DIR"
    ok "Created installation directory"
  else
    warn "Installation directory already exists: $NMC_INSTALL_DIR"
    read -p "Continue with installation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      fatal "Installation aborted"
    fi
  fi
  
  # Check dependencies
  check_deps
  
  # Download nmc
  download_nmc
  
  # Create symlink
  create_symlink
  
  # Setup shell profile
  setup_profile
  
  # Verify installation
  verify_installation
  
  echo
  echo -e "${GREEN}${BOLD}Installation complete!${NC}"
  echo
  echo "To get started:"
  echo "  1. Restart your terminal or run: source $(detect_profile)"
  echo "  2. Run: nmc init"
  echo "  3. Configure your source machines in ~/.bashrc or ~/.zshrc"
  echo
  echo "Documentation: https://github.com/$NMC_REPO"
  echo
}

# Run main function
main

} # this ensures the entire script is downloaded #