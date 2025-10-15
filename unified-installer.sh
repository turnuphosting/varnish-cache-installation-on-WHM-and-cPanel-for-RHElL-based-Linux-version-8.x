#!/bin/bash
#
# Unified Varnish + Hitch installer for cPanel/WHM (RHEL 8 family)
#
# Baseline installation and port rewrites follow the legacy scripts.
# We then layer on the optimised VCL, tuning, and WHM integration.
#
set -euo pipefail
umask 022

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local level="$1"; shift
    local colour="$NC"
    case "$level" in
        INFO) colour="$GREEN";;
        WARN) colour="$YELLOW";;
        ERROR) colour="$RED";;
        *) colour="$CYAN";;
    esac
    echo -e "${colour}[$level]${NC} $*" >&2
}

fatal() {
    log ERROR "$*"
    exit 1
}

if [[ "$EUID" -ne 0 ]]; then
    fatal "Run this installer as root."
fi

if [[ -n ${BASH_SOURCE+x} ]]; then
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
else
    SCRIPT_DIR="$PWD"
fi
APACHE_CONF="/etc/apache2/conf/httpd.conf"
[[ -f "$APACHE_CONF" ]] || APACHE_CONF="/etc/httpd/conf/httpd.conf"
[[ -f "$APACHE_CONF" ]] || fatal "Could not locate Apache httpd.conf. Install cPanel/WHM before running."

CPU_CORES=$(nproc 2>/dev/null || echo 2)
MEM_TOTAL_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 2048)
THREAD_POOLS=$(( CPU_CORES < 2 ? 2 : CPU_CORES ))
THREAD_MIN=$(( CPU_CORES * 5 < 50 ? 50 : CPU_CORES * 5 ))
THREAD_MAX=$(( CPU_CORES * 150 < 1000 ? 1000 : CPU_CORES * 150 ))
CACHE_STORAGE_VALUE=""

INSTALL_BASE="/opt/varnish-cpanel-installer"
VARNISH_DEFAULT_VCL="/etc/varnish/default.vcl"
VARNISH_SERVICE_OVERRIDE="/etc/systemd/system/varnish.service.d/override.conf"
HITCH_CONF="/etc/hitch/hitch.conf"
WHM_PLUGIN_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/varnish"
APPCONFIG_FILE="/var/cpanel/apps/varnish-cache-manager.conf"
ASSET_DIR="$INSTALL_BASE/assets"
REPO_BASE_URL="https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main"

choose_cache_storage() {
    if (( MEM_TOTAL_MB < 2048 )); then
        echo "malloc,512m"
    elif (( MEM_TOTAL_MB < 4096 )); then
        echo "malloc,1g"
    elif (( MEM_TOTAL_MB < 8192 )); then
        echo "malloc,2g"
    else
        echo "malloc,4g"
    fi
}

SERVER_IP=""
detect_server_ip() {
    local via_ip
    if via_ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}'); then
        SERVER_IP="$via_ip"
    elif via_ip=$(hostname -I 2>/dev/null | awk '{print $1}'); then
        SERVER_IP="$via_ip"
    elif via_ip=$(curl -4s https://ifconfig.co 2>/dev/null); then
        SERVER_IP="$via_ip"
    else
        SERVER_IP="127.0.0.1"
    fi
    log INFO "Detected server IP: $SERVER_IP"
}

declare -A BACKUPS=()
backup_config() {
    local file="$1"
    [[ -f "$file" ]] || return
    if [[ -z "${BACKUPS[$file]+x}" ]]; then
        local stamp
        stamp=$(date +%Y%m%d%H%M%S)
        cp "$file" "${file}.bak.${stamp}"
        BACKUPS[$file]=1
        log INFO "Backed up $file -> ${file}.bak.${stamp}"
    fi
}

