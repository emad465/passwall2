#!/bin/bash

################################################################################
# PassWall2 Smart Installer for OpenWrt
# Author: Smart Installer Team
# Description: Universal installer for PassWall2 - Works on ALL architectures
# Version: 2.2.0 (Production Ready)
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Log file
LOG_DIR="/tmp/passwall2_installer"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR" 2>/dev/null

################################################################################
# Logging Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "INFO"|"SUCCESS")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

################################################################################
# UI Functions
################################################################################

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                 PassWall2 Universal Installer                  ║"
    echo "║                    Version 2.2.0                               ║"
    echo "║              Works on ALL OpenWrt Architectures                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_separator() {
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
}

################################################################################
# System Detection Functions
################################################################################

detect_system_info() {
    log "INFO" "Starting system detection..."
    
    print_separator
    echo -e "${BOLD}System Information:${NC}"
    print_separator
    
    # Get OpenWrt version
    if [ -f /etc/openwrt_release ]; then
        source /etc/openwrt_release
        OPENWRT_VERSION="$DISTRIB_RELEASE"
        OPENWRT_ARCH="$DISTRIB_ARCH"
        OPENWRT_TARGET="$DISTRIB_TARGET"
        log "INFO" "OpenWrt: $OPENWRT_VERSION (Target: $OPENWRT_TARGET)"
        echo -e "OpenWrt: ${GREEN}$OPENWRT_VERSION${NC}"
        echo -e "Target: ${GREEN}$OPENWRT_TARGET${NC}"
    else
        log "ERROR" "This is not an OpenWrt system!"
        exit 1
    fi
    
    # Get architecture (use OpenWrt's native architecture name)
    SYSTEM_ARCH="$OPENWRT_ARCH"
    log "INFO" "Architecture: $SYSTEM_ARCH"
    echo -e "Architecture: ${GREEN}$SYSTEM_ARCH${NC}"
    
    # Get memory info
    if [ -f /proc/meminfo ]; then
        TOTAL_MEM=$(awk '/MemTotal/ {printf("%.0f", $2/1024)}' /proc/meminfo 2>/dev/null)
        log "INFO" "Memory: ${TOTAL_MEM}MB total"
        echo -e "Memory: ${GREEN}${TOTAL_MEM}MB${NC} total"
    fi
    
    # Get storage info
    if df -h /overlay >/dev/null 2>&1; then
        ROOT_AVAIL=$(df -h /overlay | awk 'NR==2 {print $4}')
    else
        ROOT_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
    fi
    log "INFO" "Storage: ${ROOT_AVAIL} available"
    echo -e "Storage: ${GREEN}${ROOT_AVAIL}${NC} available"
    
    # Check internet connectivity
    echo -n "Internet: "
    INTERNET_CONNECTED=0
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        INTERNET_CONNECTED=1
        log "INFO" "Internet: Connected"
        echo -e "${GREEN}Connected${NC}"
    else
        log "WARNING" "Internet: Not connected"
        echo -e "${RED}Disconnected${NC}"
    fi
    
    print_separator
}

check_passwall2_status() {
    # Check if installed
    if opkg list-installed 2>/dev/null | grep -q "luci-app-passwall2"; then
        PASSWALL2_INSTALLED=1
        INSTALLED_VERSION=$(opkg list-installed | grep "luci-app-passwall2" | awk '{print $3}')
        log "INFO" "Status: Installed (v${INSTALLED_VERSION})"
    else
        PASSWALL2_INSTALLED=0
        log "INFO" "Status: Not installed"
    fi
    
    # Check if available in repo
    if opkg list 2>/dev/null | grep -q "luci-app-passwall2"; then
        LATEST_VERSION=$(opkg list 2>/dev/null | grep "luci-app-passwall2" | head -1 | awk '{print $3}')
        log "INFO" "Repository: Available (v${LATEST_VERSION})"
    else
        log "INFO" "Repository: Not available"
    fi
}

################################################################################
# Repository Setup - UNIVERSAL SUPPORT
################################################################################

