#!/bin/bash

################################################################################
# PassWall2 Smart Installer for OpenWrt
# Author: Your GitHub Username
# Description: Intelligent installer for PassWall2 with automatic detection
# Version: 2.0.0 (Fixed & Enhanced)
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

# Configuration
PASSWALL2_REPO="xiaorouji/openwrt-passwall2"
PACKAGES_REPO="xiaorouji/openwrt-passwall-packages"

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
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
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
    echo "║                                                                ║"
    echo "║        PassWall2 Smart Installer for OpenWrt                   ║"
    echo "║                    Version 2.0.0                               ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_separator() {
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
}

show_spinner() {
    local pid=$1
    local message=$2
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\r"
    done
    printf "    \r"
}

################################################################################
# System Detection Functions
################################################################################

detect_system_info() {
    log "INFO" "Starting system detection..."
    
    print_separator
    echo -e "${BOLD}Detecting System Information...${NC}"
    print_separator
    
    # Get OpenWrt version
    if [ -f /etc/openwrt_release ]; then
        source /etc/openwrt_release
        OPENWRT_VERSION="$DISTRIB_RELEASE"
        OPENWRT_CODENAME="$DISTRIB_CODENAME"
        OPENWRT_ARCH="$DISTRIB_ARCH"
        log "INFO" "OpenWrt Version: $OPENWRT_VERSION ($OPENWRT_CODENAME)"
        echo -e "OpenWrt Version: ${GREEN}$OPENWRT_VERSION ($OPENWRT_CODENAME)${NC}"
    else
        log "ERROR" "This system is not OpenWrt!"
        echo -e "${RED}Error: This script only works on OpenWrt systems!${NC}"
        exit 1
    fi
    
    # Get architecture
    SYSTEM_ARCH=$(uname -m)
    log "INFO" "System Architecture: $SYSTEM_ARCH"
    echo -e "Architecture: ${GREEN}$SYSTEM_ARCH${NC}"
    
    # Get CPU info
    CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -n 1 | cut -d: -f2 | xargs)
    if [ -z "$CPU_MODEL" ]; then
        CPU_MODEL=$(grep "system type" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    fi
    log "INFO" "CPU Model: ${CPU_MODEL:-Unknown}"
    echo -e "CPU Model: ${GREEN}${CPU_MODEL:-Unknown}${NC}"
    
    # Get memory info (compatible with OpenWrt)
    if [ -f /proc/meminfo ]; then
        TOTAL_MEM=$(awk '/MemTotal/ {printf("%.0f", $2/1024)}' /proc/meminfo 2>/dev/null)
        FREE_MEM=$(awk '/MemAvailable/ {printf("%.0f", $2/1024)}' /proc/meminfo 2>/dev/null)
        if [ -z "$FREE_MEM" ]; then
            FREE_MEM=$(awk '/MemFree/ {printf("%.0f", $2/1024)}' /proc/meminfo 2>/dev/null)
        fi
        log "INFO" "Memory: ${FREE_MEM}MB free / ${TOTAL_MEM}MB total"
        echo -e "Memory: ${GREEN}${FREE_MEM}MB${NC} free / ${TOTAL_MEM}MB total"
    else
        log "WARNING" "Could not detect memory information"
        echo -e "Memory: ${YELLOW}Unknown${NC}"
    fi
    
    # Get storage info (OpenWrt compatible)
    if df -h /overlay >/dev/null 2>&1; then
        ROOT_TOTAL=$(df -h /overlay | awk 'NR==2 {print $2}')
        ROOT_USED=$(df -h /overlay | awk 'NR==2 {print $3}')
        ROOT_AVAIL=$(df -h /overlay | awk 'NR==2 {print $4}')
        ROOT_PERCENT=$(df -h /overlay | awk 'NR==2 {print $5}')
    else
        ROOT_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
        ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
        ROOT_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
        ROOT_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
    fi
    log "INFO" "Storage: ${ROOT_AVAIL} available / ${ROOT_TOTAL} total (${ROOT_PERCENT} used)"
    echo -e "Storage: ${GREEN}${ROOT_AVAIL}${NC} available / ${ROOT_TOTAL} total (${ROOT_PERCENT} used)"
    
    # Check internet connectivity
    echo -n "Checking internet connectivity... "
    INTERNET_CONNECTED=0
    if ping -c 1 -W 3 google.com >/dev/null 2>&1 || ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        INTERNET_CONNECTED=1
        log "INFO" "Internet connection: Available"
        echo -e "${GREEN}Connected${NC}"
    else
        log "WARNING" "Internet connection: Not available"
        echo -e "${RED}Not Connected${NC}"
    fi
    
    print_separator
}

