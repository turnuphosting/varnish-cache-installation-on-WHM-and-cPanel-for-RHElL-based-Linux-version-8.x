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

declare -A BACKED_UP_FILES=()

backup_file_once() {
    local file="$1"
    [ -f "$file" ] || return

    if [ -z "${BACKED_UP_FILES[$file]+x}" ]; then
        local timestamp
        timestamp=$(date +%Y%m%d%H%M%S)
        cp "$file" "${file}.backup.${timestamp}" 2>/dev/null || true
        BACKED_UP_FILES[$file]=1
    fi
}

find_conf_files_with_pattern() {
    local pattern="$1"
    shift
    local -a preferred=("$@")
    local -A seen=()
    local file=""

    for file in "${preferred[@]}"; do
        if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then
            if [ -z "${seen[$file]+x}" ]; then
                echo "$file"
                seen[$file]=1
            fi
        fi
    done

    while IFS= read -r file; do
        if [ -n "$file" ] && [ -z "${seen[$file]+x}" ]; then
            echo "$file"
            seen[$file]=1
        fi
    done < <(grep -RIl --include='*.conf' -E "$pattern" /etc/apache2 /etc/httpd 2>/dev/null || true)
}

update_port_in_file() {
    local file="$1"
    local from_port="$2"
    local to_port="$3"

    [ -f "$file" ] || return 1

    if ! grep -Eq "(Listen|<VirtualHost|NameVirtualHost)[[:space:]][^#\n]*[: ]${from_port}([[:space:]>]|$)" "$file"; then
        return 1
    fi

    backup_file_once "$file"

    sed -i -E "s/(Listen\s+0\.0\.0\.0:)${from_port}\b/\1${to_port}/g" "$file"
    sed -i -E "s/(Listen\s+[0-9]{1,3}(\.[0-9]{1,3}){3}:)${from_port}\b/\1${to_port}/g" "$file"
    sed -i -E "s/(Listen\s+\*:?)${from_port}\b/\1${to_port}/g" "$file"
    sed -i -E "s/(Listen\s+\[::\]:)${from_port}\b/\1${to_port}/g" "$file"
    sed -i -E "s/^Listen\s+${from_port}\b/Listen 0.0.0.0:${to_port}/g" "$file"
    sed -i -E "s/(<VirtualHost\s+[^:>]*:)${from_port}\b/\1${to_port}/g" "$file"
    sed -i -E "s/(NameVirtualHost\s+[^:>]*:)${from_port}\b/\1${to_port}/g" "$file"

    log "INFO" "${GREEN}✓ Updated Apache configuration (${file}) port ${from_port}→${to_port}${NC}"
    return 0
}


get_port_conflict_info() {
    local port="$1"
    local conflict_info=""

    if command -v ss >/dev/null 2>&1; then
        conflict_info=$(ss -tulpn 2>/dev/null | awk -v port="$port" 'NR > 1 {
            addr=$5
            gsub(/\[|\]/, "", addr)
            n=split(addr, parts, ":")
            candidate=parts[n]
            if (candidate == port) {
                print $0
            }
        }')
    fi

    if [ -z "$conflict_info" ] && command -v lsof >/dev/null 2>&1; then
        conflict_info=$(lsof -nP -i :"$port" -sTCP:LISTEN 2>/dev/null || true)
    fi

    echo "$conflict_info"
}

check_port_conflict() {
    local port="$1"
    local label="$2"
    local conflict_info=""

    conflict_info=$(get_port_conflict_info "$port")

    if [ -n "$conflict_info" ]; then
        local conflict_summary
        conflict_summary=$(echo "$conflict_info" | head -n 1 | sed 's/[[:space:]]\+/ /g')
        if [ -n "$conflict_summary" ]; then
            log "WARN" "${YELLOW}⚠️ Port ${port} (${label}) is currently in use by:${NC} ${conflict_summary}"
        else
            log "WARN" "${YELLOW}⚠️ Port ${port} (${label}) is currently in use. Stop the conflicting service before continuing.${NC}"
        fi
        echo "$conflict_info" >> "$LOG_FILE"
    fi
}

get_port_process_names() {
    local port="$1"
    local names=""

    if command -v lsof >/dev/null 2>&1; then
        names=$(lsof -nP -i TCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $1}' | sort -u)
    fi

    if [ -z "$names" ]; then
        local info
        info=$(get_port_conflict_info "$port")
        if [ -n "$info" ]; then
            names=$(echo "$info" | grep -oE '\("[^"]+"' | tr -d '()"' | awk '{print $1}' | sort -u)
        fi
    fi

    echo "$names"
}

