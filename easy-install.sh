#!/bin/bash
#
# Enhanced Easy Installer for Varnish Cache on cPanel/WHM
# AlmaLinux 8+ Compatible
#
# This script provides an interactive installation menu with enhanced UX
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
NC='\033[0m' # No Color

# Animation and progress functions
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    local msg="$1"
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r${CYAN}[${spinstr:0:1}] ${msg}${NC}"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r${GREEN}[✓] ${msg} - Complete${NC}\n"
}

show_progress_bar() {
    local current=$1
    local total=$2
    local description="$3"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}Progress: ${WHITE}["
    printf "${GREEN}%*s" $completed | tr ' ' '█'
    printf "${WHITE}%*s" $remaining | tr ' ' '░'
    printf "${WHITE}] ${YELLOW}%3d%% ${CYAN}- ${description}${NC}" $percentage
    
    if [ $current -eq $total ]; then
        echo
        echo
    fi
}

# Enhanced logging
log_file="/tmp/varnish-install-$(date +%Y%m%d-%H%M%S).log"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

print_header() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                          ║"
    echo "║        🚀 VARNISH CACHE FOR cPANEL/WHM - ENHANCED EASY INSTALLER 🚀                     ║"
    echo "║                                                                                          ║"
    echo "║                          📦 AlmaLinux 8+ Compatible                                      ║"
    echo "║                          🎮 Beautiful WHM Plugin Included                               ║"
    echo "║                          ⚡ High Performance Caching                                     ║"
    echo "║                          🔒 SSL/TLS Termination                                          ║"
    echo "║                                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

print_system_info() {
    echo -e "${BLUE}${BOLD}📊 System Information:${NC}"
    echo -e "${WHITE}├─ OS:${NC} $(cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
    echo -e "${WHITE}├─ Kernel:${NC} $(uname -r)"
    echo -e "${WHITE}├─ Memory:${NC} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${WHITE}├─ CPU:${NC} $(nproc) cores"
    echo -e "${WHITE}├─ cPanel:${NC} $(if [ -f /usr/local/cpanel/version ]; then cat /usr/local/cpanel/version; else echo 'Not installed'; fi)"
    echo -e "${WHITE}└─ WHM:${NC} $(if [ -f /usr/local/cpanel/whm/docroot/cgi/whm.cgi ]; then echo 'Available'; else echo 'Not available'; fi)"
    echo
}

check_dependencies() {
    local missing_deps=()
    local deps=("curl" "wget" "git" "make")
    
    echo -e "${BLUE}🔍 Checking dependencies...${NC}"
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        else
            echo -e "${GREEN}  ✓ $dep${NC}"
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}📦 Installing missing dependencies: ${missing_deps[*]}${NC}"
        {
            if command -v dnf &> /dev/null; then
                dnf install -y "${missing_deps[@]}"
            else
                yum install -y "${missing_deps[@]}"
            fi
        } &
        spinner "Installing dependencies"
        log "Installed dependencies: ${missing_deps[*]}"
    fi
    echo
}

show_menu() {
    echo -e "${CYAN}${BOLD}🎛️  INSTALLATION OPTIONS:${NC}"
    echo
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│  ${GREEN}1${WHITE}) 🚀 ${BOLD}Full Installation${NC}${WHITE}                                                       │${NC}"
    echo -e "${WHITE}│     └─ Install Varnish, Hitch, configure Apache, install WHM plugin               │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}2${WHITE}) 🔧 ${BOLD}Configure Existing Varnish for cPanel${NC}${WHITE}                                 │${NC}"
    echo -e "${WHITE}│     └─ Configure existing Varnish installation for cPanel/WHM                     │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}3${WHITE}) 🎮 ${BOLD}Install WHM Plugin Only${NC}${WHITE}                                                │${NC}"
    echo -e "${WHITE}│     └─ Install beautiful management interface for existing Varnish                │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}4${WHITE}) 📊 ${BOLD}Validate Current Installation${NC}${WHITE}                                         │${NC}"
    echo -e "${WHITE}│     └─ Check if Varnish is properly configured and working                        │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}5${WHITE}) 🔄 ${BOLD}Update/Reinstall Components${NC}${WHITE}                                           │${NC}"
    echo -e "${WHITE}│     └─ Update existing installation with latest changes                           │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}6${WHITE}) �️  ${BOLD}Uninstall Varnish${NC}${WHITE}                                                    │${NC}"
    echo -e "${WHITE}│     └─ Completely remove Varnish and restore original configuration              │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}7${WHITE}) 📋 ${BOLD}Installation Status & Logs${NC}${WHITE}                                            │${NC}"
    echo -e "${WHITE}│     └─ View current status and recent logs                                        │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}8${WHITE}) ❌ ${BOLD}Exit${NC}${WHITE}                                                                   │${NC}"
    echo -e "${WHITE}│     └─ Exit without making changes                                                │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