ensure_asset() {
    local local_path="$1"
    local remote_rel="$2"

    if [[ -f "$local_path" ]]; then
        echo "$local_path"
        return 0
    fi

    if [[ -z "$remote_rel" ]]; then
        fatal "Missing required asset at $local_path"
    fi

    mkdir -p "$(dirname "$local_path")"
    log INFO "Downloading $remote_rel from repository"
    curl -fsSL "$REPO_BASE_URL/$remote_rel" -o "$local_path" || \
        fatal "Failed to download $remote_rel from $REPO_BASE_URL"
    echo "$local_path"
}

stop_service_if_present() {
    local service_name="$1"
    if systemctl list-unit-files "$service_name" &>/dev/null; then
        systemctl stop "$service_name" >/dev/null 2>&1 || true
    fi
}

describe_port_holders() {
    local port="$1"
    local owners=""
    if command -v ss >/dev/null 2>&1; then
        owners=$(ss -H -ltnp 2>/dev/null | awk -v p=":$port" '$4 ~ p {print $5 " " $6}')
    elif command -v netstat >/dev/null 2>&1; then
        owners=$(netstat -tulpn 2>/dev/null | awk -v p=":$port" '$4 ~ p {print $4 " " $7}')
    fi
    echo "$owners"
}

ensure_port_free() {
    local port="$1"
    local description="$2"
    local attempts=0
    local owners

    owners=$(describe_port_holders "$port")
    while [[ -n "$owners" ]]; do
        if (( attempts == 0 )); then
            log WARN "Port $port ($description) is still in use by: $owners"
            log WARN "Attempting to wait for the port to become free..."
        fi

        if (( attempts >= 5 )); then
            fatal "Port $port ($description) remains in use. Stop the owning service(s) and re-run the installer."
        fi

        sleep 1
        attempts=$((attempts + 1))
        owners=$(describe_port_holders "$port")
    done

    log INFO "Port $port ready for $description"
}

get_asset_path() {
    local relative_path="$1"
    local local_candidate="$SCRIPT_DIR/$relative_path"
    if [[ -f "$local_candidate" ]]; then
        echo "$local_candidate"
        return 0
    fi

    ensure_asset "$ASSET_DIR/$relative_path" "$relative_path"
}

ensure_package() {
    local pkg="$1"
    if ! rpm -q "$pkg" &>/dev/null; then
        log INFO "Installing package: $pkg"
        dnf install -y "$pkg" >/dev/null
    fi
}

install_packages() {
    log INFO "Ensuring required packages are installed"
    ensure_package epel-release
    dnf makecache >/dev/null 2>&1 || true
    for pkg in varnish hitch curl jq bind-utils openssl perl; do
        ensure_package "$pkg"
    done
}

stop_conflicting_services() {
    log INFO "Stopping Apache, Varnish, and Hitch before reconfiguration"
    stop_service_if_present varnish.service
    stop_service_if_present varnish
    stop_service_if_present varnishncsa.service
    stop_service_if_present varnishncsa
    stop_service_if_present hitch.service
    stop_service_if_present hitch
    stop_service_if_present httpd.service
    stop_service_if_present httpd
    stop_service_if_present apache2.service
    stop_service_if_present apache2
    stop_service_if_present nginx.service
    stop_service_if_present nginx
    stop_service_if_present ea-nginx.service
    stop_service_if_present lsws.service
    stop_service_if_present lsws
    stop_service_if_present lshttpd.service
    stop_service_if_present openlitespeed.service
    stop_service_if_present caddy.service

    ensure_port_free 80 "Varnish HTTP listener"
    ensure_port_free 443 "Hitch TLS listener"
    ensure_port_free 4443 "Varnish TLS backend listener"
}

ensure_varnish_repo() {
    local repo_file="/etc/yum.repos.d/varnishcache_varnish70.repo"
    if [[ -f "$repo_file" ]]; then
        log INFO "Varnish Cache 7 repository already present"
        return
    fi

    log INFO "Configuring Varnish Cache 7 repository from packagecloud"
    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish70/script.rpm.sh | bash >/dev/null 2>&1 || \
        fatal "Unable to add Varnish Cache 7 repository"
}

