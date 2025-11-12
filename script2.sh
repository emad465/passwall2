#!/bin/sh

################################################################################
# PassWall2 Smart Installer for OpenWrt (ash compatible)
# Author: emad465
# Description: Intelligent installer for PassWall2 with automatic detection
# Version: 1.0.0
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Log file
LOG_DIR="/tmp/passwall2_installer"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Global variables
PASSWALL2_INSTALLED=0
INSTALLED_VERSION=""
INTERNET_CONNECTED=0
OPENWRT_VERSION=""
OPENWRT_ARCH=""
SYSTEM_ARCH=""

################################################################################
# Logging Functions
################################################################################

log() {
    level="$1"
    shift
    message="$*"
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        INFO)
            echo "${BLUE}[INFO]${NC} $message"
            ;;
        SUCCESS)
            echo "${GREEN}[SUCCESS]${NC} $message"
            ;;
        WARNING)
            echo "${YELLOW}[WARNING]${NC} $message"
            ;;
        ERROR)
            echo "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

################################################################################
# UI Functions
################################################################################

print_header() {
    clear
    echo "${CYAN}${BOLD}"
    echo "================================================================"
    echo "                                                                "
    echo "        PassWall2 Smart Installer for OpenWrt                   "
    echo "                    Version 1.0.0                               "
    echo "                                                                "
    echo "================================================================"
    echo "${NC}"
}

print_separator() {
    echo "${CYAN}----------------------------------------------------------------${NC}"
}

################################################################################
# System Detection Functions
################################################################################

detect_system_info() {
    log INFO "Starting system detection..."
    
    print_separator
    echo "${BOLD}Detecting System Information...${NC}"
    print_separator
    
    # Get OpenWrt version
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release
        OPENWRT_VERSION="$DISTRIB_RELEASE"
        OPENWRT_CODENAME="$DISTRIB_CODENAME"
        OPENWRT_ARCH="$DISTRIB_ARCH"
        log INFO "OpenWrt Version: $OPENWRT_VERSION ($OPENWRT_CODENAME)"
        echo "OpenWrt Version: ${GREEN}$OPENWRT_VERSION ($OPENWRT_CODENAME)${NC}"
    else
        log ERROR "This system is not OpenWrt!"
        echo "${RED}Error: This script only works on OpenWrt systems!${NC}"
        exit 1
    fi
    
    # Get architecture
    SYSTEM_ARCH=$(uname -m)
    log INFO "System Architecture: $SYSTEM_ARCH"
    echo "Architecture: ${GREEN}$SYSTEM_ARCH${NC}"
    
    # Get CPU info
    CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -n 1 | cut -d: -f2 | sed 's/^[ \t]*//')
    if [ -z "$CPU_MODEL" ]; then
        CPU_MODEL=$(cat /proc/cpuinfo | grep "system type" | cut -d: -f2 | sed 's/^[ \t]*//')
    fi
    log INFO "CPU Model: $CPU_MODEL"
    if [ -n "$CPU_MODEL" ]; then
        echo "CPU Model: ${GREEN}${CPU_MODEL}${NC}"
    else
        echo "CPU Model: ${GREEN}Unknown${NC}"
    fi
    
    # Get memory info
    TOTAL_MEM=$(free -m | awk '/Mem:/ {print $2}')
    FREE_MEM=$(free -m | awk '/Mem:/ {print $4}')
    log INFO "Memory: ${FREE_MEM}MB free / ${TOTAL_MEM}MB total"
    echo "Memory: ${GREEN}${FREE_MEM}MB${NC} free / ${TOTAL_MEM}MB total"
    
    # Get storage info
    ROOT_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
    ROOT_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
    ROOT_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
    log INFO "Storage: ${ROOT_AVAIL} available / ${ROOT_TOTAL} total (${ROOT_PERCENT} used)"
    echo "Storage: ${GREEN}${ROOT_AVAIL}${NC} available / ${ROOT_TOTAL} total (${ROOT_PERCENT} used)"
    
    # Check internet connectivity
    printf "Checking internet connectivity... "
    if ping -c 1 -W 3 google.com >/dev/null 2>&1 || ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        INTERNET_CONNECTED=1
        log INFO "Internet connection: Available"
        echo "${GREEN}Connected${NC}"
    else
        INTERNET_CONNECTED=0
        log WARNING "Internet connection: Not available"
        echo "${RED}Not Connected${NC}"
    fi
    
    print_separator
}