check_passwall2_status() {
    log "INFO" "Checking PassWall2 installation status..."
    
    if opkg list-installed 2>/dev/null | grep -q "luci-app-passwall2"; then
        PASSWALL2_INSTALLED=1
        INSTALLED_VERSION=$(opkg list-installed | grep "luci-app-passwall2" | awk '{print $3}')
        log "INFO" "PassWall2 is installed: Version $INSTALLED_VERSION"
    else
        PASSWALL2_INSTALLED=0
        log "INFO" "PassWall2 is not installed"
    fi
}

################################################################################
# Menu Functions
################################################################################

show_main_menu() {
    print_header
    
    echo -e "${BOLD}System Status:${NC}"
    echo -e "  OpenWrt: ${GREEN}${OPENWRT_VERSION:-Unknown}${NC}"
    echo -e "  Architecture: ${GREEN}${OPENWRT_ARCH:-$SYSTEM_ARCH}${NC}"
    echo -e "  Free Space: ${GREEN}${ROOT_AVAIL:-Unknown}${NC}"
    echo -e "  Internet: $((INTERNET_CONNECTED == 1)) && echo -e "${GREEN}Connected${NC}" || echo -e "${RED}Disconnected${NC}")"
    
    if [ "$PASSWALL2_INSTALLED" -eq 1 ]; then
        echo -e "  PassWall2: ${GREEN}Installed${NC} (Version: ${INSTALLED_VERSION:-Unknown})"
    else
        echo -e "  PassWall2: ${YELLOW}Not Installed${NC}"
    fi
    
    print_separator
    echo -e "${BOLD}Available Operations:${NC}"
    print_separator
    
    if [ "$PASSWALL2_INSTALLED" -eq 0 ]; then
        echo "  1) Install PassWall2"
        echo "  2) Check Requirements Only"
        echo "  3) Exit"
        echo ""
        read -rp "Select an option [1-3]: " choice
        
        case $choice in
            1)
                install_passwall2
                ;;
            2)
                check_prerequisites
                read -rp "Press Enter to return to menu..."
                show_main_menu
                ;;
            3)
                exit_script
                ;;
            *)
                log "WARNING" "Invalid option selected: $choice"
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 2
                show_main_menu
                ;;
        esac
    else
        echo "  1) Update PassWall2"
        echo "  2) Reinstall PassWall2"
        echo "  3) Uninstall PassWall2"
        echo "  4) View Installation Logs"
        echo "  5) Exit"
        echo ""
        read -rp "Select an option [1-5]: " choice
        
        case $choice in
            1)
                update_passwall2
                ;;
            2)
                reinstall_passwall2
                ;;
            3)
                uninstall_passwall2
                ;;
            4)
                view_logs
                ;;
            5)
                exit_script
                ;;
            *)
                log "WARNING" "Invalid option selected: $choice"
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 2
                show_main_menu
                ;;
        esac
    fi
}

################################################################################
# Installation Functions
################################################################################

check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    local errors=0
    
    if [ "$INTERNET_CONNECTED" -eq 0 ]; then
        log "ERROR" "Internet connection is required for installation"
        echo -e "${RED}Error: Internet connection is required!${NC}"
        echo "Please connect to the internet and try again."
        errors=$((errors + 1))
    fi
    
    # Check available space (need at least 20MB for PassWall2)
    local avail_kb
    avail_kb=$(df / 2>/dev/null | awk 'NR==2 {print $4}')
    if [ "$avail_kb" -lt 20480 ]; then
        log "ERROR" "Insufficient storage space: ${avail_kb}KB available"
        echo -e "${RED}Error: Insufficient storage space!${NC}"
        echo "At least 20MB free space is required for PassWall2."
        errors=$((errors + 1))
    fi
    
    # Check if opkg is available
    if ! command -v opkg >/dev/null 2>&1; then
        log "ERROR" "opkg package manager not found"
        echo -e "${RED}Error: opkg package manager not found!${NC}"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}✓ All prerequisites met${NC}"
        return 0
    else
        return 1
    fi
}

