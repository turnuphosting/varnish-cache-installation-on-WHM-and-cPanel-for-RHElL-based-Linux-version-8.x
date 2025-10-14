#!/bin/bash
#
# Easy Uninstaller for Varnish Cache on cPanel/WHM
# AlmaLinux 8+ Compatible
#
# This script provides comprehensive removal options with safety checks
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

# Logging
log_file="/tmp/varnish-uninstall-$(date +%Y%m%d-%H%M%S).log"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
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

print_header() {
    clear
    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                          ║"
    echo "║           🗑️  VARNISH CACHE UNINSTALLER - SAFE REMOVAL TOOL 🗑️                          ║"
    echo "║                                                                                          ║"
    echo "║                          ⚠️  WARNING: DESTRUCTIVE OPERATION ⚠️                           ║"
    echo "║                                                                                          ║"
    echo "║               This tool will remove Varnish and restore original settings               ║"
    echo "║                                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

check_installation_status() {
    echo -e "${BLUE}🔍 Checking current installation status...${NC}"
    echo
    
    local varnish_installed=false
    local hitch_installed=false
    local whm_plugin_installed=false
    local apache_modified=false
    
    # Check Varnish
    if systemctl list-unit-files | grep -q "varnish.service"; then
        varnish_installed=true
        echo -e "${YELLOW}  📦 Varnish service detected${NC}"
    fi
    
    if command -v varnishd &> /dev/null; then
        echo -e "${YELLOW}  🔧 Varnish binaries found${NC}"
    fi
    
    # Check Hitch
    if systemctl list-unit-files | grep -q "hitch.service"; then
        hitch_installed=true
        echo -e "${YELLOW}  🔒 Hitch service detected${NC}"
    fi
    
    # Check WHM Plugin
    if [ -f "/usr/local/cpanel/whm/docroot/cgi/varnish/whm_varnish_manager.cgi" ]; then
        whm_plugin_installed=true
        echo -e "${YELLOW}  🎮 WHM plugin detected${NC}"
    fi
    
    # Check Apache configuration
    if [ -f "/etc/httpd/conf/httpd.conf" ]; then
        if grep -q "Listen 8080" /etc/httpd/conf/httpd.conf; then
            apache_modified=true
            echo -e "${YELLOW}  🌐 Apache port configuration modified${NC}"
        fi
    fi
    
    echo
    
    if ! $varnish_installed && ! $hitch_installed && ! $whm_plugin_installed && ! $apache_modified; then
        echo -e "${GREEN}✅ No Varnish installation detected. System appears clean.${NC}"
        return 1
    fi
    
    return 0
}

show_uninstall_menu() {
    echo -e "${CYAN}${BOLD}🗑️  UNINSTALL OPTIONS:${NC}"
    echo
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│  ${RED}1${WHITE}) 💥 ${BOLD}Complete Removal${NC}${WHITE}                                                       │${NC}"
    echo -e "${WHITE}│     └─ Remove everything: Varnish, Hitch, WHM plugin, restore Apache               │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${RED}2${WHITE}) 🎮 ${BOLD}Remove WHM Plugin Only${NC}${WHITE}                                                │${NC}"
    echo -e "${WHITE}│     └─ Keep Varnish running, just remove the management interface                 │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${RED}3${WHITE}) 🔧 ${BOLD}Restore Apache Configuration Only${NC}${WHITE}                                    │${NC}"
    echo -e "${WHITE}│     └─ Reset Apache to port 80, keep Varnish for manual management               │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${RED}4${WHITE}) 🔒 ${BOLD}Remove Hitch SSL Termination Only${NC}${WHITE}                                    │${NC}"
    echo -e "${WHITE}│     └─ Remove SSL termination, keep Varnish and Apache configuration             │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${RED}5${WHITE}) 🧹 ${BOLD}Clean Temporary Files Only${NC}${WHITE}                                           │${NC}"
    echo -e "${WHITE}│     └─ Remove logs, cache files, and temporary data                              │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}6${WHITE}) 📋 ${BOLD}Create Backup Before Removal${NC}${WHITE}                                          │${NC}"
    echo -e "${WHITE}│     └─ Backup current configuration before proceeding with removal               │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${BLUE}7${WHITE}) 🔍 ${BOLD}Show What Would Be Removed (Dry Run)${NC}${WHITE}                                  │${NC}"
    echo -e "${WHITE}│     └─ Preview removal actions without making changes                            │${NC}"
    echo -e "${WHITE}│                                                                                     │${NC}"
    echo -e "${WHITE}│  ${GREEN}8${WHITE}) ❌ ${BOLD}Cancel and Exit${NC}${WHITE}                                                      │${NC}"
    echo -e "${WHITE}│     └─ Exit without making any changes                                           │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

create_backup() {
    local backup_dir="/opt/varnish-backup-$(date +%Y%m%d-%H%M%S)"
    
    echo -e "${BLUE}💾 Creating backup...${NC}"
    mkdir -p "$backup_dir"
    
    show_progress_bar 1 5 "Creating backup directory"
    
    # Backup configurations
    if [ -f "/etc/varnish/default.vcl" ]; then
        cp /etc/varnish/default.vcl "$backup_dir/" 2>/dev/null || true
    fi
    show_progress_bar 2 5 "Backing up Varnish configuration"
    
    if [ -f "/etc/httpd/conf/httpd.conf" ]; then
        cp /etc/httpd/conf/httpd.conf "$backup_dir/httpd.conf.backup" 2>/dev/null || true
    fi
    show_progress_bar 3 5 "Backing up Apache configuration"
    
    if [ -f "/etc/hitch/hitch.conf" ]; then
        cp /etc/hitch/hitch.conf "$backup_dir/" 2>/dev/null || true
    fi
    show_progress_bar 4 5 "Backing up Hitch configuration"
    
    # Backup WHM plugin
    if [ -d "/usr/local/cpanel/whm/docroot/cgi/varnish" ]; then
        cp -r /usr/local/cpanel/whm/docroot/cgi/varnish "$backup_dir/" 2>/dev/null || true
    fi
    show_progress_bar 5 5 "Backing up WHM plugin"
    
    echo -e "${GREEN}✅ Backup created at: $backup_dir${NC}"
    log "Backup created at $backup_dir"
    echo
}

dry_run_removal() {
    echo -e "${BLUE}🔍 DRY RUN - What would be removed:${NC}"
    echo
    
    echo -e "${YELLOW}📦 Packages that would be removed:${NC}"
    if rpm -qa | grep -q varnish; then
        echo -e "  • $(rpm -qa | grep varnish | tr '\n' ' ')"
    fi
    if rpm -qa | grep -q hitch; then
        echo -e "  • $(rpm -qa | grep hitch | tr '\n' ' ')"
    fi
    
    echo
    echo -e "${YELLOW}🔧 Services that would be stopped and disabled:${NC}"
    for service in varnish hitch; do
        if systemctl list-unit-files | grep -q "${service}.service"; then
            echo -e "  • $service"
        fi
    done
    
    echo
    echo -e "${YELLOW}📁 Files and directories that would be removed:${NC}"
    local paths=(
        "/etc/varnish"
        "/etc/hitch"
        "/usr/local/cpanel/whm/docroot/cgi/varnish"
        "/var/lib/varnish"
        "/var/log/varnish"
        "/opt/varnish-cpanel-installer"
    )
    
    for path in "${paths[@]}"; do
        if [ -e "$path" ]; then
            echo -e "  • $path"
        fi
    done
    
    echo
    echo -e "${YELLOW}⚙️  Configuration changes that would be made:${NC}"
    if [ -f "/etc/httpd/conf/httpd.conf" ]; then
        if grep -q "Listen 8080" /etc/httpd/conf/httpd.conf; then
            echo -e "  • Apache port restored from 8080 to 80"
        fi
    fi
    
    echo
    echo -e "${RED}⚠️  This is only a preview. No changes have been made.${NC}"
    echo
}

run_with_progress() {
    local command="$1"
    local description="$2"
    local steps="$3"
    
    echo -e "${BLUE}🔧 ${description}${NC}"
    
    {
        eval "$command"
    } &
    local cmd_pid=$!
    
    for ((i=1; i<=steps; i++)); do
        show_progress_bar $i $steps "$description"
        sleep 0.5
    done
    
    wait $cmd_pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ ${description} completed${NC}"
        log "${description} completed successfully"
    else
        echo -e "${RED}❌ ${description} failed${NC}"
        log "${description} failed with exit code $exit_code"
    fi
    
    return $exit_code
}

complete_removal() {
    echo -e "${RED}💥 Starting Complete Removal...${NC}"
    echo
    
    # Confirmation
    echo -e "${YELLOW}⚠️  This will completely remove Varnish and restore original configuration.${NC}"
    echo -e "${WHITE}The following will be removed:${NC}"
    echo -e "${WHITE}  • Varnish Cache service and packages${NC}"
    echo -e "${WHITE}  • Hitch SSL termination${NC}"
    echo -e "${WHITE}  • WHM management plugin${NC}"
    echo -e "${WHITE}  • All configuration files${NC}"
    echo
    echo -e "${WHITE}The following will be restored:${NC}"
    echo -e "${WHITE}  • Apache port 80 configuration${NC}"
    echo -e "${WHITE}  • Original HTTP/HTTPS setup${NC}"
    echo
    
    read -p "Type 'yes' to continue with complete removal: " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${BLUE}🔄 Operation cancelled.${NC}"
        return 0
    fi
    
    # Stop services
    run_with_progress "systemctl stop varnish hitch 2>/dev/null || true" "Stopping services" 2
    
    # Remove packages
    run_with_progress "dnf remove -y varnish hitch 2>/dev/null || yum remove -y varnish hitch 2>/dev/null || true" "Removing packages" 3
    
    # Remove configuration files
    run_with_progress "rm -rf /etc/varnish /etc/hitch /var/lib/varnish /var/log/varnish" "Removing configuration files" 2
    
    # Remove WHM plugin
    run_with_progress "rm -rf /usr/local/cpanel/whm/docroot/cgi/varnish" "Removing WHM plugin" 1
    
    # Restore Apache configuration
    restore_apache_config
    
    # Remove installer
    run_with_progress "rm -rf /opt/varnish-cpanel-installer" "Removing installer files" 1
    
    echo -e "${GREEN}${BOLD}✅ Complete removal finished!${NC}"
    echo -e "${WHITE}Your server has been restored to its original configuration.${NC}"
    echo
}

remove_whm_plugin_only() {
    echo -e "${BLUE}🎮 Removing WHM Plugin...${NC}"
    echo
    
    if run_with_progress "rm -rf /usr/local/cpanel/whm/docroot/cgi/varnish" "Removing WHM plugin files" 1; then
        echo -e "${GREEN}✅ WHM plugin removed successfully!${NC}"
        echo -e "${WHITE}Varnish continues to run normally.${NC}"
    fi
}

restore_apache_config() {
    echo -e "${BLUE}🌐 Restoring Apache Configuration...${NC}"
    
    if [ -f "/etc/httpd/conf/httpd.conf" ]; then
        # Backup current config
        cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.pre-restore
        
        # Remove port 8080 and restore port 80
        sed -i 's/Listen 8080/Listen 80/g' /etc/httpd/conf/httpd.conf
        
        run_with_progress "systemctl restart httpd" "Restarting Apache" 2
        
        echo -e "${GREEN}✅ Apache restored to port 80${NC}"
        log "Apache configuration restored to port 80"
    fi
}

remove_hitch_only() {
    echo -e "${BLUE}🔒 Removing Hitch SSL Termination...${NC}"
    echo
    
    run_with_progress "systemctl stop hitch && systemctl disable hitch" "Stopping Hitch service" 1
    run_with_progress "dnf remove -y hitch 2>/dev/null || yum remove -y hitch 2>/dev/null || true" "Removing Hitch package" 2
    run_with_progress "rm -rf /etc/hitch" "Removing Hitch configuration" 1
    
    echo -e "${GREEN}✅ Hitch SSL termination removed${NC}"
    echo -e "${WHITE}You may need to reconfigure SSL manually.${NC}"
}

clean_temporary_files() {
    echo -e "${BLUE}🧹 Cleaning Temporary Files...${NC}"
    echo
    
    local temp_paths=(
        "/tmp/varnish-*"
        "/var/tmp/varnish-*"
        "/var/log/varnish/*.log"
        "/var/lib/varnish/*"
    )
    
    for path in "${temp_paths[@]}"; do
        run_with_progress "rm -rf $path 2>/dev/null || true" "Cleaning $path" 1
    done
    
    echo -e "${GREEN}✅ Temporary files cleaned${NC}"
}

main() {
    print_header
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ This script must be run as root.${NC}"
        echo "Please use: sudo $0"
        exit 1
    fi
    
    # Check installation status
    if ! check_installation_status; then
        echo -e "${GREEN}Nothing to uninstall. Exiting.${NC}"
        exit 0
    fi
    
    while true; do
        show_uninstall_menu
        
        read -p "Enter your choice (1-8): " choice
        echo
        
        case $choice in
            1)
                create_backup
                complete_removal
                break
                ;;
            2)
                remove_whm_plugin_only
                ;;
            3)
                restore_apache_config
                ;;
            4)
                remove_hitch_only
                ;;
            5)
                clean_temporary_files
                ;;
            6)
                create_backup
                ;;
            7)
                dry_run_removal
                ;;
            8)
                echo -e "${BLUE}👋 Exiting without changes.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please select 1-8.${NC}"
                echo
                ;;
        esac
        
        echo
        echo -e "${CYAN}Press any key to continue...${NC}"
        read -n 1 -s
        clear
        print_header
        check_installation_status
    done
    
    echo -e "${GREEN}${BOLD}🎉 Uninstallation process completed!${NC}"
    echo -e "${WHITE}Log file saved at: $log_file${NC}"
    echo
}

# Run main function
main "$@"