check_passwall2_status() {
    log INFO "Checking PassWall2 installation status..."
    
    if opkg list-installed | grep -q "luci-app-passwall2"; then
        PASSWALL2_INSTALLED=1
        INSTALLED_VERSION=$(opkg list-installed | grep "luci-app-passwall2" | awk '{print $3}')
        log INFO "PassWall2 is installed: Version $INSTALLED_VERSION"
        return 0
    else
        PASSWALL2_INSTALLED=0
        log INFO "PassWall2 is not installed"
        return 1
    fi
}

################################################################################
# Menu Functions
################################################################################

show_main_menu() {
    print_header
    
    echo "${BOLD}System Status:${NC}"
    echo "  OpenWrt: ${GREEN}$OPENWRT_VERSION${NC}"
    echo "  Architecture: ${GREEN}$OPENWRT_ARCH${NC}"
    echo "  Free Space: ${GREEN}$ROOT_AVAIL${NC}"
    if [ "$INTERNET_CONNECTED" -eq 1 ]; then
        echo "  Internet: ${GREEN}Connected${NC}"
    else
        echo "  Internet: ${RED}Disconnected${NC}"
    fi
    
    if [ "$PASSWALL2_INSTALLED" -eq 1 ]; then
        echo "  PassWall2: ${GREEN}Installed${NC} (Version: $INSTALLED_VERSION)"
    else
        echo "  PassWall2: ${YELLOW}Not Installed${NC}"
    fi
    
    print_separator
    echo "${BOLD}Available Operations:${NC}"
    print_separator
    
    if [ "$PASSWALL2_INSTALLED" -eq 0 ]; then
        echo "  1) Install PassWall2"
        echo "  2) Exit"
        echo ""
        printf "Select an option [1-2]: "
        read choice
        
        case "$choice" in
            1)
                install_passwall2
                ;;
            2)
                exit_script
                ;;
            *)
                log WARNING "Invalid option selected: $choice"
                echo "${RED}Invalid option. Please try again.${NC}"
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
        printf "Select an option [1-5]: "
        read choice
        
        case "$choice" in
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
                log WARNING "Invalid option selected: $choice"
                echo "${RED}Invalid option. Please try again.${NC}"
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
    log INFO "Checking prerequisites..."
    
    if [ "$INTERNET_CONNECTED" -eq 0 ]; then
        log ERROR "Internet connection is required for installation"
        echo "${RED}Error: Internet connection is required!${NC}"
        echo "Please connect to the internet and try again."
        printf "Press Enter to return to menu..."
        read dummy
        return 1
    fi
    
    # Check available space (need at least 10MB)
    avail_kb=$(df / | awk 'NR==2 {print $4}')
    if [ "$avail_kb" -lt 10240 ]; then
        log ERROR "Insufficient storage space: ${avail_kb}KB available"
        echo "${RED}Error: Insufficient storage space!${NC}"
        echo "At least 10MB free space is required."
        printf "Press Enter to return to menu..."
        read dummy
        return 1
    fi
    
    return 0
}

update_package_lists() {
    log INFO "Updating package lists..."
    echo "${BOLD}Updating package lists...${NC}"
    
    if opkg update >> "$LOG_FILE" 2>&1; then
        log SUCCESS "Package lists updated successfully"
        echo "${GREEN}✓ Package lists updated${NC}"
        return 0
    else
        log ERROR "Failed to update package lists"
        echo "${RED}✗ Failed to update package lists${NC}"
        echo "Check log file: $LOG_FILE"
        return 1
    fi
}

install_dependencies() {
    log INFO "Installing dependencies..."
    echo "${BOLD}Installing dependencies...${NC}"
    
    deps="ca-bundle ca-certificates libustream-openssl wget-ssl curl"
    
    for dep in $deps; do
        if ! opkg list-installed | grep -q "^$dep "; then
            printf "  Installing $dep... "
            if opkg install "$dep" >> "$LOG_FILE" 2>&1; then
                log SUCCESS "Installed dependency: $dep"
                echo "${GREEN}✓${NC}"
            else
                log WARNING "Failed to install dependency: $dep (may already be present)"
                echo "${YELLOW}⚠${NC}"
            fi
        else
            log INFO "Dependency already installed: $dep"
            echo "  $dep... ${GREEN}already installed${NC}"
        fi
    done
    
    return 0
}