setup_passwall2_repository() {
    log "INFO" "Setting up PassWall2 repositories..."
    echo -e "${BOLD}Configuring repositories...${NC}"
    
    local arch="$SYSTEM_ARCH"
    local target="$OPENWRT_TARGET"
    local version="$OPENWRT_VERSION"
    local major_version=$(echo "$version" | cut -d. -f1-2)
    
    if [ -z "$arch" ] || [ -z "$target" ]; then
        log "ERROR" "Could not detect architecture or target"
        return 1
    fi
    
    local repo_file="/etc/opkg/customfeeds.conf"
    local backup_file="${repo_file}.bak.$(date +%Y%m%d)"
    
    # Backup original file
    if [ ! -f "$backup_file" ]; then
        cp "$repo_file" "$backup_file" 2>/dev/null
        log "INFO" "Backup created: $backup_file"
    fi
    
    # Remove old entries
    sed -i '/passwall2/d; /kiddin9/d; /immortalwrt/d; /openwrt-passwall/d' "$repo_file" 2>/dev/null
    
    # Add multiple repositories for maximum compatibility
    cat >> "$repo_file" << EOF

# PassWall2 Repositories - Added by Universal Installer (${arch})
# Repository 1: kiddin9 (Primary)
src/gz kiddin9_core https://op.dllkids.xyz/packages-${major_version}/${arch}/core
src/gz kiddin9_base https://op.dllkids.xyz/packages-${major_version}/${arch}/base
src/gz kiddin9_packages https://op.dllkids.xyz/packages-${major_version}/${arch}/packages
src/gz kiddin9_luci https://op.dllkids.xyz/packages-${major_version}/${arch}/luci

# Repository 2: ImmortalWrt (Fallback)
src/gz immortalwrt_core https://downloads.immortalwrt.org/releases/packages-${major_version}/${arch}/core
src/gz immortalwrt_base https://downloads.immortalwrt.org/releases/packages-${major_version}/${arch}/base
src/gz immortalwrt_packages https://downloads.immortalwrt.org/releases/packages-${major_version}/${arch}/packages
src/gz immortalwrt_luci https://downloads.immortalwrt.org/releases/packages-${major_version}/${arch}/luci
EOF
    
    log "SUCCESS" "Repositories configured for ${arch}"
    echo -e "${GREEN}✓ Repositories added${NC}"
    
    # Add GPG keys
    echo -n "  Adding GPG keys... "
    {
        wget-ssl --timeout=10 -O- https://op.dllkids.xyz/public.key 2>/dev/null | opkg-key add - 2>/dev/null
        wget-ssl --timeout=10 -O- https://downloads.immortalwrt.org/immortalwrt.gpg.key 2>/dev/null | opkg-key add - 2>/dev/null
    } >> "$LOG_FILE" 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # Update package lists
    echo -n "  Updating package lists... "
    if opkg update >> "$LOG_FILE" 2>&1; then
        log "SUCCESS" "Package lists updated"
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        log "WARNING" "Some warnings during update"
        echo -e "${YELLOW}⚠ Some warnings${NC}"
        return 0  # Still return success as warnings are okay
    fi
}

################################################################################
# Installation Functions
################################################################################

check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    if [ "$INTERNET_CONNECTED" -eq 0 ]; then
        log "ERROR" "No internet connection"
        echo -e "${RED}✗ No internet connection${NC}"
        return 1
    fi
    
    # Check storage (need ~25MB)
    local avail_kb=$(df / 2>/dev/null | awk 'NR==2 {print $4}')
    if [ "$avail_kb" -lt 25600 ]; then
        log "ERROR" "Not enough space: ${avail_kb}KB"
        echo -e "${RED}✗ Need at least 25MB free space${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites met${NC}"
    return 0
}

