#!/bin/bash
#
# 🚀 AUTOMATIC VARNISH INSTALLER - NO PROMPTS
# 
# One-liner that immediately starts full installation
# Perfect for automated deployments and curl | bash usage
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main/auto-install.sh | sudo bash
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

print_auto_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                                    ║"
    echo "║                     🚀 AUTOMATIC VARNISH INSTALLER 🚀                                             ║"
    echo "║                                                                                                    ║"
    echo "║                        🏆 LITESPEED-LEVEL PERFORMANCE GUARANTEED 🏆                               ║"
    echo "║                                                                                                    ║"
    echo "║  ⚡ Starting automatic installation in 3 seconds...                                               ║"
    echo "║  📦 This will install everything you need for maximum performance                                 ║"
    echo "║  🎮 Beautiful WHM plugin will be available after installation                                    ║"
    echo "║                                                                                                    ║"
    echo "║  Press Ctrl+C now to cancel, or wait for automatic installation                                   ║"
    echo "║                                                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

main() {
    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ This script must be run as root. Please use sudo.${NC}"
        exit 1
    fi
    
    print_auto_banner
    
    # Countdown
    for i in 3 2 1; do
        echo -e "${YELLOW}🕐 Starting in $i seconds...${NC}"
        sleep 1
    done
    
    echo -e "${GREEN}🚀 Downloading and running unified installer...${NC}"
    echo
    
    # Download and run the unified installer with aggressive cache busting
    local installer_url="https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main/unified-installer.sh"
    local cache_buster
    cache_buster=$(date +%s)
    curl -H "Cache-Control: no-cache" -H "Pragma: no-cache" -sSL "${installer_url}?cb=${cache_buster}" | bash -s -- --auto
}

# Run main function
main "$@"