install_passwall2_packages() {
    log INFO "Installing PassWall2 packages..."
    print_separator
    echo "${BOLD}Installing PassWall2 Packages...${NC}"
    print_separator
    
    # Core packages
    core_packages="luci-app-passwall2"
    
    # Additional packages (dependencies)
    additional_packages="brook chinadns-ng dns2socks dns2tcp hysteria ipt2socks microsocks naiveproxy pdnsd-alt shadowsocks-rust-sslocal shadowsocks-rust-ssserver shadowsocksr-libev-ssr-local shadowsocksr-libev-ssr-redir simple-obfs tcping trojan-plus tuic-client v2ray-core v2ray-plugin xray-core"
    
    # Install core packages
    echo ""
    echo "${CYAN}Installing core packages...${NC}"
    for package in $core_packages; do
        printf "  Installing $package... "
        if opkg install "$package" >> "$LOG_FILE" 2>&1; then
            log SUCCESS "Installed: $package"
            echo "${GREEN}✓${NC}"
        else
            log ERROR "Failed to install: $package"
            echo "${RED}✗${NC}"
            echo "${RED}Installation failed!${NC}"
            echo "Check log file: $LOG_FILE"
            return 1
        fi
    done
    
    # Install additional packages (optional, continue on failure)
    echo ""
    echo "${CYAN}Installing additional packages...${NC}"
    for package in $additional_packages; do
        printf "  Installing $package... "
        if opkg install "$package" >> "$LOG_FILE" 2>&1; then
            log SUCCESS "Installed: $package"
            echo "${GREEN}✓${NC}"
        else
            log WARNING "Could not install: $package (optional)"
            echo "${YELLOW}⚠${NC}"
        fi
    done
    
    log SUCCESS "PassWall2 installation completed"
    return 0
}

install_passwall2() {
    print_header
    echo "${BOLD}${GREEN}Starting PassWall2 Installation${NC}"
    print_separator
    
    log INFO "Installation process started"
    
    # Check prerequisites
    if ! check_prerequisites; then
        show_main_menu
        return 1
    fi
    
    # Update package lists
    if ! update_package_lists; then
        printf "Press Enter to return to menu..."
        read dummy
        show_main_menu
        return 1
    fi
    
    # Install dependencies
    if ! install_dependencies; then
        printf "Press Enter to return to menu..."
        read dummy
        show_main_menu
        return 1
    fi
    
    # Install PassWall2 packages
    if ! install_passwall2_packages; then
        printf "Press Enter to return to menu..."
        read dummy
        show_main_menu
        return 1
    fi
    
    # Final success message
    print_separator
    echo "${GREEN}${BOLD}✓ PassWall2 installed successfully!${NC}"
    print_separator
    echo ""
    echo "You can now access PassWall2 at:"
    router_ip=$(uci get network.lan.ipaddr 2>/dev/null || echo "router-ip")
    echo "${CYAN}http://${router_ip}/cgi-bin/luci/admin/services/passwall2${NC}"
    echo ""
    echo "Log file saved at: ${CYAN}$LOG_FILE${NC}"
    log SUCCESS "Installation completed successfully"
    
    printf "Press Enter to return to menu..."
    read dummy
    
    # Refresh status
    check_passwall2_status
    show_main_menu
}

################################################################################
# Update Function
################################################################################

update_passwall2() {
    print_header
    echo "${BOLD}${YELLOW}Updating PassWall2${NC}"
    print_separator
    
    log INFO "Update process started"
    
    if ! check_prerequisites; then
        show_main_menu
        return 1
    fi
    
    echo "Current version: ${GREEN}$INSTALLED_VERSION${NC}"
    echo ""
    
    if ! update_package_lists; then
        printf "Press Enter to return to menu..."
        read dummy
        show_main_menu
        return 1
    fi
    
    echo ""
    echo "${BOLD}Upgrading PassWall2...${NC}"
    if opkg upgrade "luci-app-passwall2" >> "$LOG_FILE" 2>&1; then
        log SUCCESS "PassWall2 updated successfully"
        echo "${GREEN}✓ PassWall2 updated successfully!${NC}"
    else
        log INFO "No updates available or update failed"
        echo "${YELLOW}⚠ No updates available or already up to date${NC}"
    fi
    
    printf "Press Enter to return to menu..."
    read dummy
    check_passwall2_status
    show_main_menu
}