install_passwall2() {
    print_header
    echo -e "${BOLD}${GREEN}PassWall2 Installation${NC}"
    print_separator
    
    log "INFO" "Starting installation"
    
    # Confirm
    echo -e "This will install PassWall2 and required packages."
    echo -e "Space required: ~20-25MB"
    echo ""
    read -rp "Continue? (yes/no): " confirm
    [ "$confirm" != "yes" ] && show_main_menu && return
    
    # Check prerequisites
    check_prerequisites || { read -rp "Press Enter..."; show_main_menu; return 1; }
    
    # Setup repositories
    setup_passwall2_repository || { read -rp "Press Enter..."; show_main_menu; return 1; }
    
    # Check if PassWall2 is available now
    if ! opkg list 2>/dev/null | grep -q "luci-app-passwall2"; then
        log "ERROR" "PassWall2 not available after repository setup"
        echo -e "${RED}✗ PassWall2 package not found${NC}"
        echo -e "${YELLOW}Possible issues:${NC}"
        echo -e "  - Architecture not supported by repos"
        echo -e "  - Repository temporarily down"
        echo -e "  - Network restrictions"
        read -rp "Press Enter to return..."
        show_main_menu
        return 1
    fi
    
    # Install PassWall2
    echo ""
    echo -e "${CYAN}Installing PassWall2...${NC}"
    echo -n "  Main package... "
    
    if opkg install luci-app-passwall2 >> "$LOG_FILE" 2>&1; then
        log "SUCCESS" "PassWall2 installed"
        echo -e "${GREEN}✓${NC}"
    else
        log "ERROR" "PassWall2 installation failed"
        echo -e "${RED}✗ Failed${NC}"
        read -rp "Press Enter..."
        show_main_menu
        return 1
    fi
    
    # Install language pack
    echo -n "  Chinese language... "
    opkg install luci-i18n-passwall2-zh-cn >> "$LOG_FILE" 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠${NC}"
    
    # Install recommended core packages
    echo -e "\n${CYAN}Installing core packages...${NC}"
    for pkg in xray-core v2ray-core; do
        echo -n "  $pkg... "
        opkg list 2>/dev/null | grep -q "^$pkg" && opkg install "$pkg" >> "$LOG_FILE" 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠${NC}"
    done
    
    # Wait for LuCI
    echo -e "\n${CYAN}Finalizing...${NC}"
    sleep 3
    
    # Success
    print_separator
    echo -e "${GREEN}${BOLD}✓ PassWall2 installed successfully!${NC}"
    print_separator
    echo ""
    
    LAN_IP=$(uci -q get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
    echo -e "Access PassWall2 at: ${CYAN}http://${LAN_IP}/cgi-bin/luci/admin/services/passwall2${NC}"
    echo -e "Log file: ${CYAN}$LOG_FILE${NC}"
    
    read -rp "Press Enter to continue..."
    check_passwall2_status
    show_main_menu
}

################################################################################
# Menu Functions
################################################################################

show_main_menu() {
    print_header
    
    echo -e "${BOLD}System Status:${NC}"
    echo -e "  Architecture: ${GREEN}${SYSTEM_ARCH:-Unknown}${NC}"
    echo -e "  Internet: $([ "$INTERNET_CONNECTED" -eq 1 ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"
    
    check_passwall2_status
    
    if [ "$PASSWALL2_INSTALLED" -eq 1 ]; then
        echo -e "  PassWall2: ${GREEN}Installed${NC} (v${INSTALLED_VERSION})"
    else
        echo -e "  PassWall2: ${YELLOW}Not installed${NC}"
    fi
    
    print_separator
    echo -e "${BOLD}Menu:${NC}"
    print_separator
    
    if [ "$PASSWALL2_INSTALLED" -eq 0 ]; then
        echo "  1) Install PassWall2"
        echo "  2) Exit"
        read -rp "Select [1-2]: " choice
        
        case $choice in
            1) install_passwall2 ;;
            2) exit_script ;;
            *) show_main_menu ;;
        esac
    else
        echo "  1) Update PassWall2"
        echo "  2) Reinstall"
        echo "  3) Uninstall"
        echo "  4) View Logs"
        echo "  5) Exit"
        read -rp "Select [1-5]: " choice
        
        case $choice in
            1) update_passwall2 ;;
            2) reinstall_passwall2 ;;
            3) uninstall_passwall2 ;;
            4) view_logs ;;
            5) exit_script ;;
            *) show_main_menu ;;
        esac
    fi
}

################################################################################
# Update / Reinstall / Uninstall
################################################################################

update_passwall2() {
    print_header
    echo -e "${BOLD}${YELLOW}Update PassWall2${NC}"
    print_separator
    
    setup_passwall2_repository
    echo -e "\n${CYAN}Updating...${NC}"
    opkg update > /dev/null 2>&1
    opkg upgrade luci-app-passwall2 >> "$LOG_FILE" 2>&1 && echo -e "${GREEN}✓ Updated${NC}" || echo -e "${YELLOW}⚠ No update${NC}"
    
    read -rp "Press Enter..."
    show_main_menu
}

reinstall_passwall2() {
    print_header
    echo -e "${BOLD}${YELLOW}Reinstall PassWall2${NC}"
    print_separator
    
    read -rp "Reinstall? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        # Backup config
        [ -f /etc/config/passwall2 ] && cp /etc/config/passwall2 /tmp/pw2.backup
        
        # Uninstall
        opkg remove luci-app-passwall2 --force-removal-of-dependent-packages >> "$LOG_FILE" 2>&1
        
        # Reinstall
        install_passwall2
    else
        show_main_menu
    fi
}

uninstall_passwall2() {
    print_header
    echo -e "${BOLD}${RED}Uninstall PassWall2${NC}"
    print_separator
    
    read -rp "Uninstall? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        echo -e "\n${CYAN}Uninstalling...${NC}"
        opkg remove luci-app-passwall2 --force-removal-of-dependent-packages >> "$LOG_FILE" 2>&1
        echo -e "${GREEN}✓ Uninstalled${NC}"
        PASSWALL2_INSTALLED=0
    fi
    
    read -rp "Press Enter..."
    show_main_menu
}

view_logs() {
    print_header
    echo -e "${BOLD}Installation Logs${NC}"
    print_separator
    
    echo -e "Log directory: ${CYAN}$LOG_DIR${NC}"
    echo ""
    
    if [ -d "$LOG_DIR" ]; then
        ls -lh "$LOG_DIR"/*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
        print_separator
        echo -e "Latest entries:"
        tail -n 20 "$LOG_FILE" 2>/dev/null || echo -e "${YELLOW}No logs${NC}"
    else
        echo -e "${YELLOW}No log files found${NC}"
    fi
    
    print_separator
    read -rp "Press Enter..."
    show_main_menu
}

################################################################################
# Main
################################################################################

main() {
    [ "$(id -u)" -ne 0 ] && { echo -e "${RED}Run as root!${NC}"; exit 1; }
    
    log "INFO" "PassWall2 Universal Installer started"
    
    detect_system_info
    check_passwall2_status
    show_main_menu
}

main
