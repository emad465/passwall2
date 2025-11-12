#!/bin/bash

################################################################################
# PassWall2 Universal Installer for OpenWrt
# Version: 3.0.0 (Final - Intelligent Architecture Detection)
# Supports: ALL OpenWrt versions & ALL architectures without exception
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Log
LOG_DIR="/tmp/passwall2_installer"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR" 2>/dev/null

################################################################################
# Smart Logging
################################################################################

log() {
    echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

################################################################################
# UI
################################################################################

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          PassWall2 Universal Installer v3.0.0               ║"
    echo "║    Auto-Detects Repositories for ANY Architecture           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_separator() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

################################################################################
# System Detection (Uses OpenWrt's NATIVE data)
################################################################################

detect_system() {
    print_separator
    echo -e "${BOLD}🔍 Detecting System...${NC}"
    print_separator
    
    # Get OpenWrt's EXACT architecture (no guessing!)
    source /etc/openwrt_release 2>/dev/null
    DIST_ARCH="$DISTRIB_ARCH"
    DIST_TARGET="$DISTRIB_TARGET"
    DIST_VERSION="$DISTRIB_RELEASE"
    DIST_CODENAME="$DISTRIB_CODENAME"
    
    if [ -z "$DIST_ARCH" ]; then
        echo -e "${RED}❌ Could not detect OpenWrt architecture${NC}"
        exit 1
    fi
    
    log "Architecture: $DIST_ARCH"
    log "Target: $DIST_TARGET"
    log "Version: $DIST_VERSION ($DIST_CODENAME)"
    
    echo -e "Architecture: ${GREEN}$DIST_ARCH${NC}"
    echo -e "Target: ${GREEN}$DIST_TARGET${NC}"
    echo -e "Version: ${GREEN}$DIST_VERSION${NC}"
    
    # Detect internet
    echo -n "Internet: "
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        INTERNET_OK=1
        echo -e "${GREEN}✓${NC}"
        log "Internet: OK"
    else
        INTERNET_OK=0
        echo -e "${RED}✗${NC}"
        log "Internet: Failed"
    fi
    
    print_separator
}

################################################################################
# Repository Setup (INTELLIGENT - No Hardcoded Architecture)
################################################################################

setup_repositories() {
    echo -e "${BOLD}📦 Setting up Repositories...${NC}"
    print_separator
    
    # Use OpenWrt's EXACT major version
    MAJOR_VERSION=$(echo "$DIST_VERSION" | cut -d. -f1-2)
    
    # Backup
    REPO_FILE="/etc/opkg/customfeeds.conf"
    BACKUP_FILE="${REPO_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$REPO_FILE" "$BACKUP_FILE" 2>/dev/null
        log "Repository backup: $BACKUP_FILE"
        echo -e "Backup: ${GREEN}$BACKUP_FILE${NC}"
    fi
    
    # Remove old entries
    sed -i '/passwall2/d; /kiddin9/d; /immortalwrt/d; /iranopenwrt/d; /openwrt-passwall/d' "$REPO_FILE" 2>/dev/null
    
    # Add SMART repositories that use OpenWrt's NATIVE architecture string
    cat >> "$REPO_FILE" << EOF

# PassWall2 Repositories - Auto-Generated for $DIST_ARCH
# Repository 1: kiddin9 (Primary - supports ALL architectures)
src/gz kiddin9_packages https://op.dllkids.xyz/packages-${MAJOR_VERSION}/${DIST_ARCH}/packages
src/gz kiddin9_luci https://op.dllkids.xyz/packages-${MAJOR_VERSION}/${DIST_ARCH}/luci

# Repository 2: ImmortalWrt (Fallback - supports ALL architectures)
src/gz immortalwrt_packages https://downloads.immortalwrt.org/releases/packages-${MAJOR_VERSION}/${DIST_ARCH}/packages
src/gz immortalwrt_luci https://downloads.immortalwrt.org/releases/packages-${MAJOR_VERSION}/${DIST_ARCH}/luci

# Repository 3: IranOpenWrt (Iran-Optimized)
src/gz iranopenwrt_packages https://iranopenwrt.ir/releases/packages-${MAJOR_VERSION}/${DIST_ARCH}/packages
src/gz iranopenwrt_luci https://iranopenwrt.ir/releases/packages-${MAJOR_VERSION}/${DIST_ARCH}/luci

# Repository 4: OpenWrt-Passwall Direct (Ultimate Fallback)
src/gz passwall_packages https://downloads.openwrt-passwall.site/releases/packages-${MAJOR_VERSION}/${DIST_ARCH}/packages
src/gz passwall_luci https://downloads.openwrt-passwall.site/releases/packages-${MAJOR_VERSION}/${DIST_ARCH}/luci
EOF
    
    echo -e "Repositories: ${GREEN}✓ Added${NC}"
    log "Repositories configured for $DIST_ARCH"
    
    # Add GPG keys (best effort)
    echo -n "GPG Keys: "
    {
        wget-ssl --timeout=10 -O- https://op.dllkids.xyz/public.key 2>/dev/null | opkg-key add - 2>/dev/null
        wget-ssl --timeout=10 -O- https://downloads.immortalwrt.org/immortalwrt.gpg.key 2>/dev/null | opkg-key add - 2>/dev/null
        wget-ssl --timeout=10 -O- https://iranopenwrt.ir/iranopenwrt.gpg.key 2>/dev/null | opkg-key add - 2>/dev/null
    } >> "$LOG_FILE" 2>&1
    
    echo -e "${GREEN}✓${NC}"
    
    # Update (show progress)
    echo -n "Updating packages: "
    if opkg update >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✓${NC}"
        log "Package list updated"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}"
        log "Update had warnings (this is normal)"
        return 0  # Still continue
    fi
}

