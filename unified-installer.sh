#!/bin/bash
#
# 🚀 UNIFIED VARNISH INSTALLER - OPTIMIZED FOR MAXIMUM PERFORMANCE
# 
# All-in-One installer that provides LiteSpeed-level performance and beyond
# Consolidates all installation, configuration, and optimization features
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main/unified-installer.sh | sudo bash
#

set -euo pipefail

# Enhanced color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Global configuration
SCRIPT_VERSION="2.0.0"
REPO_URL="https://github.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x"
REPO_NAME="varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x"
INSTALL_DIR="/opt/varnish-cpanel-installer"
TMP_DIR="/tmp/varnish-unified-installer-$$"
LOG_FILE="/var/log/varnish-unified-installer.log"

# Performance tracking
START_TIME=$(date +%s)

print_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                                    ║"
    echo "║                     🚀 UNIFIED VARNISH INSTALLER v${SCRIPT_VERSION} 🚀                                      ║"
    echo "║                                                                                                    ║"
    echo "║                           🏆 LITESPEED-LEVEL PERFORMANCE & BEYOND 🏆                              ║"
    echo "║                                                                                                    ║"
    echo "║  ✨ Features:                                                                                      ║"
    echo "║     • Advanced VCL with intelligent caching & compression                                         ║"
    echo "║     • Beautiful WHM management interface with real-time analytics                                 ║"
    echo "║     • LiteSpeed-level or better performance optimizations                                         ║"
    echo "║     • Enhanced security with rate limiting & DDoS protection                                      ║"
    echo "║     • Auto-scaling configuration based on server resources                                        ║"
    echo "║     • Real-time performance monitoring & cache warming                                            ║"
    echo "║                                                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
    echo -e "${message}"
}

show_progress() {
    local current=$1
    local total=$2
    local description="$3"
    local percentage=$((current * 100 / total))
    local completed=$((current * 60 / total))
    local remaining=$((60 - completed))
    
    printf "\r${CYAN}Progress: ${WHITE}["
    printf "${GREEN}%*s" $completed | tr ' ' '█'
    printf "${WHITE}%*s" $remaining | tr ' ' '░'
    printf "${WHITE}] ${YELLOW}%3d%% ${CYAN}- ${description}${NC}" $percentage
    
    if [ $current -eq $total ]; then
        echo
        echo
    fi
}

detect_system() {
    log "INFO" "${BLUE}🔍 Detecting system configuration...${NC}"
    
    # Detect OS
    if [ -f /etc/redhat-release ]; then
        OS_VERSION=$(cat /etc/redhat-release)
        log "INFO" "${GREEN}✓ OS: $OS_VERSION${NC}"
    else
        log "ERROR" "${RED}❌ Unsupported OS. This installer requires RHEL-based distributions.${NC}"
        exit 1
    fi
    
    # Detect system resources
    CPU_CORES=$(nproc)
    TOTAL_RAM_GB=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024))
    
    log "INFO" "${GREEN}✓ CPU Cores: $CPU_CORES${NC}"
    log "INFO" "${GREEN}✓ Total RAM: ${TOTAL_RAM_GB}GB${NC}"
    
    # Detect cPanel/WHM
    if [ -f /usr/local/cpanel/cpanel ]; then
        CPANEL_VERSION=$(cat /usr/local/cpanel/version 2>/dev/null || echo "Unknown")
        HAS_CPANEL=true
        log "INFO" "${GREEN}✓ cPanel/WHM detected: $CPANEL_VERSION${NC}"
    else
        HAS_CPANEL=false
        log "WARN" "${YELLOW}⚠️ cPanel/WHM not detected${NC}"
    fi
    
    # Calculate optimal settings
    if [ $TOTAL_RAM_GB -lt 2 ]; then
        VARNISH_MEMORY="512M"
        PERFORMANCE_PROFILE="minimal"
    elif [ $TOTAL_RAM_GB -lt 4 ]; then
        VARNISH_MEMORY="1G"
        PERFORMANCE_PROFILE="standard"
    elif [ $TOTAL_RAM_GB -lt 8 ]; then
        VARNISH_MEMORY="3G"
        PERFORMANCE_PROFILE="high"
    else
        VARNISH_MEMORY="$((TOTAL_RAM_GB * 60 / 100))G"
        PERFORMANCE_PROFILE="maximum"
    fi
    
    log "INFO" "${CYAN}📊 Auto-configured for $PERFORMANCE_PROFILE performance profile${NC}"
    echo
}