configure_apache_ports() {
    log INFO "Reconfiguring Apache to listen on 8080/8443"
    backup_config "$APACHE_CONF"

    if ! grep -Eq '^Listen\s+0\.0\.0\.0:8080' "$APACHE_CONF"; then
        if grep -Eq '^Listen\s+80(\s|$)' "$APACHE_CONF"; then
            sed -ri 's/^Listen\s+80(\s|$)/Listen 0.0.0.0:8080\1/' "$APACHE_CONF"
        elif grep -Eq '^Listen\s+0\.0\.0\.0:80(\s|$)' "$APACHE_CONF"; then
            sed -ri 's/^Listen\s+0\.0\.0\.0:80(\s|$)/Listen 0.0.0.0:8080\1/' "$APACHE_CONF"
        elif grep -Eq '^Listen\s+\[::\]:80(\s|$)' "$APACHE_CONF"; then
            sed -ri 's/^Listen\s+\[::\]:80(\s|$)/Listen [::]:8080\1/' "$APACHE_CONF"
        else
            echo "Listen 0.0.0.0:8080" >> "$APACHE_CONF"
        fi
    fi

    if ! grep -Eq '^Listen\s+0\.0\.0\.0:8443' "$APACHE_CONF"; then
        if grep -Eq '^Listen\s+443(\s|$)' "$APACHE_CONF"; then
            sed -ri 's/^Listen\s+443(\s|$)/Listen 0.0.0.0:8443\1/' "$APACHE_CONF"
        elif grep -Eq '^Listen\s+0\.0\.0\.0:443(\s|$)' "$APACHE_CONF"; then
            sed -ri 's/^Listen\s+0\.0\.0\.0:443(\s|$)/Listen 0.0.0.0:8443\1/' "$APACHE_CONF"
        elif grep -Eq '^Listen\s+\[::\]:443(\s|$)' "$APACHE_CONF"; then
            sed -ri 's/^Listen\s+\[::\]:443(\s|$)/Listen [::]:8443\1/' "$APACHE_CONF"
        else
            echo "Listen 0.0.0.0:8443" >> "$APACHE_CONF"
        fi
    fi

    perl -0pi -e 's/<VirtualHost\s+\*:80>/<VirtualHost *:8080>/g' "$APACHE_CONF" 2>/dev/null || true
    perl -0pi -e 's/<VirtualHost\s+\*:443>/<VirtualHost *:8443>/g' "$APACHE_CONF" 2>/dev/null || true
    perl -0pi -e 's/NameVirtualHost\s+\*:80/NameVirtualHost *:8080/g' "$APACHE_CONF" 2>/dev/null || true
    perl -0pi -e 's/NameVirtualHost\s+\*:443/NameVirtualHost *:8443/g' "$APACHE_CONF" 2>/dev/null || true
}

update_whm_ports() {
    local whmapi="/usr/local/cpanel/bin/whmapi1"
    if [[ ! -x "$whmapi" ]]; then
        log WARN "WHM API not available; update Apache ports manually in Tweak Settings"
        return
    fi

    log INFO "Updating WHM Tweak Settings for Apache listener ports"
    "$whmapi" set_tweaksetting key=apache_port value="0.0.0.0:8080" >/dev/null 2>&1 || \
        log WARN "Failed to update non-SSL Apache port via WHM"
    "$whmapi" set_tweaksetting key=apache_ssl_port value="0.0.0.0:8443" >/dev/null 2>&1 || \
        log WARN "Failed to update SSL Apache port via WHM"
}

configure_varnish_service() {
    log INFO "Configuring systemd override for Varnish"
    mkdir -p "$(dirname "$VARNISH_SERVICE_OVERRIDE")"
    backup_config "$VARNISH_SERVICE_OVERRIDE"

    cat > "$VARNISH_SERVICE_OVERRIDE" <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/varnishd -a 0.0.0.0:80 -a 127.0.0.1:4443,proxy \\
    -f $VARNISH_DEFAULT_VCL \\
    -s ${CACHE_STORAGE_VALUE} \\
    -p feature=+http2 \\
    -p http_req_hdr_len=65536 \\
    -p http_resp_hdr_len=65536 \\
    -p thread_pools=${THREAD_POOLS} \\
    -p thread_pool_min=${THREAD_MIN} \\
    -p thread_pool_max=${THREAD_MAX} \\
    -p idle_send_timeout=60s \\
    -p timeout_idle=60s
LimitNOFILE=131072
EOF
}

