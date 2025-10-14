#!/bin/bash
#
# Varnish Installation Status Checker
# Provides comprehensive status overview and recommendations
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

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                          ║"
    echo "║              📊 VARNISH INSTALLATION STATUS CHECKER 📊                                  ║"
    echo "║                                                                                          ║"
    echo "║                    Comprehensive system analysis and recommendations                     ║"
    echo "║                                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

check_system_info() {
    echo -e "${CYAN}${BOLD}🖥️  SYSTEM INFORMATION${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│ OS:${NC} $(cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
    echo -e "${WHITE}│ Kernel:${NC} $(uname -r)"
    echo -e "${WHITE}│ Architecture:${NC} $(uname -m)"
    echo -e "${WHITE}│ Memory:${NC} $(free -h | awk '/^Mem:/ {print $2" total, "$3" used, "$7" available"}')"
    echo -e "${WHITE}│ CPU:${NC} $(nproc) cores"
    echo -e "${WHITE}│ Uptime:${NC} $(uptime -p)"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

check_cpanel_whm() {
    echo -e "${CYAN}${BOLD}🎛️  cPANEL/WHM STATUS${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    
    if [ -f /usr/local/cpanel/version ]; then
        local cpanel_version=$(cat /usr/local/cpanel/version)
        echo -e "${WHITE}│ cPanel Version:${NC} ${GREEN}$cpanel_version${NC}"
    else
        echo -e "${WHITE}│ cPanel:${NC} ${RED}Not installed${NC}"
    fi
    
    if [ -f /usr/local/cpanel/whm/docroot/cgi/whm.cgi ]; then
        echo -e "${WHITE}│ WHM:${NC} ${GREEN}Available${NC}"
    else
        echo -e "${WHITE}│ WHM:${NC} ${RED}Not available${NC}"
    fi
    
    if systemctl is-active --quiet cpanel 2>/dev/null; then
        echo -e "${WHITE}│ cPanel Service:${NC} ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}│ cPanel Service:${NC} ${RED}Not running${NC}"
    fi
    
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

check_varnish_status() {
    echo -e "${CYAN}${BOLD}🚀 VARNISH CACHE STATUS${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    
    # Check if Varnish is installed
    if command -v varnishd &> /dev/null; then
        local version=$(varnishd -V 2>&1 | head -1 | awk '{print $2}')
        echo -e "${WHITE}│ Varnish Version:${NC} ${GREEN}$version${NC}"
    else
        echo -e "${WHITE}│ Varnish:${NC} ${RED}Not installed${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo
        return 1
    fi
    
    # Check service status
    if systemctl is-active --quiet varnish 2>/dev/null; then
        echo -e "${WHITE}│ Service Status:${NC} ${GREEN}Running${NC}"
        
        # Get uptime
        local uptime=$(systemctl show varnish --property=ActiveEnterTimestamp --value)
        if [ -n "$uptime" ]; then
            echo -e "${WHITE}│ Service Uptime:${NC} $(date -d "$uptime" +'%Y-%m-%d %H:%M:%S') ($(date -d "$uptime" +'%s') seconds ago)"
        fi
    else
        echo -e "${WHITE}│ Service Status:${NC} ${RED}Not running${NC}"
    fi
    
    # Check if enabled
    if systemctl is-enabled --quiet varnish 2>/dev/null; then
        echo -e "${WHITE}│ Auto-start:${NC} ${GREEN}Enabled${NC}"
    else
        echo -e "${WHITE}│ Auto-start:${NC} ${RED}Disabled${NC}"
    fi
    
    # Check configuration
    if [ -f /etc/varnish/default.vcl ]; then
        echo -e "${WHITE}│ Configuration:${NC} ${GREEN}/etc/varnish/default.vcl${NC}"
        
        # Check for backend configuration
        if grep -q "backend.*{" /etc/varnish/default.vcl; then
            local backend_port=$(grep -A 5 "backend.*{" /etc/varnish/default.vcl | grep "\.port" | head -1 | sed 's/.*= *"\?//; s/"\?;.*//')
            echo -e "${WHITE}│ Backend Port:${NC} ${GREEN}$backend_port${NC}"
        fi
    else
        echo -e "${WHITE}│ Configuration:${NC} ${RED}Missing${NC}"
    fi
    
    # Check listening port
    if ss -tlnp | grep -q ":80.*varnish"; then
        echo -e "${WHITE}│ Listening Port:${NC} ${GREEN}80 (HTTP)${NC}"
    elif ss -tlnp | grep -q ":6081.*varnish"; then
        echo -e "${WHITE}│ Listening Port:${NC} ${YELLOW}6081 (Default)${NC}"
    else
        echo -e "${WHITE}│ Listening Port:${NC} ${RED}Unknown${NC}"
    fi
    
    # Check statistics if running
    if systemctl is-active --quiet varnish 2>/dev/null && command -v varnishstat &> /dev/null; then
        local stats=$(varnishstat -1 -f MAIN.uptime,MAIN.cache_hit,MAIN.cache_miss,MAIN.n_object 2>/dev/null)
        if [ -n "$stats" ]; then
            echo -e "${WHITE}│ Cache Stats:${NC}"
            echo "$stats" | while read line; do
                echo -e "${WHITE}│   $(echo $line | awk '{print $1}'):${NC} ${GREEN}$(echo $line | awk '{print $2}')${NC}"
            done
        fi
    fi
    
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

check_hitch_status() {
    echo -e "${CYAN}${BOLD}🔒 HITCH SSL TERMINATION${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    
    if command -v hitch &> /dev/null; then
        local version=$(hitch --version 2>&1 | head -1 | awk '{print $2}')
        echo -e "${WHITE}│ Hitch Version:${NC} ${GREEN}$version${NC}"
    else
        echo -e "${WHITE}│ Hitch:${NC} ${RED}Not installed${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo
        return 1
    fi
    
    if systemctl is-active --quiet hitch 2>/dev/null; then
        echo -e "${WHITE}│ Service Status:${NC} ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}│ Service Status:${NC} ${RED}Not running${NC}"
    fi
    
    if [ -f /etc/hitch/hitch.conf ]; then
        echo -e "${WHITE}│ Configuration:${NC} ${GREEN}/etc/hitch/hitch.conf${NC}"
        
        # Check listening port
        if grep -q "frontend.*443" /etc/hitch/hitch.conf; then
            echo -e "${WHITE}│ SSL Port:${NC} ${GREEN}443${NC}"
        fi
        
        # Check backend
        if grep -q "backend.*127.0.0.1" /etc/hitch/hitch.conf; then
            local backend=$(grep "backend.*127.0.0.1" /etc/hitch/hitch.conf | awk '{print $3}')
            echo -e "${WHITE}│ Backend:${NC} ${GREEN}$backend${NC}"
        fi
    else
        echo -e "${WHITE}│ Configuration:${NC} ${RED}Missing${NC}"
    fi
    
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

check_apache_status() {
    echo -e "${CYAN}${BOLD}🌐 APACHE WEB SERVER${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    
    if command -v httpd &> /dev/null; then
        local version=$(httpd -v | head -1 | awk '{print $3}' | cut -d'/' -f2)
        echo -e "${WHITE}│ Apache Version:${NC} ${GREEN}$version${NC}"
    else
        echo -e "${WHITE}│ Apache:${NC} ${RED}Not installed${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo
        return 1
    fi
    
    if systemctl is-active --quiet httpd 2>/dev/null; then
        echo -e "${WHITE}│ Service Status:${NC} ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}│ Service Status:${NC} ${RED}Not running${NC}"
    fi
    
    # Check listening ports
    if [ -f /etc/httpd/conf/httpd.conf ]; then
        local ports=$(grep "^Listen" /etc/httpd/conf/httpd.conf | awk '{print $2}' | tr '\n' ' ')
        if [[ "$ports" == *"8080"* ]]; then
            echo -e "${WHITE}│ Listening Ports:${NC} ${GREEN}$ports${NC} ${CYAN}(Configured for Varnish)${NC}"
        else
            echo -e "${WHITE}│ Listening Ports:${NC} ${YELLOW}$ports${NC} ${CYAN}(Standard configuration)${NC}"
        fi
    fi
    
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

check_whm_plugin() {
    echo -e "${CYAN}${BOLD}🎮 WHM MANAGEMENT PLUGIN${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    
    if [ -f "/usr/local/cpanel/whm/docroot/cgi/varnish/whm_varnish_manager.cgi" ]; then
        echo -e "${WHITE}│ Plugin Status:${NC} ${GREEN}Installed${NC}"
        echo -e "${WHITE}│ Location:${NC} ${GREEN}/usr/local/cpanel/whm/docroot/cgi/varnish/${NC}"
        
        if [ -f "/usr/local/cpanel/whm/docroot/cgi/varnish/varnish_ajax.cgi" ]; then
            echo -e "${WHITE}│ AJAX Backend:${NC} ${GREEN}Available${NC}"
        else
            echo -e "${WHITE}│ AJAX Backend:${NC} ${RED}Missing${NC}"
        fi
        
        # Check if accessible
        local server_ip=$(hostname -I | awk '{print $1}')
        echo -e "${WHITE}│ Access URL:${NC} ${CYAN}https://$server_ip:2087/cgi/varnish/whm_varnish_manager.cgi${NC}"
        echo -e "${WHITE}│ WHM Menu:${NC} ${CYAN}System → Varnish Cache Manager${NC}"
    else
        echo -e "${WHITE}│ Plugin Status:${NC} ${RED}Not installed${NC}"
    fi
    
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

check_network_connectivity() {
    echo -e "${CYAN}${BOLD}🌐 NETWORK CONNECTIVITY${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    
    # Test HTTP
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null | grep -q "200\|301\|302"; then
        echo -e "${WHITE}│ HTTP (Port 80):${NC} ${GREEN}Responding${NC}"
    else
        echo -e "${WHITE}│ HTTP (Port 80):${NC} ${RED}Not responding${NC}"
    fi
    
    # Test HTTPS
    if curl -s -k -o /dev/null -w "%{http_code}" https://localhost:443 2>/dev/null | grep -q "200\|301\|302"; then
        echo -e "${WHITE}│ HTTPS (Port 443):${NC} ${GREEN}Responding${NC}"
    else
        echo -e "${WHITE}│ HTTPS (Port 443):${NC} ${RED}Not responding${NC}"
    fi
    
    # Test Apache backend
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "200\|301\|302"; then
        echo -e "${WHITE}│ Apache Backend (Port 8080):${NC} ${GREEN}Responding${NC}"
    else
        echo -e "${WHITE}│ Apache Backend (Port 8080):${NC} ${RED}Not responding${NC}"
    fi
    
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

generate_recommendations() {
    echo -e "${YELLOW}${BOLD}💡 RECOMMENDATIONS & NEXT STEPS${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    
    local has_issues=false
    
    # Check if Varnish is not installed
    if ! command -v varnishd &> /dev/null; then
        echo -e "${WHITE}│ 🚀 Install Varnish:${NC} ${CYAN}curl -sSL https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main/install.sh | sudo bash${NC}"
        has_issues=true
    fi
    
    # Check if Varnish is not running
    if command -v varnishd &> /dev/null && ! systemctl is-active --quiet varnish 2>/dev/null; then
        echo -e "${WHITE}│ 🔧 Start Varnish:${NC} ${CYAN}systemctl start varnish && systemctl enable varnish${NC}"
        has_issues=true
    fi
    
    # Check if Apache is on wrong port
    if [ -f /etc/httpd/conf/httpd.conf ] && ! grep -q "Listen 8080" /etc/httpd/conf/httpd.conf; then
        echo -e "${WHITE}│ ⚙️  Configure Apache:${NC} ${CYAN}make install-cpanel${NC}"
        has_issues=true
    fi
    
    # Check if WHM plugin is missing
    if [ ! -f "/usr/local/cpanel/whm/docroot/cgi/varnish/whm_varnish_manager.cgi" ]; then
        echo -e "${WHITE}│ 🎮 Install WHM Plugin:${NC} ${CYAN}make install-plugin${NC}"
        has_issues=true
    fi
    
    # Check if SSL termination is missing
    if ! command -v hitch &> /dev/null; then
        echo -e "${WHITE}│ 🔒 Setup SSL Termination:${NC} ${CYAN}make install${NC}"
        has_issues=true
    fi
    
    if ! $has_issues; then
        echo -e "${WHITE}│ ✅ System appears to be properly configured!${NC}"
        echo -e "${WHITE}│ 📊 Access WHM Plugin: System → Varnish Cache Manager${NC}"
        echo -e "${WHITE}│ 🔍 Monitor Performance: varnishstat${NC}"
        echo -e "${WHITE}│ 📋 View Logs: journalctl -u varnish -f${NC}"
    fi
    
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

show_quick_commands() {
    echo -e "${BLUE}${BOLD}⚡ QUICK COMMANDS${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│ 📊 Check Status:${NC} ${CYAN}systemctl status varnish httpd hitch${NC}"
    echo -e "${WHITE}│ 🔧 Restart Services:${NC} ${CYAN}systemctl restart varnish httpd${NC}"
    echo -e "${WHITE}│ 📋 View Logs:${NC} ${CYAN}journalctl -u varnish -f${NC}"
    echo -e "${WHITE}│ 📈 Statistics:${NC} ${CYAN}varnishstat${NC}"
    echo -e "${WHITE}│ 🧹 Clear Cache:${NC} ${CYAN}varnishadm 'ban req.url ~ .'${NC}"
    echo -e "${WHITE}│ ✅ Validate Config:${NC} ${CYAN}make validate${NC}"
    echo -e "${WHITE}│ 🗑️  Uninstall:${NC} ${CYAN}./easy-uninstall.sh${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

main() {
    print_header
    
    check_system_info
    check_cpanel_whm
    check_varnish_status
    check_hitch_status
    check_apache_status
    check_whm_plugin
    check_network_connectivity
    generate_recommendations
    show_quick_commands
    
    echo -e "${GREEN}${BOLD}📊 Status check completed!${NC}"
    echo -e "${WHITE}Run this script anytime to check your Varnish installation status.${NC}"
    echo
}

# Run main function
main "$@"