################################################################################
# Reinstall Function
################################################################################

reinstall_passwall2() {
    print_header
    echo "${BOLD}${YELLOW}Reinstalling PassWall2${NC}"
    print_separator
    
    log INFO "Reinstall process started"
    
    echo "${YELLOW}Warning: This will remove and reinstall PassWall2.${NC}"
    echo "${YELLOW}Your configuration will be preserved.${NC}"
    echo ""
    printf "Are you sure you want to continue? (yes/no): "
    read confirm
    
    if [ "$confirm" != "yes" ]; then
        log INFO "Reinstallation cancelled by user"
        show_main_menu
        return 0
    fi
    
    # Backup configuration
    log INFO "Backing up configuration..."
    echo ""
    echo "Backing up configuration..."
    if [ -f /etc/config/passwall2 ]; then
        cp /etc/config/passwall2 /tmp/passwall2.backup
        log SUCCESS "Configuration backed up"
        echo "${GREEN}✓ Configuration backed up${NC}"
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
    log INFO "Uninstalling PassWall2..."
    echo ""
    echo "${BOLD}Removing PassWall2 packages...${NC}"
    
    # Get all passwall2 related packages
    packages=$(opkg list-installed | grep -E "passwall2|brook|chinadns|hysteria|v2ray|xray|trojan|shadowsocks" | awk '{print $1}')
    
    for package in $packages; do
        printf "  Removing $package... "
        if opkg remove "$package" >> "$LOG_FILE" 2>&1; then
            log SUCCESS "Removed: $package"
            echo "${GREEN}✓${NC}"
        else
            log WARNING "Failed to remove: $package"
            echo "${YELLOW}⚠${NC}"
        fi
    done
    
    log SUCCESS "PassWall2 uninstalled"
}

uninstall_passwall2() {
    print_header
    echo "${BOLD}${RED}Uninstalling PassWall2${NC}"
    print_separator
    
    log INFO "Uninstall process started"
    
    echo "${RED}Warning: This will completely remove PassWall2 from your system.${NC}"
    echo ""
    printf "Are you sure you want to continue? (yes/no): "
    read confirm
    
    if [ "$confirm" != "yes" ]; then
        log INFO "Uninstallation cancelled by user"
        show_main_menu
        return 0
    fi
    
    uninstall_passwall2_internal
    
    print_separator
    echo "${GREEN}✓ PassWall2 has been uninstalled${NC}"
    print_separator
    
    printf "Press Enter to return to menu..."
    read dummy
    
    PASSWALL2_INSTALLED=0
    show_main_menu
}

################################################################################
# Utility Functions
################################################################################

view_logs() {
    print_header
    echo "${BOLD}Installation Logs${NC}"
    print_separator
    
    echo "Log files location: ${CYAN}$LOG_DIR${NC}"
    echo ""
    echo "Available log files:"
    ls -lh "$LOG_DIR"/*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    
    print_separator
    echo ""
    echo "Recent log entries from current session:"
    print_separator
    tail -n 30 "$LOG_FILE"
    
    print_separator
    printf "Press Enter to return to menu..."
    read dummy
    show_main_menu
}

exit_script() {
    print_header
    echo "${BOLD}Thank you for using PassWall2 Smart Installer!${NC}"
    print_separator
    echo ""
    echo "Installation logs saved at: ${CYAN}$LOG_FILE${NC}"
    echo ""
    log INFO "Script terminated by user"
    exit 0
}

################################################################################
# Main Execution
################################################################################

main() {
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo "${RED}Error: This script must be run as root!${NC}"
        echo "Please run as root user"
        exit 1
    fi
    
    log INFO "Script started"
    log INFO "========================================"
    
    # Detect system information
    detect_system_info
    
    # Check PassWall2 status
    check_passwall2_status
    
    # Show main menu
    show_main_menu
}

# Start the script
main