show_installation_menu() {
    echo -e "${CYAN}${BOLD}🎛️ INSTALLATION OPTIONS:${NC}"
    echo
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│  ${GREEN}1${WHITE}) 🚀 ${BOLD}FULL INSTALLATION${NC}${WHITE} (Recommended)                                              │${NC}"
    echo -e "${WHITE}│     └─ Complete setup: Varnish + Hitch + Apache config + WHM plugin + Optimizations         │${NC}"
    echo -e "${WHITE}│                                                                                                 │${NC}"
    echo -e "${WHITE}│  ${GREEN}2${WHITE}) ⚡ ${BOLD}PERFORMANCE-ONLY INSTALLATION${NC}${WHITE}                                                │${NC}"
    echo -e "${WHITE}│     └─ Install with maximum performance optimizations (LiteSpeed-level)                    │${NC}"
    echo -e "${WHITE}│                                                                                                 │${NC}"
    echo -e "${WHITE}│  ${GREEN}3${WHITE}) 🎮 ${BOLD}CPANEL CONFIGURATION ONLY${NC}${WHITE}                                                    │${NC}"
    echo -e "${WHITE}│     └─ Configure existing Varnish for cPanel/WHM integration                               │${NC}"
    echo -e "${WHITE}│                                                                                                 │${NC}"
    echo -e "${WHITE}│  ${GREEN}4${WHITE}) 🎨 ${BOLD}WHM PLUGIN ONLY${NC}${WHITE}                                                              │${NC}"
    echo -e "${WHITE}│     └─ Install beautiful management interface for existing Varnish                         │${NC}"
    echo -e "${WHITE}│                                                                                                 │${NC}"
    echo -e "${WHITE}│  ${GREEN}5${WHITE}) 🔧 ${BOLD}OPTIMIZATION ONLY${NC}${WHITE}                                                            │${NC}"
    echo -e "${WHITE}│     └─ Apply performance optimizations to existing Varnish installation                   │${NC}"
    echo -e "${WHITE}│                                                                                                 │${NC}"
    echo -e "${WHITE}│  ${GREEN}6${WHITE}) 📊 ${BOLD}STATUS CHECK${NC}${WHITE}                                                                 │${NC}"
    echo -e "${WHITE}│     └─ Check current installation status and get recommendations                           │${NC}"
    echo -e "${WHITE}│                                                                                                 │${NC}"
    echo -e "${WHITE}│  ${GREEN}7${WHITE}) 🗑️ ${BOLD}UNINSTALL${NC}${WHITE}                                                                   │${NC}"
    echo -e "${WHITE}│     └─ Complete removal with system restoration                                            │${NC}"
    echo -e "${WHITE}│                                                                                                 │${NC}"
    echo -e "${WHITE}│  ${GREEN}8${WHITE}) ❌ ${BOLD}EXIT${NC}${WHITE}                                                                          │${NC}"
    echo -e "${WHITE}│     └─ Exit without making changes                                                         │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

install_dependencies() {
    log "INFO" "${BLUE}📦 Installing required dependencies...${NC}"
    
    show_progress 1 8 "Updating package repositories"
    
    # Update package database
    if command -v dnf &> /dev/null; then
        dnf update -y &>/dev/null
        dnf install -y curl wget git make bc epel-release &>/dev/null
    else
        yum update -y &>/dev/null
        yum install -y curl wget git make bc epel-release &>/dev/null
    fi
    
    show_progress 2 8 "Installing build tools"
    
    # Install development tools
    if command -v dnf &> /dev/null; then
        dnf groupinstall -y "Development Tools" &>/dev/null || true
        dnf install -y gcc gcc-c++ autoconf automake libtool pkgconfig &>/dev/null || true
    else
        yum groupinstall -y "Development Tools" &>/dev/null || true
        yum install -y gcc gcc-c++ autoconf automake libtool pkgconfig &>/dev/null || true
    fi
    
    log "INFO" "${GREEN}✅ Dependencies installed${NC}"
}