update_package_lists() {
    log "INFO" "Updating package lists..."
    echo -e "${BOLD}Updating package lists...${NC}"
    
    if opkg update >> "$LOG_FILE" 2>&1; then
        log "SUCCESS" "Package lists updated successfully"
        echo -e "${GREEN}✓ Package lists updated${NC}"
        return 0
    else
        log "ERROR" "Failed to update package lists"
        echo -e "${RED}✗ Failed to update package lists${NC}"
        echo "Check log file: $LOG_FILE"
        return 1
    fi
}

install_dependencies() {
    log "INFO" "Installing dependencies..."
    echo -e "${BOLD}Installing prerequisites...${NC}"
    
    # Essential dependencies for PassWall2
    local deps=(
        "ca-bundle"
        "ca-certificates"
        "libustream-openssl"
        "wget-ssl"
        "curl"
        "iptables"
        "ip6tables"
        "dnsmasq-full"
    )
    
    local installed_count=0
    for dep in "${deps[@]}"; do
        if opkg list-installed 2>/dev/null | grep -q "^${dep} "; then
            log "INFO" "Dependency already installed: $dep"
        else
            echo -n "  Installing $dep... "
            if opkg install "$dep" >> "$LOG_FILE" 2>&1; then
                log "SUCCESS" "Installed dependency: $dep"
                echo -e "${GREEN}✓${NC}"
                installed_count=$((installed_count + 1))
            else
                log "WARNING" "Failed to install dependency: $dep"
                echo -e "${YELLOW}⚠${NC}"
            fi
        fi
    done
    
    log "SUCCESS" "Dependencies check completed. Installed: $installed_count"
    return 0
}