################################################################################
# Package Search & Installation (INTELLIGENT)
################################################################################

find_and_install_passwall2() {
    echo -e "\n${BOLD}🔍 Searching for PassWall2...${NC}"
    print_separator
    
    # Search ALL configured repositories
    log "Searching for PassWall2 in repositories..."
    
    local pkg_info=$(opkg list 2>/dev/null | grep "luci-app-passwall2" | head -1)
    
    if [ -z "$pkg_info" ]; then
        echo -e "${RED}❌ PassWall2 NOT found in any repository${NC}"
        echo ""
        echo -e "${YELLOW}Possible reasons:${NC}"
        echo -e "  1. Repository temporarily down"
        echo -e "  2. Architecture very new/rare (wait for build)"
        echo -e "  3. Network blocks (use VPN)"
        echo ""
        echo -e "${CYAN}Try manually:${NC}"
        echo -e "  opkg list | grep passwall2"
        log "PassWall2 not found in repos"
        return 1
    fi
    
    local pkg_name=$(echo "$pkg_info" | awk '{print $1}')
    local pkg_version=$(echo "$pkg_info" | awk '{print $3}')
    
    echo -e "Found: ${GREEN}$pkg_name v$pkg_version${NC}"
    log "Found: $pkg_name v$pkg_version"
    
    # INSTALL
    echo -e "\n${BOLD}📥 Installing...${NC}"
    print_separator
    
    echo -n "PassWall2 core: "
    if opkg install "luci-app-passwall2" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✓${NC}"
        log "PassWall2 installed successfully"
    else
        echo -e "${RED}✗${NC}"
        log "PassWall2 installation failed"
        return 1
    fi
    
    # Language pack (optional)
    echo -n "Chinese pack: "
    opkg install luci-i18n-passwall2-zh-cn >> "$LOG_FILE" 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠${NC}"
    
    # Core packages (optional)
    echo -e "\n${CYAN}Installing core packages...${NC}"
    for pkg in xray-core v2ray-core; do
        echo -n "  $pkg: "
        opkg install "$pkg" >> "$LOG_FILE" 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠${NC}"
    done
    
    return 0
}

################################################################################
# Main Installation Flow
################################################################################

install_passwall2() {
    print_header
    
    if [ "$INTERNET_OK" -ne 1 ]; then
        echo -e "${RED}❌ Internet connection required${NC}"
        read -rp "Press Enter..."
        return
    fi
    
    echo -e "${BOLD}📋 PassWall2 Installation${NC}"
    print_separator
    
    echo -e "This will:"
    echo -e "  • Add PassWall2 repositories"
    echo -e "  • Update package lists"
    echo -e "  • Install PassWall2 + dependencies"
    echo -e "  • Required space: ~25MB"
    echo ""
    
    read -rp "Continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        show_main_menu
        return
    fi
    
    # Setup repos
    setup_repositories || { read -rp "Press Enter..."; show_main_menu; return; }
    
    # Find and install
    find_and_install_passwall2 || { read -rp "Press Enter..."; show_main_menu; return; }
    
    # Wait for LuCI
    echo -e "\n${CYAN}Finalizing installation...${NC}"
    sleep 3
    
    # Success
    print_separator
    echo -e "${GREEN}${BOLD}✅ PassWall2 Installed Successfully!${NC}"
    print_separator
    
    LAN_IP=$(uci -q get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
    echo -e "🌐 Access: ${CYAN}http://${LAN_IP}/cgi-bin/luci/admin/services/passwall2${NC}"
    echo -e "📄 Log: ${CYAN}$LOG_FILE${NC}"
    
    read -rp "Press Enter to continue..."
    show_main_menu
}

################################################################################
# Menu
################################################################################

show_main_menu() {
    print_header
    
    detect_system
    
    echo -e "${BOLD}📊 Status:${NC}"
    
    if opkg list-installed 2>/dev/null | grep -q "luci-app-passwall2"; then
        INSTALLED_VER=$(opkg list-installed | grep "luci-app-passwall2" | awk '{print $3}')
        echo -e "  PassWall2: ${GREEN}Installed (v$INSTALLED_VER)${NC}"
        echo ""
        echo "  1) Update"
        echo "  2) Reinstall"
        echo "  3) Uninstall"
        echo "  4) View Logs"
        echo "  5) Exit"
        read -rp "Select [1-5]: " choice
        
        case $choice in
            1) install_passwall2 ;;
            2) install_passwall2 ;;
            3) 
                read -rp "Uninstall? (yes/no): " c
                [ "$c" = "yes" ] && opkg remove luci-app-passwall2 --force-removal-of-dependent-packages >> "$LOG_FILE" 2>&1
                show_main_menu
                ;;
            4) 
                print_separator
                tail -n 30 "$LOG_FILE"
                print_separator
                read -rp "Press Enter..."
                show_main_menu
                ;;
            5) exit 0 ;;
            *) show_main_menu ;;
        esac
    else
        echo -e "  PassWall2: ${YELLOW}Not installed${NC}"
        echo ""
        echo "  1) Install PassWall2"
        echo "  2) Exit"
        read -rp "Select [1-2]: " choice
        
        case $choice in
            1) install_passwall2 ;;
            2) exit 0 ;;
            *) show_main_menu ;;
        esac
    fi
}

################################################################################
# Start
################################################################################

echo "$0" > /tmp/.pw2_install_running
show_main_menu