configure_varnish_params() {
    local params="/etc/varnish/varnish.params"
    mkdir -p "/etc/varnish"
    if [[ -f "$params" ]]; then
        backup_config "$params"
    fi

    cat > "$params" <<EOF
VARNISH_LISTEN_ADDRESS=0.0.0.0
VARNISH_LISTEN_PORT=80
VARNISH_ADMIN_LISTEN_ADDRESS=127.0.0.1
VARNISH_ADMIN_LISTEN_PORT=6082
VARNISH_STORAGE="${CACHE_STORAGE_VALUE}"
VARNISH_TTL=120
DAEMON_OPTS="-p default_ttl=120"
EOF
}

install_vcl() {
    local source_vcl
    source_vcl=$(get_asset_path "optimized-default.vcl")

    log INFO "Installing optimized VCL to $VARNISH_DEFAULT_VCL"
    mkdir -p "$(dirname "$VARNISH_DEFAULT_VCL")"
    backup_config "$VARNISH_DEFAULT_VCL"
    cp "$source_vcl" "$VARNISH_DEFAULT_VCL"
    chmod 0644 "$VARNISH_DEFAULT_VCL"

    if [[ -n "$SERVER_IP" && "$SERVER_IP" != "127.0.0.1" ]]; then
        if ! grep -q "$SERVER_IP" "$VARNISH_DEFAULT_VCL"; then
            sed -i "s/# Add your server IPs here/# Add your server IPs here\\n    \"${SERVER_IP}\";/" "$VARNISH_DEFAULT_VCL"
        fi
    fi
}

configure_hitch() {
    log INFO "Configuring Hitch TLS proxy"
    mkdir -p "$(dirname "$HITCH_CONF")"
    backup_config "$HITCH_CONF"

    local certs
    certs=$(awk '/SSLCertificate(File)?/ {print $2}' "$APACHE_CONF" | sort -u)

    cat > "$HITCH_CONF" <<EOF
frontend = "[*]:443"
backend = "[127.0.0.1]:4443"
workers = ${THREAD_POOLS}
daemon = on
user = "hitch"
group = "hitch"
write-proxy-v2 = on
ciphers = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
EOF

    local added=0
    while IFS= read -r cert; do
        [[ -z "$cert" ]] && continue
        if [[ -f "$cert" ]]; then
            echo "pem-file = \"$cert\"" >> "$HITCH_CONF"
            ((added++))
        else
            log WARN "Certificate path $cert referenced by Apache was not found"
        fi
    done <<< "$certs"

    echo "# pem-dir = \"/etc/pki/tls/private\"" >> "$HITCH_CONF"
    chmod 0640 "$HITCH_CONF"
    chown hitch:hitch "$HITCH_CONF" 2>/dev/null || true

    if (( added == 0 )); then
        log WARN "No certificates added to Hitch. Install certificates and run $INSTALL_BASE/update_hitch_certs.sh"
    fi
}

deploy_support_scripts() {
    log INFO "Deploying helper scripts to $INSTALL_BASE"
    mkdir -p "$INSTALL_BASE"
    local updater
    updater=$(get_asset_path "update_hitch_certs.sh")

    cp "$updater" "$INSTALL_BASE/update_hitch_certs.sh"
    chmod 0755 "$INSTALL_BASE/update_hitch_certs.sh"
}