run_with_progress() {
    local command="$1"
    local description="$2"
    local steps="$3"
    
    echo -e "${BLUE}📋 ${description}${NC}"
    echo
    
    {
        eval "$command"
    } &
    local cmd_pid=$!
    
    # Simulate progress for user feedback
    for ((i=1; i<=steps; i++)); do
        show_progress_bar $i $steps "$description"
        sleep 1
    done
    
    wait $cmd_pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ ${description} completed successfully!${NC}"
        log "${description} completed successfully"
    else
        echo -e "${RED}❌ ${description} failed!${NC}"
        log "${description} failed with exit code $exit_code"
    fi
    
    echo
    return $exit_code
}

# Enhanced installation functions
install_full() {
    echo -e "${PURPLE}🚀 Starting Full Installation...${NC}"
    echo
    
    if run_with_progress "make install" "Installing Varnish Cache and components" 8; then
        echo -e "${GREEN}${BOLD}🎉 Full installation completed successfully!${NC}"
        echo
        echo -e "${BLUE}📋 What was installed:${NC}"
        echo -e "${WHITE}  ✓ Varnish Cache (port 80)${NC}"
        echo -e "${WHITE}  ✓ Apache reconfigured (port 8080)${NC}"
        echo -e "${WHITE}  ✓ Hitch SSL termination${NC}"
        echo -e "${WHITE}  ✓ WHM management plugin${NC}"
        echo -e "${WHITE}  ✓ Automatic certificate updates${NC}"
        echo
        show_access_info
    else
        echo -e "${RED}❌ Installation failed. Check logs: $log_file${NC}"
        return 1
    fi
}

install_cpanel_config() {
    echo -e "${CYAN}🔧 Configuring Existing Varnish for cPanel...${NC}"
    echo
    
    if run_with_progress "make install-cpanel" "Configuring Varnish for cPanel" 5; then
        echo -e "${GREEN}✅ cPanel configuration completed!${NC}"
        show_access_info
    else
        echo -e "${RED}❌ Configuration failed. Check logs: $log_file${NC}"
        return 1
    fi
}

install_whm_plugin() {
    echo -e "${PURPLE}🎮 Installing WHM Plugin...${NC}"
    echo
    
    if run_with_progress "make install-plugin" "Installing WHM management plugin" 3; then
        echo -e "${GREEN}✅ WHM plugin installed successfully!${NC}"
        show_access_info
    else
        echo -e "${RED}❌ Plugin installation failed. Check logs: $log_file${NC}"
        return 1
    fi
}

validate_installation() {
    echo -e "${BLUE}📊 Validating Installation...${NC}"
    echo
    
    if run_with_progress "make validate" "Running validation checks" 4; then
        echo -e "${GREEN}✅ Validation completed!${NC}"
    else
        echo -e "${RED}❌ Validation found issues. Check logs: $log_file${NC}"
        return 1
    fi
}

update_installation() {
    echo -e "${YELLOW}� Updating Installation...${NC}"
    echo
    
    if run_with_progress "git pull && make install" "Updating components" 6; then
        echo -e "${GREEN}✅ Update completed!${NC}"
    else
        echo -e "${RED}❌ Update failed. Check logs: $log_file${NC}"
        return 1
    fi
}

uninstall_varnish() {
    echo -e "${RED}🗑️  Uninstalling Varnish...${NC}"
    echo
    echo -e "${YELLOW}⚠️  This will completely remove Varnish and restore original configuration.${NC}"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        if run_with_progress "make uninstall" "Removing Varnish components" 5; then
            echo -e "${GREEN}✅ Uninstallation completed!${NC}"
        else
            echo -e "${RED}❌ Uninstallation failed. Check logs: $log_file${NC}"
            return 1
        fi
    else
        echo -e "${BLUE}🔄 Uninstallation cancelled.${NC}"
    fi
}

show_status_and_logs() {
    echo -e "${BLUE}📋 Installation Status & Recent Logs${NC}"
    echo
    
    echo -e "${CYAN}🔍 Service Status:${NC}"
    services=("varnish" "httpd" "hitch")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $service: Running${NC}"
        else
            echo -e "${RED}  ✗ $service: Not running${NC}"
        fi
    done
    
    echo
    echo -e "${CYAN}� Recent Installation Logs:${NC}"
    if [ -f "$log_file" ]; then
        tail -10 "$log_file"
    else
        echo "No recent installation logs found."
    fi
    
    echo
    echo -e "${CYAN}🔧 Varnish Status:${NC}"
    if command -v varnishstat &> /dev/null; then
        varnishstat -1 -f MAIN.uptime,MAIN.cache_hit,MAIN.cache_miss 2>/dev/null || echo "Varnish not responding"
    else
        echo "Varnish tools not installed"
    fi
}

show_access_info() {
    echo -e "${GREEN}${BOLD}🎮 Access Information:${NC}"
    echo -e "${WHITE}├─ WHM Plugin:${NC} System → Varnish Cache Manager"
    echo -e "${WHITE}├─ Direct URL:${NC} https://$(hostname -I | awk '{print $1}'):2087/cgi/varnish/whm_varnish_manager.cgi"
    echo -e "${WHITE}├─ Varnish Stats:${NC} varnishstat"
    echo -e "${WHITE}└─ Logs:${NC} journalctl -u varnish -f"
    echo
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_color $RED "❌ This script must be run as root or with sudo"
        print_color $YELLOW "💡 Try: sudo $0"
        exit 1
    fi
}