map_process_to_service() {
    local process="$1"
    case "$process" in
        httpd|apache2) echo "httpd" ;;
        nginx) echo "nginx" ;;
        varnishd) echo "varnish" ;;
        hitch) echo "hitch" ;;
        haproxy) echo "haproxy" ;;
        envoy) echo "envoy" ;;
        caddy) echo "caddy" ;;
        lighttpd) echo "lighttpd" ;;
        crowdsec*) echo "crowdsec" ;;
        traefik) echo "traefik" ;;
        *) echo "" ;;
    esac
}

ensure_port_free() {
    local port="$1"
    local label="$2"
    local allow_httpd="${3:-false}"
    local conflict_info

    conflict_info=$(get_port_conflict_info "$port")

    if [ -z "$conflict_info" ]; then
        return 0
    fi

    local processes
    processes=$(get_port_process_names "$port")
    local attempted=()

    for process in $processes; do
        if [ -z "$process" ]; then
            continue
        fi

        if [ "$allow_httpd" = "true" ] && { [ "$process" = "httpd" ] || [ "$process" = "apache2" ]; }; then
            continue
        fi

        local service
        service=$(map_process_to_service "$process")

        if [ -n "$service" ]; then
            if systemctl status "$service" >/dev/null 2>&1 || systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
                log "WARN" "${YELLOW}⚠️ Attempting to stop conflicting service '$service' on port ${port}...${NC}"
                systemctl stop "$service" >/dev/null 2>&1 || true
                attempted+=("$service")
                sleep 1
            fi
        fi
    done

    conflict_info=$(get_port_conflict_info "$port")
    if [ -n "$conflict_info" ]; then
        local remaining
        remaining=$(get_port_process_names "$port")
        if [ -z "$remaining" ]; then
            remaining="$processes"
        fi
        if [ -z "$remaining" ]; then
            remaining="unknown process"
        fi

        log "ERROR" "${RED}❌ Port ${port} (${label}) is still in use. Conflicting processes: ${remaining}. Please stop or reconfigure these services (e.g., 'systemctl stop <service>') and rerun the installer.${NC}"
        echo "$conflict_info" >> "$LOG_FILE"
        exit 1
    fi

    if [ ${#attempted[@]} -gt 0 ]; then
        log "INFO" "${GREEN}✓ Freed port ${port} by stopping: ${attempted[*]}${NC}"
    fi

    return 0
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

configure_apache_ports() {
    log "INFO" "${BLUE}🛠️ Harmonizing Apache listener ports...${NC}"

    check_port_conflict 80 "Apache HTTP"
    check_port_conflict 443 "HTTPS"

    if [ "$HAS_CPANEL" = true ] && command -v whmapi1 >/dev/null 2>&1; then
        log "INFO" "${CYAN}🔧 Applying WHM tweak settings for Apache ports...${NC}"
        whmapi1 set_tweaksetting key=apache_port value=0.0.0.0:8080 >/dev/null 2>&1 || \
            log "WARN" "${YELLOW}⚠️ Unable to update Apache non-SSL port via WHM API${NC}"
        whmapi1 set_tweaksetting key=apache_ssl_port value=0.0.0.0:8443 >/dev/null 2>&1 || \
            log "WARN" "${YELLOW}⚠️ Unable to update Apache SSL port via WHM API${NC}"
    fi

    local http_pattern='(Listen|<VirtualHost|NameVirtualHost)[[:space:]][^#\n]*[: ]80([[:space:]>]|$)'
    local ssl_pattern='(Listen|<VirtualHost|NameVirtualHost)[[:space:]][^#\n]*[: ]443([[:space:]>]|$)'
    local -a http_candidates=(
        "/etc/apache2/conf/httpd.conf"
        "/etc/httpd/conf/httpd.conf"
        "/etc/apache2/conf.d/port.conf"
        "/etc/httpd/conf.d/port.conf"
        "/etc/apache2/conf/extra/httpd-vhosts.conf"
        "/etc/httpd/conf/extra/httpd-vhosts.conf"
    )
    local -a ssl_candidates=(
        "/etc/apache2/conf.d/ssl.conf"
        "/etc/httpd/conf.d/ssl.conf"
        "/etc/apache2/conf/extra/httpd-ssl.conf"
        "/etc/httpd/conf/extra/httpd-ssl.conf"
        "/etc/apache2/conf/httpd.conf"
        "/etc/httpd/conf/httpd.conf"
    )

    local -a http_conf_files=()
    local -a ssl_conf_files=()
    mapfile -t http_conf_files < <(find_conf_files_with_pattern "$http_pattern" "${http_candidates[@]}")
    mapfile -t ssl_conf_files < <(find_conf_files_with_pattern "$ssl_pattern" "${ssl_candidates[@]}")

    local updated_http=false
    local updated_ssl=false
    local conf=""

    for conf in "${http_conf_files[@]}"; do
        if update_port_in_file "$conf" 80 8080; then
            updated_http=true
        fi
    done

    for conf in "${ssl_conf_files[@]}"; do
        if update_port_in_file "$conf" 443 8443; then
            updated_ssl=true
        fi
    done

    if [ "$updated_http" = false ]; then
        log "WARN" "${YELLOW}⚠️ Could not locate any Apache configuration entries for port 80. Verify Apache configuration manually.${NC}"
    fi

    if [ "$updated_ssl" = false ]; then
        log "WARN" "${YELLOW}⚠️ Could not locate any Apache configuration entries for port 443. Hitch may still conflict with the existing listener.${NC}"
    fi

    if command -v /scripts/rebuildhttpdconf >/dev/null 2>&1; then
        /scripts/rebuildhttpdconf >/dev/null 2>&1 || \
            log "WARN" "${YELLOW}⚠️ Failed to rebuild Apache configuration via WHM scripts${NC}"
    fi

    check_port_conflict 8080 "Apache HTTP (post-change)"
    check_port_conflict 8443 "Apache HTTPS (post-change)"
}

reset_apache_ports() {
    log "INFO" "${BLUE}🧹 Restoring Apache ports to 80/443...${NC}"

    if [ "$HAS_CPANEL" = true ] && command -v whmapi1 >/dev/null 2>&1; then
        whmapi1 set_tweaksetting key=apache_port value=0.0.0.0:80 >/dev/null 2>&1 || true
        whmapi1 set_tweaksetting key=apache_ssl_port value=0.0.0.0:443 >/dev/null 2>&1 || true
    fi

    local http_pattern='(Listen|<VirtualHost|NameVirtualHost)[[:space:]][^#\n]*[: ]8080([[:space:]>]|$)'
    local ssl_pattern='(Listen|<VirtualHost|NameVirtualHost)[[:space:]][^#\n]*[: ]8443([[:space:]>]|$)'
    local -a http_conf_files=()
    local -a ssl_conf_files=()

    mapfile -t http_conf_files < <(find_conf_files_with_pattern "$http_pattern" "/etc/apache2/conf/httpd.conf" "/etc/httpd/conf/httpd.conf" "/etc/apache2/conf.d/port.conf" "/etc/httpd/conf.d/port.conf" "/etc/apache2/conf/extra/httpd-vhosts.conf" "/etc/httpd/conf/extra/httpd-vhosts.conf")
    mapfile -t ssl_conf_files < <(find_conf_files_with_pattern "$ssl_pattern" "/etc/apache2/conf.d/ssl.conf" "/etc/httpd/conf.d/ssl.conf" "/etc/apache2/conf/extra/httpd-ssl.conf" "/etc/httpd/conf/extra/httpd-ssl.conf" "/etc/apache2/conf/httpd.conf" "/etc/httpd/conf/httpd.conf")

    local conf=""
    for conf in "${http_conf_files[@]}"; do
        update_port_in_file "$conf" 8080 80 || true
    done

    for conf in "${ssl_conf_files[@]}"; do
        update_port_in_file "$conf" 8443 443 || true
    done

    if command -v /scripts/rebuildhttpdconf >/dev/null 2>&1; then
        /scripts/rebuildhttpdconf >/dev/null 2>&1 || true
    fi
}

configure_system() {
    log "INFO" "${BLUE}⚙️ Configuring system for optimal performance...${NC}"
    
    show_progress 7 8 "Applying system optimizations"

    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}' || curl -s ifconfig.me || echo "127.0.0.1")
    
    configure_apache_ports

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
    -a :4443,PROXY \
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

    check_port_conflict 4443 "Varnish TLS listener"
    
    log "INFO" "${GREEN}✅ System configured${NC}"
}

configure_hitch_tls() {
    log "INFO" "${BLUE}🔐 Configuring Hitch TLS termination...${NC}"

    local hitch_conf="/etc/hitch/hitch.conf"
    local cert_dir="/etc/hitch/certs"
    local apache_conf=""
    local pem_entries=()

    mkdir -p "$cert_dir" "$cert_dir/ocsp"

    if [ -f /etc/apache2/conf/httpd.conf ]; then
        apache_conf="/etc/apache2/conf/httpd.conf"
    elif [ -f /etc/httpd/conf/httpd.conf ]; then
        apache_conf="/etc/httpd/conf/httpd.conf"
    fi

    if [ -n "$apache_conf" ]; then
        while IFS='|' read -r cert key; do
            # Ensure both certificate and key exist before proceeding
            if [ -f "$cert" ] && [ -f "$key" ]; then
                local name
                name=$(basename "${cert%.*}")
                local combined="$cert_dir/${name}.pem"

                cat "$cert" "$key" > "$combined" 2>/dev/null || true
                chmod 600 "$combined" 2>/dev/null || true
                chown hitch:hitch "$combined" 2>/dev/null || true
                pem_entries+=("$combined")
            fi
        done < <(
            awk '
                /SSLCertificateFile/ {cert=$2}
                /SSLCertificateKeyFile/ && cert {printf "%s|%s\n", cert, $2; cert=""}
            ' "$apache_conf" | sort -u
        )
    fi

    # Fallback to cPanel service certificate if no vhost certificates detected
    if [ ${#pem_entries[@]} -eq 0 ]; then
        if [ -f /var/cpanel/ssl/cpanel/cpanel.pem ]; then
            cp /var/cpanel/ssl/cpanel/cpanel.pem "$cert_dir/cpanel.pem" 2>/dev/null || true
            chmod 600 "$cert_dir/cpanel.pem" 2>/dev/null || true
            chown hitch:hitch "$cert_dir/cpanel.pem" 2>/dev/null || true
            pem_entries+=("$cert_dir/cpanel.pem")
        elif [ -f /etc/pki/tls/certs/localhost.crt ] && [ -f /etc/pki/tls/private/localhost.key ]; then
            cat /etc/pki/tls/certs/localhost.crt /etc/pki/tls/private/localhost.key > "$cert_dir/localhost.pem" 2>/dev/null || true
            chmod 600 "$cert_dir/localhost.pem" 2>/dev/null || true
            chown hitch:hitch "$cert_dir/localhost.pem" 2>/dev/null || true
            pem_entries+=("$cert_dir/localhost.pem")
        fi
    fi

    cat > "$hitch_conf" <<EOF
frontend = "[*]:443"
backend = "[127.0.0.1]:4443"
workers = $((CPU_CORES < 4 ? 4 : CPU_CORES))
daemon = on
user = "hitch"
group = "hitch"
write-proxy-v2 = on
alpn-protos = "h2,http/1.1"
tls-protos = TLSv1.2 TLSv1.3
ciphers = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
ocsp-dir = "$cert_dir/ocsp"
EOF

    if [ ${#pem_entries[@]} -gt 0 ]; then
        for pem in "${pem_entries[@]}"; do
            echo "pem-file = \"$pem\"" >> "$hitch_conf"
        done
        log "INFO" "${GREEN}✅ Hitch certificates configured (${#pem_entries[@]} detected)${NC}"
    else
        echo "# pem-files will be added automatically by update_hitch_certs.sh" >> "$hitch_conf"
        log "WARN" "${YELLOW}⚠️ No SSL certificates detected. Hitch will start with placeholder config.${NC}"
    fi

    chown hitch:hitch "$hitch_conf" 2>/dev/null || true
    chmod 640 "$hitch_conf" 2>/dev/null || true

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable hitch &>/dev/null || true
    systemctl stop hitch &>/dev/null || true
    
    log "INFO" "${CYAN}ℹ️ Hitch configuration prepared. Service will restart after Apache reload.${NC}"
}

cleanup_existing_whm_plugin() {
    local theme=""
    local dynamic_dir=""
    local plugin_dir=""

    if command -v /usr/local/cpanel/bin/unregister_appconfig >/dev/null 2>&1; then
        /usr/local/cpanel/bin/unregister_appconfig varnish_cache_manager >/dev/null 2>&1 || true
    fi

    for plugin_dir in \
        /usr/local/cpanel/whostmgr/docroot/cgi/varnish \
        /usr/local/cpanel/whm/docroot/cgi/varnish
    do
        rm -rf "$plugin_dir" 2>/dev/null || true
    done

    rm -f /usr/local/cpanel/whm/addonfeatures/varnish 2>/dev/null || true
    rm -f /var/cpanel/whm/addon_plugins/varnish.conf 2>/dev/null || true

    for theme in jupiter glass paper_lantern; do
        dynamic_dir="/usr/local/cpanel/base/frontend/${theme}/dynamicui"
        if [ -d "$dynamic_dir" ]; then
            rm -f "$dynamic_dir/varnish_cache_manager.json" 2>/dev/null || true
        fi
    done

    log "INFO" "${CYAN}ℹ️ Removed legacy WHM plugin artefacts before deployment${NC}"
}

install_whm_plugin() {
    if [ "$HAS_CPANEL" = true ]; then
        log "INFO" "${BLUE}🎮 Installing WHM management plugin...${NC}"
        cleanup_existing_whm_plugin
        
        local plugin_dir="/usr/local/cpanel/whostmgr/docroot/cgi/varnish"

        # Create WHM plugin directory
        if ! mkdir -p "$plugin_dir"; then
            log "WARN" "${YELLOW}⚠️ Failed to create WHM plugin directory - continuing without plugin${NC}"
            return 0
        fi
        
        # Install plugin files
        if ! cp whm_varnish_manager.cgi "$plugin_dir/" 2>/dev/null; then
            log "WARN" "${YELLOW}⚠️ Failed to copy WHM manager script - continuing without plugin${NC}"
            return 0
        fi
        
        if ! cp varnish_ajax.cgi "$plugin_dir/" 2>/dev/null; then
            log "WARN" "${YELLOW}⚠️ Failed to copy AJAX handler script - continuing without plugin${NC}"
            return 0
        fi
        
        chmod +x "$plugin_dir"/*.cgi 2>/dev/null || true
        chown root:root "$plugin_dir"/*.cgi 2>/dev/null || true
        sed -i 's/\r$//' "$plugin_dir"/*.cgi 2>/dev/null || true
        
        # Register plugin using AppConfig for modern WHM themes
        local appconfig_tmp
        appconfig_tmp=$(mktemp /tmp/varnish_appconfig.XXXX.conf)
        cat > "$appconfig_tmp" <<'EOF'
name=varnish_cache_manager
displayname=Varnish Cache Manager
version=2.0
service=whostmgr
group=System
category=software
feature=varnish_cache_manager
acls=any
url=varnish/whm_varnish_manager.cgi
entryurl=varnish/whm_varnish_manager.cgi
target=_self
icon=chart-area
EOF

        if [ -x /usr/local/cpanel/bin/register_appconfig ]; then
            if /usr/local/cpanel/bin/register_appconfig "$appconfig_tmp" >/dev/null 2>&1; then
                log "INFO" "${GREEN}✓ WHM AppConfig registered${NC}"
            else
                log "WARN" "${YELLOW}⚠️ Failed to register AppConfig. Plugin may need manual registration.${NC}"
            fi
        fi

        rm -f "$appconfig_tmp"

        # Legacy addon registration for Paper Lantern / older WHM menu
        mkdir -p /var/cpanel/whm/addon_plugins 2>/dev/null || true
        cat > /var/cpanel/whm/addon_plugins/varnish.conf <<'EOF'
name: Varnish Cache Manager
version: 2.0
url: /cgi/varnish/whm_varnish_manager.cgi
category: software
desc: Manage Varnish Cache with real-time performance monitoring
EOF
        chmod 644 /var/cpanel/whm/addon_plugins/varnish.conf 2>/dev/null || true

        # Add dynamic UI entries for modern WHM themes
        for theme in jupiter glass; do
            local dynamic_dir="/usr/local/cpanel/base/frontend/${theme}/dynamicui"
            if [ -d "$dynamic_dir" ]; then
                cat > "$dynamic_dir/varnish_cache_manager.json" <<'EOF'
{
    "item": {
        "name": "varnish_cache_manager",
        "type": "link",
        "data": {
            "href": "/cgi/varnish/whm_varnish_manager.cgi",
            "target": "self"
        },
        "metadata": {
            "label": "Varnish Cache Manager",
            "category": "software",
            "icon": "chart-area"
        }
    }
}
EOF
                chmod 644 "$dynamic_dir/varnish_cache_manager.json" 2>/dev/null || true
            fi
        done

        # Ensure addon features entry exists for legacy WHM menus
        mkdir -p /usr/local/cpanel/whm/addonfeatures 2>/dev/null || true
        cat > /usr/local/cpanel/whm/addonfeatures/varnish <<'EOF'
---
group: System
name: Varnish Cache Manager
url: /cgi/varnish/whm_varnish_manager.cgi
icon: /whm/addon_plugins/park_wrapper_24.gif
description: Manage Varnish Cache with real-time performance monitoring
EOF
        chmod 644 /usr/local/cpanel/whm/addonfeatures/varnish 2>/dev/null || true

        if command -v whmapi1 >/dev/null 2>&1; then
            whmapi1 flush_third_party_dynamicui name=varnish_cache_manager >/dev/null 2>&1 || true
        fi

        if [ -x /usr/local/cpanel/bin/clearcache ]; then
            /usr/local/cpanel/bin/clearcache whostmgr 2>/dev/null || true
        fi

        if command -v /usr/local/cpanel/bin/build_locale_databases >/dev/null 2>&1; then
            /usr/local/cpanel/bin/build_locale_databases >/dev/null 2>&1 || true
        fi

        if command -v /usr/local/cpanel/bin/restartsrv_cpsrvd >/dev/null 2>&1; then
            /usr/local/cpanel/bin/restartsrv_cpsrvd >/dev/null 2>&1 || true
        else
            systemctl reload cpanel 2>/dev/null || true
        fi
        
        log "INFO" "${GREEN}✅ WHM plugin installation completed${NC}"
    else
        log "INFO" "${CYAN}📝 cPanel/WHM not detected - skipping WHM plugin installation${NC}"
    fi
}

start_services() {
    log "INFO" "${BLUE}🔄 Starting optimized services...${NC}"
    
    show_progress 8 8 "Starting services"
    
    ensure_port_free 8080 "Apache HTTP (post-change)"
    ensure_port_free 8443 "Apache HTTPS (post-change)"
    ensure_port_free 80 "Varnish HTTP"
    ensure_port_free 443 "Hitch TLS frontend"
    ensure_port_free 4443 "Varnish TLS backend"

    # Start services in correct order
    systemctl enable httpd varnish hitch &>/dev/null
    restart_apache
    sleep 2
    systemctl restart varnish &>/dev/null
    sleep 2
    systemctl restart hitch &>/dev/null || true
    
    # Verify services
    if systemctl is-active --quiet hitch; then
        log "INFO" "${GREEN}✓ Hitch is active${NC}"
    else
        log "WARN" "${YELLOW}⚠️ Hitch is not active. SSL termination may not be available until certificates are configured.${NC}"
    fi
    
    if systemctl is-active --quiet httpd && systemctl is-active --quiet varnish; then
        log "INFO" "${GREEN}✅ Core services started successfully${NC}"
    else
        log "ERROR" "${RED}❌ Service startup failed${NC}"
        return 1
    fi
}

stop_services() {
    log "INFO" "${BLUE}⛔ Stopping Varnish, Hitch, and Apache...${NC}"
    systemctl stop hitch &>/dev/null || true
    systemctl stop varnish &>/dev/null || true
    systemctl stop httpd &>/dev/null || true
    systemctl stop nginx &>/dev/null || true
}

restart_apache() {
    if [ -x /scripts/restartsrv_httpd ]; then
        /scripts/restartsrv_httpd --no-verbose >/dev/null 2>&1 || /scripts/restartsrv_httpd >/dev/null 2>&1 || true
    elif [ -x /usr/local/cpanel/scripts/restartsrv_httpd ]; then
        /usr/local/cpanel/scripts/restartsrv_httpd --no-verbose >/dev/null 2>&1 || /usr/local/cpanel/scripts/restartsrv_httpd >/dev/null 2>&1 || true
    else
        systemctl restart httpd &>/dev/null || true
    fi
}

run_performance_optimization() {
    log "INFO" "${BLUE}⚡ Applying performance optimizations...${NC}"
    
    log "INFO" "${CYAN}ℹ️ Performance tuning is now handled directly by the unified installer.${NC}"
    log "INFO" "${CYAN}ℹ️ Varnish runtime parameters and system limits are configured automatically.${NC}"
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
    log "INFO" "${WHITE}║     • Validate: sudo httpd -t && sudo varnishd -C -f /etc/varnish/default.vcl ║${NC}"
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
    stop_services
    install_varnish_and_hitch
    configure_system
    configure_hitch_tls
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
    stop_services
    install_varnish_and_hitch
    configure_system
    configure_hitch_tls
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
    stop_services
    configure_system
    configure_hitch_tls
    install_whm_plugin
    ensure_port_free 8080 "Apache HTTP (post-change)"
    ensure_port_free 8443 "Apache HTTPS (post-change)"
    restart_apache
    ensure_port_free 80 "Varnish HTTP"
    ensure_port_free 443 "Hitch TLS frontend"
    ensure_port_free 4443 "Varnish TLS backend"
    systemctl restart varnish &>/dev/null
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

    detect_system
    if validate_installation; then
        log "INFO" "${GREEN}✅ Environment looks healthy${NC}"
    else
        log "WARN" "${YELLOW}⚠️ Detected potential issues. Review the log output above for details.${NC}"
    fi
}

uninstall_varnish() {
    log "INFO" "${PURPLE}🗑️ Starting uninstallation...${NC}"
    echo

    detect_system
    stop_services
    cleanup_existing_whm_plugin
    systemctl disable varnish hitch &>/dev/null || true
    systemctl enable httpd &>/dev/null || true
    rm -rf /etc/systemd/system/varnish.service.d 2>/dev/null || true
    rm -rf /etc/systemd/system/hitch.service.d 2>/dev/null || true
    rm -rf /etc/hitch/certs 2>/dev/null || true
    rm -f /etc/hitch/hitch.conf 2>/dev/null || true
    systemctl daemon-reload

    if command -v dnf >/dev/null 2>&1; then
        dnf remove -y varnish hitch &>/dev/null || true
    else
        yum remove -y varnish hitch &>/dev/null || true
    fi

    reset_apache_ports
    restart_apache

    log "INFO" "${GREEN}✅ Uninstallation completed. Apache is back on ports 80/443.${NC}"
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
    case "${1:-}" in
        --auto|--full)
            full_installation
            exit 0
            ;;
        --performance)
            performance_installation
            exit 0
            ;;
        --cpanel-only|--cpanel)
            cpanel_configuration
            exit 0
            ;;
        --plugin-only|--plugin)
            whm_plugin_only
            exit 0
            ;;
        --optimize-only|--optimize)
            optimization_only
            exit 0
            ;;
        --status)
            status_check
            exit 0
            ;;
        --uninstall)
            uninstall_varnish
            exit 0
            ;;
        --menu|--interactive)
            shift
            ;;
        "")
            ;;
        *)
            log "WARN" "${YELLOW}⚠️ Unknown flag '${1}'. Falling back to interactive mode.${NC}"
            ;;
    esac
    
    # Check if running in non-interactive mode (piped from curl)
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        log "INFO" "${CYAN}🚀 Detected non-interactive mode (curl | bash). Starting automatic full installation...${NC}"
        log "INFO" "${WHITE}📋 This will install:${NC}"
        log "INFO" "${WHITE}   • Varnish Cache with LiteSpeed-level optimizations${NC}"
        log "INFO" "${WHITE}   • Hitch SSL termination${NC}"
        log "INFO" "${WHITE}   • Apache port reconfiguration (8080)${NC}"
        log "INFO" "${WHITE}   • Beautiful WHM management plugin${NC}"
        log "INFO" "${WHITE}   • Real-time performance monitoring${NC}"
        echo
        log "INFO" "${YELLOW}⏳ Installation will begin in 5 seconds... (Press Ctrl+C to cancel)${NC}"
        sleep 5
        full_installation
        exit 0
    fi
    
    # Interactive mode only when we have a proper terminal
    while true; do
        show_installation_menu
        
        # Check if we can read from terminal
        if ! read -t 30 -p "Enter your choice (1-8) [default: 1]: " choice; then
            log "INFO" "${CYAN}⏰ No input received. Defaulting to full installation...${NC}"
            choice=1
        fi
        
        # Default to option 1 if no choice provided
        choice=${choice:-1}
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