deploy_whm_plugin() {
    if [[ ! -d "/usr/local/cpanel" ]]; then
        log WARN "cPanel not detected; skipping WHM Plugin deployment"
        return
    fi

    log INFO "Deploying WHM Varnish Cache Manager plugin"
    local manager_cgi
    local ajax_cgi
    manager_cgi=$(get_asset_path "whm_varnish_manager.cgi")
    ajax_cgi=$(get_asset_path "varnish_ajax.cgi")

    mkdir -p "$WHM_PLUGIN_DIR"
    cp "$manager_cgi" "$WHM_PLUGIN_DIR/whm_varnish_manager.cgi"
    cp "$ajax_cgi" "$WHM_PLUGIN_DIR/varnish_ajax.cgi"
    chmod 0755 "$WHM_PLUGIN_DIR/whm_varnish_manager.cgi" "$WHM_PLUGIN_DIR/varnish_ajax.cgi"

    mkdir -p "$(dirname "$APPCONFIG_FILE")"
    cat > "$APPCONFIG_FILE" <<EOF
name: varnish_cache_manager
displayname: Varnish Cache Manager
service: varnish
group: root
url: varnish/whm_varnish_manager.cgi
category: Server Configuration
feature: varnishcache
EOF

    if [[ -x /usr/local/cpanel/bin/register_appconfig ]]; then
        /usr/local/cpanel/bin/register_appconfig "$APPCONFIG_FILE" >/dev/null 2>&1 || \
            log WARN "Failed to register WHM AppConfig"
    else
        log WARN "register_appconfig not available; register the plugin manually"
    fi
}

validate_configs() {
    log INFO "Validating Apache configuration"
    if ! /usr/sbin/httpd -t >/dev/null 2>&1; then
        fatal "Apache configuration validation failed"
    fi

    log INFO "Validating VCL syntax"
    if ! /usr/sbin/varnishd -C -f "$VARNISH_DEFAULT_VCL" >/dev/null 2>&1; then
        fatal "Varnish VCL validation failed"
    fi
}

restart_services() {
    log INFO "Reloading systemd daemon state"
    systemctl daemon-reload

    log INFO "Restarting Apache on 8080/8443"
    systemctl enable httpd >/dev/null 2>&1 || true
    if [[ -x /scripts/restartsrv_httpd ]]; then
        /scripts/restartsrv_httpd >/dev/null 2>&1 || systemctl restart httpd
    else
        systemctl restart httpd
    fi

    ensure_port_free 80 "Varnish HTTP listener"
    ensure_port_free 443 "Hitch TLS listener"
    ensure_port_free 4443 "Varnish TLS backend listener"

    log INFO "Enabling and restarting Varnish"
    systemctl enable varnish >/dev/null 2>&1 || true
    systemctl restart varnish

    log INFO "Enabling and restarting Hitch"
    systemctl enable hitch >/dev/null 2>&1 || true
    systemctl restart hitch
}

perform_full_install() {
    detect_server_ip
    CACHE_STORAGE_VALUE="${CACHE_STORAGE_VALUE:-$(choose_cache_storage)}"
    log INFO "Selected cache storage: $CACHE_STORAGE_VALUE"

    ensure_package curl
    ensure_varnish_repo
    install_packages
    stop_conflicting_services
    configure_apache_ports
    update_whm_ports
    install_vcl
    configure_varnish_params
    configure_varnish_service
    configure_hitch
    deploy_support_scripts
    deploy_whm_plugin
    validate_configs
    restart_services

    log INFO "Installation complete. Access WHM → System → Varnish Cache Manager"
}

usage() {
    cat <<EOF
Usage: $0 [--auto|--full]

Rebuilds the Varnish/Hitch stack for cPanel/WHM based on the legacy installer.

Options:
  --auto, --full   Run the full installation without prompting
  -h, --help       Show this help message
EOF
}

main() {
    local auto_mode=0
    for arg in "$@"; do
        case "$arg" in
            --auto|--full)
                auto_mode=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                fatal "Unknown option: $arg"
                ;;
        esac
    done

    if [[ -t 0 && -t 1 && $auto_mode -eq 0 ]]; then
        echo
        read -r -p "Proceed with the full Varnish + Hitch installation? [y/N] " answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            log WARN "Installation cancelled by user"
            exit 0
        fi
    fi

    perform_full_install
}

main "$@"