get_latest_release() {
    log "INFO" "Fetching latest PassWall2 release information..."
    echo -e "${BOLD}Checking for latest version...${NC}"
    
    # Try to get latest release from GitHub API (fixed URL)
    local api_url="https://api.github.com/repos/${PASSWALL2_REPO}/releases/latest"
    LATEST_VERSION=""
    
    if command -v curl >/dev/null 2>&1; then
        LATEST_VERSION=$(curl -s --connect-timeout 10 "$api_url" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget-ssl >/dev/null 2>&1; then
        LATEST_VERSION=$(wget-ssl --timeout=10 -qO- "$api_url" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    fi
    
    if [ -n "$LATEST_VERSION" ]; then
        log "INFO" "Latest version available: $LATEST_VERSION"
        echo -e "Latest version: ${GREEN}$LATEST_VERSION${NC}"
        return 0
    else
        log "WARNING" "Could not fetch latest version from GitHub"
        echo -e "${YELLOW}⚠ Could not check latest version, will use opkg repository${NC}"
        return 1
    fi
}

install_passwall2_packages() {
    log "INFO" "Installing PassWall2 packages..."
    print_separator
    echo -e "${BOLD}Installing PassWall2...${NC}"
    print_separator
    
    # Install core package first
    echo -e "\n${CYAN}Installing main PassWall2 package...${NC}"
    echo -n "  Installing luci-app-passwall2... "
    
    if opkg install "luci-app-passwall2" >> "$LOG_FILE" 2>&1; then
        log "SUCCESS" "Installed luci-app-passwall2"
        echo -e "${GREEN}✓${NC}"
    else
        log "ERROR" "Failed to install luci-app-passwall2"
        echo -e "${RED}✗ Installation failed${NC}"
        echo -e "${RED}This might be due to incompatible architecture or repository issues${NC}"
        echo -e "${YELLOW}Please check the log file: $LOG_FILE${NC}"
        return 1
    fi
    
    # Install language pack
    echo -n "  Installing language pack... "
    if opkg install "luci-i18n-passwall2-zh-cn" >> "$LOG_FILE" 2>&1; then
        log "SUCCESS" "Installed language pack"
        echo -e "${GREEN}✓${NC}"
    else
        log "WARNING" "Language pack not available or failed to install"
        echo -e "${YELLOW}⚠${NC}"
    fi
    
    # Install optional core packages (best effort)
    echo -e "\n${CYAN}Installing optional core packages...${NC}"
    local core_packages=(
        "xray-core"
        "v2ray-core"
        "shadowsocks-rust-sslocal"
        "shadowsocks-rust-ssserver"
        "hysteria"
        "tuic-client"
    )
    
    for package in "${core_packages[@]}"; do
        if opkg list | grep -q "^${package}"; then
            echo -n "  Installing $package... "
            if opkg install "$package" >> "$LOG_FILE" 2>&1; then
                log "SUCCESS" "Installed: $package"
                echo -e "${GREEN}✓${NC}"
            else
                log "WARNING" "Failed to install: $package"
                echo -e "${YELLOW}⚠${NC}"
            fi
        else
            log "INFO" "Package not available in repository: $package"
            echo -e "  $package... ${YELLOW}not in repo${NC}"
        fi
    done
    
    log "SUCCESS" "PassWall2 installation process completed"
    return 0
}

install_passwall2() {
    print_header
    echo -e "${BOLD}${GREEN}Starting PassWall2 Installation${NC}"
    print_separator
    
    log "INFO" "Installation process started"
    
    # Confirm installation
    echo -e "${YELLOW}PassWall2 will be installed on your system.${NC}"
    echo -e "Estimated space required: ~15-20MB"
    echo ""
    read -rp "Do you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "INFO" "Installation cancelled by user"
        show_main_menu
        return 0
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        read -rp "Press Enter to return to menu..."
        show_main_menu
        return 1
    fi
    
    # Update package lists
    if ! update_package_lists; then
        read -rp "Press Enter to return to menu..."
        show_main_menu
        return 1
    fi
    
    # Install dependencies
    if ! install_dependencies; then
        read -rp "Press Enter to return to menu..."
        show_main_menu
        return 1
    fi
    
    # Get latest release info (optional)
    get_latest_release
    
    # Install PassWall2 packages
    if ! install_passwall2_packages; then
        read -rp "Press Enter to return to menu..."
        show_main_menu
        return 1
    fi
    
    # Wait a moment for LuCI to refresh
    echo -e "\n${CYAN}Finalizing installation...${NC}"
    sleep 3
    
    # Final success message
    print_separator
    echo -e "${GREEN}${BOLD}✓ PassWall2 installed successfully!${NC}"
    print_separator
    echo ""
    echo -e "You can now access PassWall2 at:"
    
    # Get LAN IP safely
    LAN_IP=$(uci -q get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
    echo -e "${CYAN}http://${LAN_IP}/cgi-bin/luci/admin/services/passwall2${NC}"
    echo ""
    echo -e "Log file saved at: ${CYAN}$LOG_FILE${NC}"
    log "SUCCESS" "Installation completed successfully"
    
    read -rp "Press Enter to return to menu..."
    
    # Refresh status
    check_passwall2_status
    show_main_menu
}

################################################################################
# Update Function
################################################################################

update_passwall2() {
    print_header
    echo -e "${BOLD}${YELLOW}Updating PassWall2${NC}"
    print_separator
    
    log "INFO" "Update process started"
    
    if ! check_prerequisites; then
        show_main_menu
        return 1
    fi
    
    echo -e "Current version: ${GREEN}${INSTALLED_VERSION:-Unknown}${NC}"
    echo ""
    
    if ! update_package_lists; then
        read -rp "Press Enter to return to menu..."
        show_main_menu
        return 1
    fi
    
    echo -e "\n${BOLD}Upgrading PassWall2...${NC}"
    if opkg upgrade "luci-app-passwall2" >> "$LOG_FILE" 2>&1; then
        log "SUCCESS" "PassWall2 updated successfully"
        echo -e "${GREEN}✓ PassWall2 updated successfully!${NC}"
        # Also update core packages
        opkg upgrade xray-core v2ray-core >> "$LOG_FILE" 2>&1
    else
        log "INFO" "No updates available or update failed"
        echo -e "${YELLOW}⚠ No updates available or already up to date${NC}"
    fi
    
    read -rp "Press Enter to return to menu..."
    check_passwall2_status
    show_main_menu
}

################################################################################
# Reinstall Function
################################################################################

reinstall_passwall2() {
    print_header
    echo -e "${BOLD}${YELLOW}Reinstalling PassWall2${NC}"
    print_separator
    
    log "INFO" "Reinstall process started"
    
    echo -e "${YELLOW}Warning: This will remove and reinstall PassWall2.${NC}"
    echo -e "${YELLOW}Your configuration will be preserved if possible.${NC}"
    echo ""
    read -rp "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "INFO" "Reinstallation cancelled by user"
        show_main_menu
        return 0
    fi
    
    # Backup configuration
    log "INFO" "Backing up configuration..."
    echo -e "\nBacking up configuration..."
    if [ -f /etc/config/passwall2 ]; then
        cp /etc/config/passwall2 /tmp/passwall2.backup
        log "SUCCESS" "Configuration backed up"
        echo -e "${GREEN}✓ Configuration backed up${NC}"
    else
        log "INFO" "No existing configuration to backup"
        echo -e "${YELLOW}⚠ No existing configuration found${NC}"
    fi
    
    # Uninstall
    uninstall_passwall2_internal
    
    # Reinstall
    install_passwall2
}

################################################################################
# Uninstall Function
################################################################################

uninstall_passwall2_internal() {
    log "INFO" "Uninstalling PassWall2..."
    echo -e "\n${BOLD}Removing PassWall2 packages...${NC}"
    
    # Get all passwall2 related packages (more specific)
    local packages=$(opkg list-installed 2>/dev/null | grep -E "passwall2|luci-app-passwall2" | awk '{print $1}')
    
    if [ -z "$packages" ]; then
        log "INFO" "No PassWall2 packages found to remove"
        echo -e "${YELLOW}⚠ No PassWall2 packages found${NC}"
        return 0
    fi
    
    for package in $packages; do
        echo -n "  Removing $package... "
        if opkg remove "$package" --force-removal-of-dependent-packages >> "$LOG_FILE" 2>&1; then
            log "SUCCESS" "Removed: $package"
            echo -e "${GREEN}✓${NC}"
        else
            log "WARNING" "Failed to remove: $package"
            echo -e "${YELLOW}⚠${NC}"
        fi
    done
    
    log "SUCCESS" "PassWall2 uninstalled"
}

uninstall_passwall2() {
    print_header
    echo -e "${BOLD}${RED}Uninstalling PassWall2${NC}"
    print_separator
    
    log "INFO" "Uninstall process started"
    
    echo -e "${RED}Warning: This will completely remove PassWall2 from your system.${NC}"
    echo -e "${RED}All configurations will be deleted.${NC}"
    echo ""
    read -rp "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "INFO" "Uninstallation cancelled by user"
        show_main_menu
        return 0
    fi
    
    uninstall_passwall2_internal
    
    # Also remove core packages that were installed with PassWall2
    echo -e "\n${BOLD}Removing associated core packages...${NC}"
    local core_packages=("xray-core" "v2ray-core" "hysteria" "tuic-client")
    for pkg in "${core_packages[@]}"; do
        if opkg list-installed 2>/dev/null | grep -q "^$pkg "; then
            opkg remove "$pkg" >> "$LOG_FILE" 2>&1
            echo -e "  Removed $pkg"
        fi
    done
    
    print_separator
    echo -e "${GREEN}✓ PassWall2 has been uninstalled${NC}"
    print_separator
    
    read -rp "Press Enter to return to menu..."
    
    PASSWALL2_INSTALLED=0
    show_main_menu
}

################################################################################
# Utility Functions
################################################################################

view_logs() {
    print_header
    echo -e "${BOLD}Installation Logs${NC}"
    print_separator
    
    echo -e "Log files location: ${CYAN}$LOG_DIR${NC}"
    echo ""
    if [ -d "$LOG_DIR" ]; then
        echo -e "Available log files:"
        ls -lh "$LOG_DIR"/*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    else
        echo -e "${YELLOW}No log files found${NC}"
    fi
    
    print_separator
    echo -e "\nRecent log entries from current session:"
    print_separator
    if [ -f "$LOG_FILE" ]; then
        tail -n 30 "$LOG_FILE" 2>/dev/null || echo -e "${YELLOW}Could not read log file${NC}"
    else
        echo -e "${YELLOW}No log file for this session${NC}"
    fi
    
    print_separator
    read -rp "Press Enter to return to menu..."
    show_main_menu
}

exit_script() {
    print_header
    echo -e "${BOLD}Thank you for using PassWall2 Smart Installer!${NC}"
    print_separator
    echo ""
    echo -e "Installation logs saved at: ${CYAN}$LOG_FILE${NC}"
    echo ""
    log "INFO" "Script terminated by user"
    exit 0
}

################################################################################
# Main Execution
################################################################################

main() {
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root!${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    log "INFO" "Script started"
    log "INFO" "========================================"
    
    # Detect system information
    detect_system_info
    
    # Check PassWall2 status (don't exit on failure)
    check_passwall2_status
    
    # Show main menu
    show_main_menu
}

# Start the script
main