download_and_setup() {
    log "INFO" "${BLUE}📥 Downloading latest installer components...${NC}"
    
    show_progress 3 8 "Creating installation directory"
    
    # Clean up and create directories
    rm -rf "$TMP_DIR" "$INSTALL_DIR"
    mkdir -p "$TMP_DIR" "$INSTALL_DIR"
    cd "$TMP_DIR"
    
    show_progress 4 8 "Cloning repository"
    
    # Clone repository
    if ! git clone "$REPO_URL" "$REPO_NAME" &>/dev/null; then
        log "ERROR" "${RED}❌ Failed to clone repository${NC}"
        exit 1
    fi
    
    cd "$REPO_NAME"
    
    show_progress 5 8 "Installing files"
    
    # Copy files to permanent location
    cp -r * "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR"/*.sh
    
    cd "$INSTALL_DIR"
    
    log "INFO" "${GREEN}✅ Files installed to $INSTALL_DIR${NC}"
}

install_varnish_and_hitch() {
    log "INFO" "${BLUE}🚀 Installing Varnish Cache and Hitch...${NC}"
    
    show_progress 6 8 "Installing Varnish repository"
    
    # Add Varnish repository
    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish70/script.rpm.sh | bash &>/dev/null
    
    # Install Varnish and Hitch
    if command -v dnf &> /dev/null; then
        dnf install -y varnish hitch &>/dev/null
    else
        yum install -y varnish hitch &>/dev/null
    fi
    
    log "INFO" "${GREEN}✅ Varnish and Hitch installed${NC}"
}

configure_system() {
    log "INFO" "${BLUE}⚙️ Configuring system for optimal performance...${NC}"
    
    show_progress 7 8 "Applying system optimizations"
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}' || curl -s ifconfig.me || echo "127.0.0.1")
    
    # Configure Apache
    if [ -f /etc/httpd/conf/httpd.conf ]; then
        cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.backup.$(date +%Y%m%d)
        sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
        
        if ! grep -q "Listen 8080" /etc/httpd/conf/httpd.conf; then
            echo "Listen 8080" >> /etc/httpd/conf/httpd.conf
        fi
    fi
    
    # Install optimized VCL
    cp optimized-default.vcl /etc/varnish/default.vcl
    sed -i "s/Replace it with Your System IP's Address/$SERVER_IP/g" /etc/varnish/default.vcl
    
    # Configure Varnish systemd service
    mkdir -p /etc/systemd/system/varnish.service.d
    cat > /etc/systemd/system/varnish.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/varnishd \\
    -a :80 \\
    -a :8443,PROXY \\
    -T localhost:6082 \\
    -f /etc/varnish/default.vcl \\
    -S /etc/varnish/secret \\
    -s malloc,$VARNISH_MEMORY \\
    -p feature=+http2 \\
    -p workspace_backend=128k \\
    -p workspace_client=128k \\
    -p thread_pools=$((CPU_CORES / 2 < 2 ? 2 : CPU_CORES / 2)) \\
    -p thread_pool_min=$((CPU_CORES * 5)) \\
    -p thread_pool_max=$((CPU_CORES * 100)) \\
    -p default_ttl=3600 \\
    -p default_grace=86400
LimitNOFILE=131072
LimitNPROC=65536
LimitMEMLOCK=infinity
EOF

    systemctl daemon-reload
    
    log "INFO" "${GREEN}✅ System configured${NC}"
}

install_whm_plugin() {
    if [ "$HAS_CPANEL" = true ]; then
        log "INFO" "${BLUE}🎮 Installing WHM management plugin...${NC}"
        
        # Create WHM plugin directory
        mkdir -p /usr/local/cpanel/whm/docroot/cgi/varnish
        
        # Install plugin files
        cp whm_varnish_manager.cgi /usr/local/cpanel/whm/docroot/cgi/varnish/
        cp varnish_ajax.cgi /usr/local/cpanel/whm/docroot/cgi/varnish/
        chmod +x /usr/local/cpanel/whm/docroot/cgi/varnish/*.cgi
        
        # Register plugin with WHM
        if [ ! -f /usr/local/cpanel/whm/addonfeatures/varnish ]; then
            cat > /usr/local/cpanel/whm/addonfeatures/varnish << 'EOF'
---
group: System
name: Varnish Cache Manager
url: /cgi/varnish/whm_varnish_manager.cgi
icon: /whm/addon_plugins/park_wrapper_24.gif
description: Manage Varnish Cache with real-time performance monitoring
EOF
        fi
        
        log "INFO" "${GREEN}✅ WHM plugin installed${NC}"
    fi
}

start_services() {
    log "INFO" "${BLUE}🔄 Starting optimized services...${NC}"
    
    show_progress 8 8 "Starting services"
    
    # Start services in correct order
    systemctl enable httpd varnish hitch &>/dev/null
    systemctl restart httpd &>/dev/null
    sleep 2
    systemctl restart varnish &>/dev/null
    sleep 2
    systemctl restart hitch &>/dev/null || true
    
    # Verify services
    if systemctl is-active --quiet httpd && systemctl is-active --quiet varnish; then
        log "INFO" "${GREEN}✅ All services started successfully${NC}"
    else
        log "ERROR" "${RED}❌ Service startup failed${NC}"
        return 1
    fi
}

run_performance_optimization() {
    log "INFO" "${BLUE}⚡ Applying performance optimizations...${NC}"
    
    if [ -f "optimize-performance.sh" ]; then
        chmod +x optimize-performance.sh
        ./optimize-performance.sh &>/dev/null
        log "INFO" "${GREEN}✅ Performance optimizations applied${NC}"
    fi
}

validate_installation() {
    log "INFO" "${BLUE}✅ Validating installation...${NC}"
    
    local issues=0
    
    # Test HTTP response
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
        log "INFO" "${GREEN}✓ HTTP test passed${NC}"
    else
        log "ERROR" "${RED}✗ HTTP test failed${NC}"
        ((issues++))
    fi
    
    # Test Varnish headers
    if curl -s -I http://localhost | grep -qi "x-cache\|x-served-by\|x-varnish"; then
        log "INFO" "${GREEN}✓ Varnish headers detected${NC}"
    else
        log "WARN" "${YELLOW}⚠ Varnish headers not detected${NC}"
    fi
    
    # Test response time
    RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" http://localhost 2>/dev/null || echo "999")
    if (( $(echo "$RESPONSE_TIME < 0.5" | bc -l 2>/dev/null || echo 0) )); then
        log "INFO" "${GREEN}✓ Excellent response time: ${RESPONSE_TIME}s${NC}"
    else
        log "INFO" "${CYAN}ℹ Response time: ${RESPONSE_TIME}s${NC}"
    fi
    
    return $issues
}

show_completion_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo
    log "INFO" "${GREEN}${BOLD}🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo
    log "INFO" "${WHITE}╔═══════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    log "INFO" "${WHITE}║                              🚀 VARNISH CACHE READY 🚀                                       ║${NC}"
    log "INFO" "${WHITE}║                                                                                               ║${NC}"
    log "INFO" "${WHITE}║  ✨ Installation completed in ${duration} seconds                                                    ║${NC}"
    log "INFO" "${WHITE}║  🏆 Performance Profile: $PERFORMANCE_PROFILE                                                          ║${NC}"
    log "INFO" "${WHITE}║  💾 Cache Memory: $VARNISH_MEMORY                                                                   ║${NC}"
    log "INFO" "${WHITE}║  🖥️  CPU Cores: $CPU_CORES                                                                        ║${NC}"
    log "INFO" "${WHITE}║                                                                                               ║${NC}"
    if [ "$HAS_CPANEL" = true ]; then
    log "INFO" "${WHITE}║  🎮 WHM Plugin: https://$(hostname -I | awk '{print $1}'):2087/cgi/varnish/whm_varnish_manager.cgi  ║${NC}"
    log "INFO" "${WHITE}║  📍 WHM Menu: System → Varnish Cache Manager                                                 ║${NC}"
    fi
    log "INFO" "${WHITE}║                                                                                               ║${NC}"
    log "INFO" "${WHITE}║  📊 Commands:                                                                                 ║${NC}"
    log "INFO" "${WHITE}║     • Status: systemctl status varnish                                                       ║${NC}"
    log "INFO" "${WHITE}║     • Stats: varnishstat                                                                      ║${NC}"
    log "INFO" "${WHITE}║     • Logs: journalctl -u varnish -f                                                         ║${NC}"
    log "INFO" "${WHITE}║     • Validate: $INSTALL_DIR/check-status.sh                        ║${NC}"
    log "INFO" "${WHITE}║                                                                                               ║${NC}"
    log "INFO" "${WHITE}╚═══════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    log "INFO" "${CYAN}🚀 Your website should now load at LiteSpeed-level performance or better!${NC}"
    echo
}

cleanup() {
    rm -rf "$TMP_DIR" 2>/dev/null || true
}

# Main installation function
full_installation() {
    log "INFO" "${PURPLE}🚀 Starting full installation...${NC}"
    echo
    
    detect_system
    install_dependencies
    download_and_setup
    install_varnish_and_hitch
    configure_system
    install_whm_plugin
    start_services
    run_performance_optimization
    
    if validate_installation; then
        show_completion_summary
    else
        log "WARN" "${YELLOW}⚠️ Installation completed with some warnings. Check the logs for details.${NC}"
    fi
}

performance_installation() {
    log "INFO" "${PURPLE}⚡ Starting performance-optimized installation...${NC}"
    echo
    
    detect_system
    install_dependencies
    download_and_setup
    install_varnish_and_hitch
    configure_system
    install_whm_plugin
    run_performance_optimization
    start_services
    
    if validate_installation; then
        show_completion_summary
    fi
}

cpanel_configuration() {
    log "INFO" "${PURPLE}🔧 Configuring existing Varnish for cPanel...${NC}"
    echo
    
    detect_system
    download_and_setup
    configure_system
    install_whm_plugin
    systemctl restart httpd varnish
    validate_installation
}

whm_plugin_only() {
    if [ "$HAS_CPANEL" = true ]; then
        log "INFO" "${PURPLE}🎮 Installing WHM plugin only...${NC}"
        echo
        
        download_and_setup
        install_whm_plugin
        log "INFO" "${GREEN}✅ WHM plugin installed successfully!${NC}"
    else
        log "ERROR" "${RED}❌ cPanel/WHM not detected. Cannot install plugin.${NC}"
    fi
}

optimization_only() {
    log "INFO" "${PURPLE}🔧 Applying performance optimizations...${NC}"
    echo
    
    download_and_setup
    run_performance_optimization
    systemctl restart varnish
    validate_installation
}

status_check() {
    log "INFO" "${PURPLE}📊 Running status check...${NC}"
    echo
    
    download_and_setup
    chmod +x check-status.sh
    ./check-status.sh
}

uninstall_varnish() {
    log "INFO" "${PURPLE}🗑️ Starting uninstallation...${NC}"
    echo
    
    download_and_setup
    chmod +x easy-uninstall.sh
    ./easy-uninstall.sh
}

main() {
    # Trap for cleanup
    trap cleanup EXIT
    
    print_banner
    
    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "${RED}❌ This script must be run as root. Please use sudo.${NC}"
        exit 1
    fi
    
    # Auto-installation mode (no interaction)
    if [ "${1:-}" = "--auto" ] || [ "${1:-}" = "--full" ]; then
        full_installation
        exit 0
    fi
    
    # Interactive mode
    while true; do
        show_installation_menu
        read -p "Enter your choice (1-8): " choice
        echo
        
        case $choice in
            1)
                full_installation
                break
                ;;
            2)
                performance_installation
                break
                ;;
            3)
                cpanel_configuration
                break
                ;;
            4)
                whm_plugin_only
                break
                ;;
            5)
                optimization_only
                break
                ;;
            6)
                status_check
                break
                ;;
            7)
                uninstall_varnish
                break
                ;;
            8)
                log "INFO" "${BLUE}👋 Exiting without changes.${NC}"
                exit 0
                ;;
            *)
                log "ERROR" "${RED}❌ Invalid choice. Please select 1-8.${NC}"
                echo
                ;;
        esac
    done
}

# Run main function
main "$@"