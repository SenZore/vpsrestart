# VPS Auto Restart System
A comprehensive auto-restart solution for Ubuntu 24 LTS VPS with Discord webhook notifications.
## Features
- ✅ **Systemd-based** - Proper service management with `systemctl`
- ⏰ **Configurable Schedule** - Set any restart time (default: 5:00 AM)
- 🌏 **Timezone Support** - GMT+7 (Asia/Jakarta) default
- 🔔 **Discord Notifications** - Rich embed messages for restart events
- 🔄 **Smart Embed Updates** - Replaces old embeds to avoid spam
- 📊 **Service Monitoring** - Reports service status after restart
- 🎛️ **Easy Toggle** - Enable/disable without removing installation
## Quick Install
```bash
# Download and run installer
wget https://raw.githubusercontent.com/your-repo/vps-auto-restart/main/install.sh
chmod +x install.sh
sudo ./install.sh
```
Or manually upload files:
```bash
# Upload to VPS
scp install.sh user@your-vps:/home/user/
# Run installer
sudo ./install.sh
```
## Interactive Setup
The installer will prompt you for:
1. **Timezone** - Default: Asia/Jakarta (GMT+7)
2. **Restart Time** - Default: 05:00 (5 AM)
3. **Discord Webhook** - Optional notifications
## Management Commands
After installation, use `varctl` to manage the service:
```bash
varctl status       # View current status and next restart time
varctl enable       # Enable auto-restart
varctl disable      # Disable auto-restart (timer still runs but skips)
varctl set-time     # Change restart time
varctl set-webhook  # Configure Discord webhook
varctl test         # Send test Discord notification
varctl logs         # View recent activity logs
varctl restart-now  # Force immediate restart
varctl uninstall    # Remove the entire system
```
## Discord Notifications
### When Server Restarts
![Restart Notification](https://via.placeholder.com/400x200/FFA500/fff?text=🔄+Server+Restarting)
Shows:
- Server hostname
- Current time
- Uptime before restart
- Next scheduled restart time
### When Server Comes Online
![Online Notification](https://via.placeholder.com/400x200/57F287/fff?text=✅+Server+Online)
Shows:
- Server hostname
- Boot time
- Current uptime
- Next scheduled restart
- Service status (SSH, Nginx, Docker, etc.)
### Spam Prevention
The system automatically deletes the previous notification before posting a new one, keeping your Discord channel clean.
## File Locations
| File | Location |
|------|----------|
| Config | `/opt/vps-auto-restart/config.env` |
| Scripts | `/opt/vps-auto-restart/` |
| Logs | `/var/log/vps-auto-restart.log` |
| Service | `/etc/systemd/system/vps-auto-restart.service` |
| Timer | `/etc/systemd/system/vps-auto-restart.timer` |
## Systemd Services
```bash
# Check timer status
systemctl status vps-auto-restart.timer
# View next scheduled restart
systemctl list-timers vps-auto-restart.timer
# Manual service control
sudo systemctl start/stop/restart vps-auto-restart.timer
```
## Configuration File
Edit `/opt/vps-auto-restart/config.env`:
```bash
TIMEZONE="Asia/Jakarta"
RESTART_HOUR="05"
RESTART_MINUTE="00"
DISCORD_ENABLED="true"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/xxx/yyy"
DISCORD_MESSAGE_ID=""
ENABLED="true"
```
## Requirements
- Ubuntu 24 LTS (or compatible)
- Root access (sudo)
- `curl` and `jq` (auto-installed)
- Discord webhook URL (optional)
## Uninstall
```bash
sudo varctl uninstall
```
This removes:
- All systemd services and timers
- Configuration files
- Scripts from `/opt/vps-auto-restart/`
- The `varctl` command
## License
MIT License - Free to use and modify.
