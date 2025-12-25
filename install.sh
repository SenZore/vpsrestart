#!/bin/bash
#===============================================================================
# VPS Auto Restart - AIO Installer
# For Ubuntu 24 LTS
# Features: Systemd Service, Discord Webhook, Configurable Schedule
#===============================================================================
set -e
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'
# Installation paths
INSTALL_DIR="/opt/vps-auto-restart"
CONFIG_FILE="$INSTALL_DIR/config.env"
SERVICE_FILE="/etc/systemd/system/vps-auto-restart.service"
TIMER_FILE="/etc/systemd/system/vps-auto-restart.timer"
STARTUP_SERVICE="/etc/systemd/system/vps-startup-notify.service"
# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ${BOLD}VPS Auto Restart System${NC}${CYAN}                                 ║"
    echo "║     For Ubuntu 24 LTS                                        ║"
    echo "║                                                              ║"
    echo "║     Features:                                                ║"
    echo "║     • Systemd-based auto restart                             ║"
    echo "║     • Discord webhook notifications                          ║"
    echo "║     • Configurable schedule                                  ║"
    echo "║     • Toggle enable/disable                                  ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}
# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: Please run as root (sudo ./install.sh)${NC}"
        exit 1
    fi
}
# Install dependencies
install_deps() {
    echo -e "${BLUE}[1/6] Installing dependencies...${NC}"
    apt-get update -qq
    apt-get install -y -qq curl jq > /dev/null 2>&1
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}
# Configure timezone
configure_timezone() {
    echo ""
    echo -e "${BLUE}[2/6] Timezone Configuration${NC}"
    echo -e "${YELLOW}Default: Asia/Jakarta (GMT+7 - Indonesia)${NC}"
    echo ""
    read -p "Use default timezone? [Y/n]: " use_default_tz
    
    if [[ "$use_default_tz" =~ ^[Nn]$ ]]; then
        echo "Available timezones: Asia/Jakarta, Asia/Singapore, Asia/Bangkok, UTC, etc."
        read -p "Enter timezone: " TIMEZONE
    else
        TIMEZONE="Asia/Jakarta"
    fi
    
    timedatectl set-timezone "$TIMEZONE"
    echo -e "${GREEN}✓ Timezone set to: $TIMEZONE${NC}"
}
# Configure restart time
configure_time() {
    echo ""
    echo -e "${BLUE}[3/6] Restart Schedule Configuration${NC}"
    echo -e "${YELLOW}Default: 05:00 (5 AM)${NC}"
    echo ""
    read -p "Enter restart hour (0-23) [5]: " RESTART_HOUR
    RESTART_HOUR=${RESTART_HOUR:-5}
    
    read -p "Enter restart minute (0-59) [0]: " RESTART_MINUTE
    RESTART_MINUTE=${RESTART_MINUTE:-0}
    
    # Validate
    if ! [[ "$RESTART_HOUR" =~ ^[0-9]+$ ]] || [ "$RESTART_HOUR" -lt 0 ] || [ "$RESTART_HOUR" -gt 23 ]; then
        RESTART_HOUR=5
    fi
    if ! [[ "$RESTART_MINUTE" =~ ^[0-9]+$ ]] || [ "$RESTART_MINUTE" -lt 0 ] || [ "$RESTART_MINUTE" -gt 59 ]; then
        RESTART_MINUTE=0
    fi
    
    # Format with leading zeros
    RESTART_HOUR=$(printf "%02d" $RESTART_HOUR)
    RESTART_MINUTE=$(printf "%02d" $RESTART_MINUTE)
    
    echo -e "${GREEN}✓ Restart scheduled for: ${RESTART_HOUR}:${RESTART_MINUTE}${NC}"
}
# Configure Discord webhook
configure_discord() {
    echo ""
    echo -e "${BLUE}[4/6] Discord Webhook Configuration${NC}"
    echo ""
    read -p "Enable Discord notifications? [y/N]: " enable_discord
    
    if [[ "$enable_discord" =~ ^[Yy]$ ]]; then
        DISCORD_ENABLED="true"
        echo ""
        echo -e "${YELLOW}Enter your Discord webhook URL:${NC}"
        read -p "Webhook URL: " DISCORD_WEBHOOK
        
        if [[ -z "$DISCORD_WEBHOOK" ]]; then
            echo -e "${RED}No webhook provided. Disabling Discord notifications.${NC}"
            DISCORD_ENABLED="false"
            DISCORD_WEBHOOK=""
        else
            # Test webhook
            echo -e "${YELLOW}Testing webhook...${NC}"
            test_response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DISCORD_WEBHOOK" \
                -H "Content-Type: application/json" \
                -d '{"content": "🔧 **VPS Auto Restart** - Webhook test successful!"}')
            
            if [ "$test_response" = "204" ] || [ "$test_response" = "200" ]; then
                echo -e "${GREEN}✓ Webhook test successful!${NC}"
            else
                echo -e "${YELLOW}⚠ Webhook test returned: $test_response (may still work)${NC}"
            fi
        fi
    else
        DISCORD_ENABLED="false"
        DISCORD_WEBHOOK=""
    fi
    
    echo -e "${GREEN}✓ Discord notifications: $DISCORD_ENABLED${NC}"
}
# Create installation directory and files
create_files() {
    echo ""
    echo -e "${BLUE}[5/6] Creating service files...${NC}"
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Create config file
    cat > "$CONFIG_FILE" << EOF
# VPS Auto Restart Configuration
# Generated: $(date)
TIMEZONE="$TIMEZONE"
RESTART_HOUR="$RESTART_HOUR"
RESTART_MINUTE="$RESTART_MINUTE"
DISCORD_ENABLED="$DISCORD_ENABLED"
DISCORD_WEBHOOK="$DISCORD_WEBHOOK"
DISCORD_MESSAGE_ID=""
ENABLED="true"
EOF
    # Create main restart script
    cat > "$INSTALL_DIR/restart.sh" << 'RESTARTSCRIPT'
#!/bin/bash
#===============================================================================
# VPS Auto Restart - Main Restart Script
#===============================================================================
source /opt/vps-auto-restart/config.env
LOG_FILE="/var/log/vps-auto-restart.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}
get_next_restart_time() {
    # Calculate next restart time
    local next_date=$(date -d "tomorrow $RESTART_HOUR:$RESTART_MINUTE" '+%Y-%m-%d %H:%M:%S %Z')
    echo "$next_date"
}
send_discord_shutdown() {
    if [ "$DISCORD_ENABLED" != "true" ] || [ -z "$DISCORD_WEBHOOK" ]; then
        return
    fi
    
    local hostname=$(hostname)
    local current_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    local next_restart=$(get_next_restart_time)
    local uptime_str=$(uptime -p)
    
    # Delete previous message if exists
    if [ -n "$DISCORD_MESSAGE_ID" ]; then
        # Extract webhook ID and token for deletion
        local webhook_base=$(echo "$DISCORD_WEBHOOK" | sed 's|/github||g')
        curl -s -X DELETE "${webhook_base}/messages/${DISCORD_MESSAGE_ID}" > /dev/null 2>&1
    fi
    
    # Send new message with wait=true to get message ID
    local response=$(curl -s -X POST "${DISCORD_WEBHOOK}?wait=true" \
        -H "Content-Type: application/json" \
        -d @- << EMBED
{
    "embeds": [{
        "title": "🔄 Server Restarting",
        "description": "The VPS is performing a scheduled restart.",
        "color": 16744256,
        "fields": [
            {
                "name": "🖥️ Server",
                "value": "\`$hostname\`",
                "inline": true
            },
            {
                "name": "⏰ Time",
                "value": "\`$current_time\`",
                "inline": true
            },
            {
                "name": "📊 Uptime Before Restart",
                "value": "\`$uptime_str\`",
                "inline": false
            },
            {
                "name": "🔜 Next Scheduled Restart",
                "value": "\`$next_restart\`",
                "inline": false
            }
        ],
        "footer": {
            "text": "VPS Auto Restart System"
        },
        "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    }]
}
EMBED
)
    
    # Extract and save message ID
    local msg_id=$(echo "$response" | jq -r '.id // empty')
    if [ -n "$msg_id" ]; then
        sed -i "s/DISCORD_MESSAGE_ID=.*/DISCORD_MESSAGE_ID=\"$msg_id\"/" /opt/vps-auto-restart/config.env
    fi
    
    log "Discord notification sent (restart)"
}
# Main logic
main() {
    # Check if enabled
    if [ "$ENABLED" != "true" ]; then
        log "Auto-restart is disabled, skipping"
        exit 0
    fi
    
    log "Starting scheduled restart"
    
    # Send Discord notification
    send_discord_shutdown
    
    # Wait a moment for notification to send
    sleep 5
    
    # Perform restart
    log "Executing system restart"
    /sbin/shutdown -r now "Scheduled daily restart"
}
main
RESTARTSCRIPT
    # Create startup notification script
    cat > "$INSTALL_DIR/startup-notify.sh" << 'STARTUPSCRIPT'
#!/bin/bash
#===============================================================================
# VPS Auto Restart - Startup Notification Script
#===============================================================================
# Wait for network to be available
sleep 10
source /opt/vps-auto-restart/config.env
LOG_FILE="/var/log/vps-auto-restart.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}
get_next_restart_time() {
    local next_date=$(date -d "today $RESTART_HOUR:$RESTART_MINUTE" '+%Y-%m-%d %H:%M:%S %Z')
    local next_ts=$(date -d "today $RESTART_HOUR:$RESTART_MINUTE" '+%s')
    local now_ts=$(date '+%s')
    
    if [ "$next_ts" -le "$now_ts" ]; then
        next_date=$(date -d "tomorrow $RESTART_HOUR:$RESTART_MINUTE" '+%Y-%m-%d %H:%M:%S %Z')
    fi
    echo "$next_date"
}
check_services() {
    local services_status=""
    local all_ok=true
    
    # Check common services (add more as needed)
    for service in ssh nginx apache2 mysql mariadb docker; do
        if systemctl is-enabled "$service" > /dev/null 2>&1; then
            if systemctl is-active --quiet "$service"; then
                services_status+="✅ $service\n"
            else
                services_status+="❌ $service\n"
                all_ok=false
            fi
        fi
    done
    
    if [ -z "$services_status" ]; then
        services_status="No monitored services detected"
    fi
    
    echo -e "$services_status"
}
send_discord_startup() {
    if [ "$DISCORD_ENABLED" != "true" ] || [ -z "$DISCORD_WEBHOOK" ]; then
        return
    fi
    
    local hostname=$(hostname)
    local current_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    local next_restart=$(get_next_restart_time)
    local uptime_str=$(uptime -p)
    local boot_time=$(uptime -s)
    local services=$(check_services)
    
    # Delete previous message if exists
    if [ -n "$DISCORD_MESSAGE_ID" ]; then
        local webhook_base=$(echo "$DISCORD_WEBHOOK" | sed 's|/github||g')
        curl -s -X DELETE "${webhook_base}/messages/${DISCORD_MESSAGE_ID}" > /dev/null 2>&1
    fi
    
    # Send new embed
    local response=$(curl -s -X POST "${DISCORD_WEBHOOK}?wait=true" \
        -H "Content-Type: application/json" \
        -d @- << EMBED
{
    "embeds": [{
        "title": "✅ Server Online",
        "description": "The VPS has successfully restarted and is now online.",
        "color": 5763719,
        "fields": [
            {
                "name": "🖥️ Server",
                "value": "\`$hostname\`",
                "inline": true
            },
            {
                "name": "🕐 Boot Time",
                "value": "\`$boot_time\`",
                "inline": true
            },
            {
                "name": "⏱️ Uptime",
                "value": "\`$uptime_str\`",
                "inline": true
            },
            {
                "name": "🔜 Next Restart",
                "value": "\`$next_restart\`",
                "inline": false
            },
            {
                "name": "📋 Service Status",
                "value": "$(echo -e "$services" | head -10 | tr '\n' ' ' | sed 's/  / | /g')",
                "inline": false
            }
        ],
        "footer": {
            "text": "VPS Auto Restart System"
        },
        "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    }]
}
EMBED
)
    
    # Save message ID
    local msg_id=$(echo "$response" | jq -r '.id // empty')
    if [ -n "$msg_id" ]; then
        sed -i "s/DISCORD_MESSAGE_ID=.*/DISCORD_MESSAGE_ID=\"$msg_id\"/" /opt/vps-auto-restart/config.env
    fi
    
    log "Discord notification sent (startup)"
}
send_discord_startup
STARTUPSCRIPT
    # Create control script
    cat > "$INSTALL_DIR/varctl" << 'CTLSCRIPT'
#!/bin/bash
#===============================================================================
# VPS Auto Restart - Control Script (varctl)
#===============================================================================
CONFIG_FILE="/opt/vps-auto-restart/config.env"
source "$CONFIG_FILE"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
show_status() {
    source "$CONFIG_FILE"
    
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     VPS Auto Restart Status                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$ENABLED" = "true" ]; then
        echo -e "Status:          ${GREEN}ENABLED${NC}"
    else
        echo -e "Status:          ${RED}DISABLED${NC}"
    fi
    
    echo -e "Timezone:        ${YELLOW}$TIMEZONE${NC}"
    echo -e "Restart Time:    ${YELLOW}${RESTART_HOUR}:${RESTART_MINUTE}${NC}"
    
    if [ "$DISCORD_ENABLED" = "true" ]; then
        echo -e "Discord:         ${GREEN}ENABLED${NC}"
    else
        echo -e "Discord:         ${YELLOW}DISABLED${NC}"
    fi
    
    echo ""
    
    # Timer status
    if systemctl is-active --quiet vps-auto-restart.timer; then
        echo -e "Timer Service:   ${GREEN}RUNNING${NC}"
        echo ""
        echo -e "${BLUE}Next trigger:${NC}"
        systemctl list-timers vps-auto-restart.timer --no-pager | tail -2 | head -1
    else
        echo -e "Timer Service:   ${RED}STOPPED${NC}"
    fi
    
    echo ""
}
enable_restart() {
    sed -i 's/ENABLED=.*/ENABLED="true"/' "$CONFIG_FILE"
    systemctl enable vps-auto-restart.timer
    systemctl start vps-auto-restart.timer
    echo -e "${GREEN}✓ Auto-restart ENABLED${NC}"
}
disable_restart() {
    sed -i 's/ENABLED=.*/ENABLED="false"/' "$CONFIG_FILE"
    echo -e "${YELLOW}✓ Auto-restart DISABLED${NC}"
    echo "(Timer still runs but restart will be skipped)"
}
set_time() {
    read -p "Enter hour (0-23): " hour
    read -p "Enter minute (0-59): " minute
    
    hour=$(printf "%02d" $hour)
    minute=$(printf "%02d" $minute)
    
    sed -i "s/RESTART_HOUR=.*/RESTART_HOUR=\"$hour\"/" "$CONFIG_FILE"
    sed -i "s/RESTART_MINUTE=.*/RESTART_MINUTE=\"$minute\"/" "$CONFIG_FILE"
    
    # Update timer
    cat > /etc/systemd/system/vps-auto-restart.timer << EOF
[Unit]
Description=VPS Auto Restart Timer
[Timer]
OnCalendar=*-*-* ${hour}:${minute}:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
    
    systemctl daemon-reload
    systemctl restart vps-auto-restart.timer
    
    echo -e "${GREEN}✓ Restart time set to ${hour}:${minute}${NC}"
}
set_webhook() {
    read -p "Enter Discord webhook URL (empty to disable): " webhook
    
    if [ -z "$webhook" ]; then
        sed -i 's/DISCORD_ENABLED=.*/DISCORD_ENABLED="false"/' "$CONFIG_FILE"
        sed -i 's|DISCORD_WEBHOOK=.*|DISCORD_WEBHOOK=""|' "$CONFIG_FILE"
        echo -e "${YELLOW}✓ Discord notifications disabled${NC}"
    else
        sed -i 's/DISCORD_ENABLED=.*/DISCORD_ENABLED="true"/' "$CONFIG_FILE"
        sed -i "s|DISCORD_WEBHOOK=.*|DISCORD_WEBHOOK=\"$webhook\"|" "$CONFIG_FILE"
        echo -e "${GREEN}✓ Discord webhook updated${NC}"
    fi
}
test_notification() {
    source "$CONFIG_FILE"
    
    if [ "$DISCORD_ENABLED" != "true" ]; then
        echo -e "${RED}Discord notifications are disabled${NC}"
        return
    fi
    
    echo -e "${YELLOW}Sending test notification...${NC}"
    /opt/vps-auto-restart/startup-notify.sh
    echo -e "${GREEN}✓ Test notification sent${NC}"
}
show_logs() {
    echo -e "${CYAN}=== Recent Logs ===${NC}"
    tail -30 /var/log/vps-auto-restart.log 2>/dev/null || echo "No logs yet"
}
show_help() {
    echo -e "${CYAN}VPS Auto Restart Control (varctl)${NC}"
    echo ""
    echo "Usage: varctl [command]"
    echo ""
    echo "Commands:"
    echo "  status      Show current status"
    echo "  enable      Enable auto-restart"
    echo "  disable     Disable auto-restart"
    echo "  set-time    Change restart time"
    echo "  set-webhook Configure Discord webhook"
    echo "  test        Send test notification"
    echo "  logs        Show recent logs"
    echo "  restart-now Force restart now"
    echo "  uninstall   Remove auto-restart system"
    echo "  help        Show this help"
    echo ""
}
force_restart() {
    echo -e "${RED}WARNING: This will restart the VPS immediately!${NC}"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        /opt/vps-auto-restart/restart.sh
    else
        echo "Cancelled"
    fi
}
uninstall() {
    echo -e "${RED}This will remove the VPS Auto Restart system${NC}"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        systemctl stop vps-auto-restart.timer 2>/dev/null
        systemctl stop vps-startup-notify.service 2>/dev/null
        systemctl disable vps-auto-restart.timer 2>/dev/null
        systemctl disable vps-startup-notify.service 2>/dev/null
        rm -f /etc/systemd/system/vps-auto-restart.*
        rm -f /etc/systemd/system/vps-startup-notify.service
        rm -f /usr/local/bin/varctl
        rm -rf /opt/vps-auto-restart
        systemctl daemon-reload
        echo -e "${GREEN}✓ Uninstalled successfully${NC}"
    else
        echo "Cancelled"
    fi
}
case "${1:-help}" in
    status) show_status ;;
    enable) enable_restart ;;
    disable) disable_restart ;;
    set-time) set_time ;;
    set-webhook) set_webhook ;;
    test) test_notification ;;
    logs) show_logs ;;
    restart-now) force_restart ;;
    uninstall) uninstall ;;
    help|--help|-h) show_help ;;
    *) echo "Unknown command. Use 'varctl help' for usage." ;;