# Function to check OS compatibility
check_os() {
    if ! command -v dnf >/dev/null 2>&1 && ! command -v yum >/dev/null 2>&1; then
        print_color $RED "❌ This installer is designed for RHEL-based systems (AlmaLinux, CentOS, RHEL)"
        exit 1
    fi
}

# Function to install prerequisites
install_prerequisites() {
    print_color $BLUE "📦 Installing prerequisites..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget make || true
    else
        yum install -y curl wget make || true
    fi
}

# Function for complete installation
complete_installation() {
    print_color $GREEN "🚀 Starting Complete Installation..."
    echo ""
    print_color $YELLOW "This will:"
    echo "   • Install Varnish Cache and Hitch"
    echo "   • Configure Apache to use port 8080"
    echo "   • Configure Varnish to use port 80"
    echo "   • Setup SSL termination with Hitch"
    echo "   • Configure automatic certificate updates"
    echo "   • Install beautiful WHM management plugin"
    echo ""
    
    read -p "Do you want to continue? [Y/n]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        print_color $YELLOW "Installation cancelled"
        return
    fi
    
    make install
    print_color $GREEN "✅ Complete installation finished!"
    
    echo ""
    print_color $CYAN "🎉 Next steps:"
    echo "   1. Update WHM Tweak Settings (Apache ports)"
    echo "   2. Access WHM > System > Varnish Cache Manager"
    echo "   3. Test your websites"
    echo "   4. Consider installing the cPanel Varnish plugin"
}

# Function for cPanel configuration only
cpanel_configuration() {
    print_color $GREEN "⚙️ Configuring Existing Varnish for cPanel..."
    echo ""
    print_color $YELLOW "This will:"
    echo "   • Configure Apache to listen on port 8080"
    echo "   • Configure Varnish to listen on port 80"
    echo "   • Update backend configuration with server IP"
    echo "   • Restart services"
    echo ""
    
    read -p "Do you want to continue? [Y/n]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        print_color $YELLOW "Configuration cancelled"
        return
    fi
    
    make install-cpanel
    print_color $GREEN "✅ cPanel configuration completed!"
}

# Function to install WHM plugin only
install_whm_plugin() {
    print_color $BLUE "🔌 Installing WHM Varnish Cache Manager Plugin..."
    echo ""
    print_color $YELLOW "This will:"
    echo "   • Install beautiful WHM management interface"
    echo "   • Add real-time monitoring dashboard"
    echo "   • Enable domain-specific cache management"
    echo "   • Provide performance analytics with charts"
    echo "   • Add security status monitoring"
    echo ""
    
    read -p "Do you want to continue? [Y/n]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        print_color $YELLOW "Plugin installation cancelled"
        return
    fi
    
    make install-plugin
    print_color $GREEN "✅ WHM plugin installation completed!"
    
    echo ""
    print_color $CYAN "🎉 Plugin installed successfully!"
    echo "   Access: WHM > System > Varnish Cache Manager"
    echo "   URL: https://$(hostname):2087/cgi/varnish/whm_varnish_manager.cgi"
}

# Function to validate configuration
validate_configuration() {
    print_color $BLUE "🔍 Validating Varnish Configuration..."
    echo ""
    
    if make validate; then
        print_color $GREEN "✅ Validation completed!"
    else
        print_color $RED "❌ Validation found issues. Check the output above."
    fi
}

# Function to setup cron
setup_cron() {
    print_color $BLUE "⏰ Setting up SSL Certificate Auto-Update..."
    
    make setup-cron
    print_color $GREEN "✅ Cron job configured!"
}

# Function to uninstall
uninstall_varnish() {
    print_color $RED "🗑️ Uninstalling Varnish and Hitch..."
    echo ""
    print_color $YELLOW "⚠️  WARNING: This will completely remove Varnish and Hitch!"
    echo ""
    
    make uninstall
}

# Function to show help
show_help() {
    make help
    echo ""
    read -p "Press Enter to continue..."
}

# Function to wait for user input
wait_for_input() {
    echo ""
    read -p "Press Enter to continue..."
}

# Main function
main() {
    print_banner
    
    # Check if running as root
    check_root
    
    # Check OS compatibility
    check_os
    
    # Install prerequisites
    install_prerequisites
    
    while true; do
        print_banner
        show_menu
        
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1)
                complete_installation
                wait_for_input
                ;;
            2)
                cpanel_configuration
                wait_for_input
                ;;
            3)
                install_whm_plugin
                wait_for_input
                ;;
            4)
                validate_configuration
                wait_for_input
                ;;
            5)
                setup_cron
                wait_for_input
                ;;
            6)
                uninstall_varnish
                wait_for_input
                ;;
            7)
                show_help
                ;;
            8)
                print_color $CYAN "👋 Thank you for using Varnish Installer!"
                exit 0
                ;;
            *)
                print_color $RED "❌ Invalid option. Please select 1-8."
                sleep 2
                ;;
        esac
    done
}

# Run main function
main "$@"