# NMC — NGINX Machine Configurator (Bash CLI)

## Overview

`nmc` is a simple command-line tool that helps you manage connections to different servers through your local NGINX. Think of it as a "remote server switcher" that automatically configures NGINX to proxy your local traffic to different remote machines.

### What This CLI Does (In Simple Words)

Instead of manually editing NGINX configuration files every time you want to switch between different servers (like your home PC, cloud instances, or testing machines), NMC lets you:
- **Switch between servers** with one command
- **Automatically generate** the proper NGINX configuration
- **Check if services are working** on your local machine
- **Keep your server list updated** from remote sources

All configuration is **stored in `~/.nmc`** and can be customized via `.bashrc` or `.zshrc` environment variables.

---

### One-line Install
```bash
curl -o- https://raw.githubusercontent.com/rajadubey/nmc/master/install.sh | bash
```

## Installation

```bash
# Download the script
curl -fsSL -o ~/.nmc/nmc https://raw.githubusercontent.com/rajadubey/nmc/master/nmc

# Make it executable
chmod +x ~/.nmc/nmc

# Create symlink (may require sudo)
sudo ln -sf ~/.nmc/nmc /usr/local/bin/nmc
```


### Dependencies

Install required dependencies:

**macOS:**
```bash
brew install jq curl nginx
```

**Ubuntu/Debian:**
```bash
sudo apt install jq curl nginx openssh-client
```

---

## Environment Variables

Define your machines in `.bashrc` or `.zshrc`:

```bash
# For 'nmc refetch' - specify which machine to fetch from
export NMC_SSH_USER="ubuntu"
export NMC_SSH_HOST="54.123.45.67"
export NMC_SSH_PORT="22"
export NMC_REMOTE_MACHINES_JSON="/opt/machines.json"
```

Reload shell configuration:
```bash
source ~/.bashrc
# or
source ~/.zshrc
```

---

## Machine Configuration Format

`machine.json` example structure:

```json
{
  "personal_home_pc_ubuntu": {
    "ip": "192.168.1.100",
    "services": {
      "file_server_api": { "local": 8080, "remote": 80 },
      "user_service_api": { "local": 8081, "remote": 3000 },
      "payment_service_api": { "local": 5432, "remote": 5432 }
    }
  },
  "aws_machine": {
    "ip": "54.123.45.67",
    "services": {
      "organisation_common_api": { "local": 8082, "remote": 80 },
      "lambda_helper_api": { "local": 8083, "remote": 3000 }
    }
  },
  "gcp_lowCost_instance": {
    "ip": "34.56.78.90", 
    "services": {
      "category_store_api": { "local": 8084, "remote": 8080 },
      "book_store_api_2": { "local": 8085, "remote": 8081 }
    }
  }
}
```

---

## Usage

### Basic Commands

```bash
nmc init                    # Initialize ~/.nmc directory
nmc ls                      # List all available machines
nmc connect aws_machine     # Switch to AWS machine
nmc status                  # Show active machine and port mappings
nmc check                   # Test if services are accessible locally
nmc refresh                 # Regenerate and reload NGINX configuration
nmc refetch                 # Update machine.json from remote source
nmc break                   # Break connection from remote machine
```

### Example Workflow

```bash
# 1. Initialize and set up NMC
nmc init

# 2. See what machines are available
nmc ls

# 3. Connect to your home PC
nmc connect personal_home_pc_ubuntu

# 4. Check if services are working locally
nmc check

# 5. Update configuration from remote
nmc refetch
nmc refresh

# 6. Switch to cloud machine
nmc connect gcp_lowCost_instance
nmc check

# 6. Stop/Break this connection
nmc stop
nmc check
nmc status
```

### Service Health Checking

The `nmc check` command tests all services and shows their HTTP status:

```bash
$ nmc check
🔍 Checking services for aws_free_machine
  web (localhost:8082): Up (HTTP 200)
  api (localhost:8083): Up (HTTP 200)
  database (localhost:5432): Down
```

---

## How It Works

1. **Configuration Storage**: All data stored in `~/.nmc/`
   - `machine.json` - Server definitions and service mappings
   - `active` - Currently selected machine
   - `remote.conf` - Generated NGINX configuration
   - `nmc.log` - Operation logs

2. **NGINX Integration**: Automatically detects NGINX configuration directory and creates `remote.conf` with proper proxy settings

3. **Health Monitoring**: Tests local ports to verify services are accessible through the proxy

---

## Troubleshooting

### Common Issues

**Permission denied when copying to nginx directory:**
```bash
# On macOS with Homebrew NGINX
sudo chmod 755 /opt/homebrew/etc/nginx
```

**nginx configuration test fails:**
```bash
sudo nginx -t  # Check for syntax errors
```

**Service check shows "Down":**
- Verify the remote machine is running and accessible
- Check if services are active on the remote machine
- Confirm firewall rules allow connections

**Cannot fetch remote configuration:**
```bash
# Test SSH connection manually
ssh user@hostname "cat /path/to/machines.json"
```

### Logs

Check operation logs for detailed debugging:
```bash
tail -f ~/.nmc/nmc.log
```

---

## Notes

- Automatically handles NGINX configuration testing and reloading
- Works with any NGINX installation (Homebrew, system packages, custom compiled)
- Logs all operations for debugging purposes

---
