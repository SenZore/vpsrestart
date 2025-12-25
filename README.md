# VPS Auto Restart System

A complete automatic restart setup for Ubuntu 24 LTS servers with optional Discord webhook notifications.

## Features
- Based on **systemd** for proper service management
- Customizable restart schedule (default is 5:00 AM)
- Supports timezone configuration (default: Asia/Jakarta, GMT+7)
- Sends updates to Discord through webhook embeds
- Reuses a single embed message to avoid spam
- Reports system and service status after restart
- Can be turned on or off anytime without uninstalling

## Quick Installation
```
# Download and run the installer
wget https://raw.githubusercontent.com/SenZore/vpsrestart/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

Or upload it manually:
```
# Upload the installer
scp install.sh user@your-vps:/home/user/
# Run the installer
sudo ./install.sh
```

## Interactive Setup
During installation, you’ll be asked for:
1. Timezone (default: Asia/Jakarta)
2. Restart time (default: 05:00 AM)
3. Discord webhook URL (optional)

## Management Commands
After setup, use `varctl` to manage or check the service:
```
varctl status       # View service status and next restart time
varctl enable       # Turn on automatic restart
varctl disable      # Turn off automatic restart (timer still runs)
varctl set-time     # Set a new restart time
varctl set-webhook  # Configure or change Discord webhook
varctl test         # Send a test message to Discord
varctl logs         # Check recent logs
varctl restart-now  # Restart the server immediately
varctl uninstall    # Remove everything
```

## Discord Notifications
**When the server restarts**, a message shows:
- Hostname  
- Current time  
- Uptime before restart  
- Next scheduled restart

**After the server is back online**, another message shows:
- Hostname  
- Boot time  
- Current uptime  
- Next scheduled restart  
- Service status (SSH, Nginx, Docker, etc.)

The script automatically deletes the previous embed before sending a new one, keeping your log channel clean.

## File Locations
| File | Path |
|------|------|
| Configuration | `/opt/vps-auto-restart/config.env` |
| Scripts | `/opt/vps-auto-restart/` |
| Logs | `/var/log/vps-auto-restart.log` |
| Systemd Service | `/etc/systemd/system/vps-auto-restart.service` |
| Systemd Timer | `/etc/systemd/system/vps-auto-restart.timer` |

## Systemd Commands
```
# Check timer status
systemctl status vps-auto-restart.timer

# View next scheduled restart
systemctl list-timers vps-auto-restart.timer

# Manual control
sudo systemctl start vps-auto-restart.timer
sudo systemctl stop vps-auto-restart.timer
sudo systemctl restart vps-auto-restart.timer
```

## Configuration
Edit `/opt/vps-auto-restart/config.env`:
```
TIMEZONE="Asia/Jakarta"
RESTART_HOUR="05"
RESTART_MINUTE="00"
DISCORD_ENABLED="true"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/xxx/yyy"
DISCORD_MESSAGE_ID=""
ENABLED="true"
```

## Requirements
- Ubuntu 24 LTS or compatible  
- Root access (sudo)  
- `curl` and `jq` (auto-installed)  
- Optional Discord webhook URL  

## Uninstall
```
sudo varctl uninstall
```

This will remove:
- The systemd service and timer  
- All configuration and script files  
- The `varctl` command  

## License
MIT License — free to use, edit, and distribute.
```