esac
CTLSCRIPT
    # Make scripts executable
    chmod +x "$INSTALL_DIR/restart.sh"
    chmod +x "$INSTALL_DIR/startup-notify.sh"
    chmod +x "$INSTALL_DIR/varctl"
    
    # Create symlink for easy access
    ln -sf "$INSTALL_DIR/varctl" /usr/local/bin/varctl
    
    # Create systemd service for restart
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=VPS Auto Restart Service
After=network.target
[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/restart.sh
[Install]
WantedBy=multi-user.target
EOF
    # Create systemd timer
    cat > "$TIMER_FILE" << EOF
[Unit]
Description=VPS Auto Restart Timer
[Timer]
OnCalendar=*-*-* ${RESTART_HOUR}:${RESTART_MINUTE}:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
    # Create startup notification service
    cat > "$STARTUP_SERVICE" << EOF
[Unit]
Description=VPS Startup Notification
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/startup-notify.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✓ Service files created${NC}"
}
# Enable and start services
enable_services() {
    echo ""
    echo -e "${BLUE}[6/6] Enabling services...${NC}"
    
    # Create log file
    touch /var/log/vps-auto-restart.log
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start timer
    systemctl enable vps-auto-restart.timer
    systemctl start vps-auto-restart.timer
    
    # Enable startup notification
    systemctl enable vps-startup-notify.service
    
    echo -e "${GREEN}✓ Services enabled and started${NC}"
}
# Show completion message
show_complete() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║     ✅ Installation Complete!                                ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo -e "  Timezone:     ${YELLOW}$TIMEZONE${NC}"
    echo -e "  Restart at:   ${YELLOW}${RESTART_HOUR}:${RESTART_MINUTE}${NC}"
    echo -e "  Discord:      ${YELLOW}$DISCORD_ENABLED${NC}"
    echo ""
    echo -e "${CYAN}Management Commands:${NC}"
    echo -e "  ${GREEN}varctl status${NC}      - View status"
    echo -e "  ${GREEN}varctl enable${NC}      - Enable auto-restart"
    echo -e "  ${GREEN}varctl disable${NC}     - Disable auto-restart"
    echo -e "  ${GREEN}varctl set-time${NC}    - Change restart time"
    echo -e "  ${GREEN}varctl set-webhook${NC} - Configure Discord"
    echo -e "  ${GREEN}varctl test${NC}        - Send test notification"
    echo -e "  ${GREEN}varctl logs${NC}        - View logs"
    echo -e "  ${GREEN}varctl uninstall${NC}   - Remove system"
    echo ""
    echo -e "${CYAN}Next scheduled restart:${NC}"
    systemctl list-timers vps-auto-restart.timer --no-pager | tail -2 | head -1
    echo ""
}
# Main installation flow
main() {
    show_banner
    check_root
    install_deps
    configure_timezone
    configure_time
    configure_discord
    create_files
    enable_services
    show_complete
}
main
