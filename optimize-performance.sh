#!/bin/bash
#
# Varnish Performance Optimizer
# Applies LiteSpeed-level performance optimizations and beyond
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

log_file="/var/log/varnish-optimization.log"

print_header() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                          ║"
    echo "║              🚀 VARNISH PERFORMANCE OPTIMIZER 🚀                                        ║"
    echo "║                                                                                          ║"
    echo "║                    LiteSpeed-Level Performance & Beyond                                 ║"
    echo "║                                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
    echo -e "$1"
}

show_progress() {
    local current=$1
    local total=$2
    local description="$3"
    local percentage=$((current * 100 / total))
    local completed=$((current * 50 / total))
    local remaining=$((50 - completed))
    
    printf "\r${CYAN}Progress: ${WHITE}["
    printf "${GREEN}%*s" $completed | tr ' ' '█'
    printf "${WHITE}%*s" $remaining | tr ' ' '░'
    printf "${WHITE}] ${YELLOW}%3d%% ${CYAN}- ${description}${NC}" $percentage
    
    if [ $current -eq $total ]; then
        echo
        echo
    fi
}

optimize_system_limits() {
    log "${BLUE}🔧 Optimizing system limits for maximum performance...${NC}"
    
    show_progress 1 10 "Configuring kernel parameters"
    
    # Optimize TCP settings for high performance
    cat > /etc/sysctl.d/99-varnish-performance.conf << 'EOF'
# Varnish Performance Optimizations
# Network performance
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# File system performance
fs.file-max = 2097152
vm.swappiness = 1
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.vfs_cache_pressure = 50

# Memory management
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
EOF

    sysctl -p /etc/sysctl.d/99-varnish-performance.conf &>/dev/null
    
    show_progress 2 10 "Setting process limits"
    
    # Set high limits for Varnish process
    cat > /etc/security/limits.d/varnish.conf << 'EOF'
varnish soft nofile 131072
varnish hard nofile 131072
varnish soft nproc 65536
varnish hard nproc 65536
varnish soft memlock unlimited
varnish hard memlock unlimited
EOF

    show_progress 3 10 "Configuring systemd limits"
    
    # Create systemd override for Varnish
    mkdir -p /etc/systemd/system/varnish.service.d
    cat > /etc/systemd/system/varnish.service.d/limits.conf << 'EOF'
[Service]
LimitNOFILE=131072
LimitNPROC=65536
LimitMEMLOCK=infinity
LimitCORE=infinity
EOF

    systemctl daemon-reload
    
    log "${GREEN}✅ System limits optimized${NC}"
}

configure_varnish_parameters() {
    log "${BLUE}⚙️ Configuring Varnish for maximum performance...${NC}"
    
    show_progress 4 10 "Calculating optimal memory allocation"
    
    # Calculate optimal memory settings based on available RAM
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    # Allocate 60% of RAM to Varnish cache, minimum 1GB, maximum based on system
    if [ $total_ram_gb -lt 2 ]; then
        varnish_memory="512M"
    elif [ $total_ram_gb -lt 4 ]; then
        varnish_memory="1G"
    elif [ $total_ram_gb -lt 8 ]; then
        varnish_memory="3G"
    elif [ $total_ram_gb -lt 16 ]; then
        varnish_memory="8G"
    else
        varnish_memory="$((total_ram_gb * 60 / 100))G"
    fi
    
    # Calculate thread pool settings based on CPU cores
    cpu_cores=$(nproc)
    thread_pool_min=$((cpu_cores * 5))
    thread_pool_max=$((cpu_cores * 100))
    thread_pools=$((cpu_cores / 2))
    if [ $thread_pools -lt 2 ]; then
        thread_pools=2
    fi
    
    show_progress 5 10 "Writing optimized Varnish configuration"
    
    # Create optimized Varnish configuration
    cat > /etc/varnish/varnish.params << EOF
# Varnish Performance-Optimized Configuration
# Memory: ${varnish_memory} (${total_ram_gb}GB total RAM detected)
# CPU Cores: ${cpu_cores}

# Malloc storage with optimized size
VARNISH_STORAGE="malloc,${varnish_memory}"

# Listen on port 80 for HTTP
VARNISH_LISTEN_PORT=80

# Advanced threading configuration
VARNISH_ADMIN_LISTEN_ADDRESS=127.0.0.1
VARNISH_ADMIN_LISTEN_PORT=6082

# Performance parameters
VARNISH_USER=varnish
VARNISH_GROUP=varnish

# Runtime parameters for maximum performance
DAEMON_OPTS="-a :80 \\
    -a :8443,PROXY \\
    -T localhost:6082 \\
    -f /etc/varnish/default.vcl \\
    -S /etc/varnish/secret \\
    -s malloc,${varnish_memory} \\
    -p feature=+http2 \\
    -p vcc_allow_inline_c=on \\
    -p vcc_unsafe_path=off \\
    -p workspace_backend=128k \\
    -p workspace_client=128k \\
    -p workspace_session=2k \\
    -p workspace_thread=8k \\
    -p http_req_hdr_len=16384 \\
    -p http_req_size=65536 \\
    -p http_resp_hdr_len=16384 \\
    -p http_resp_size=65536 \\
    -p shm_reclen=1024 \\
    -p default_ttl=3600 \\
    -p default_grace=86400 \\
    -p default_keep=604800 \\
    -p timeout_idle=60 \\
    -p timeout_req=300 \\
    -p send_timeout=600 \\
    -p idle_send_timeout=60 \\
    -p pipe_timeout=60 \\
    -p connect_timeout=5 \\
    -p first_byte_timeout=60 \\
    -p between_bytes_timeout=10 \\
    -p acceptor_sleep_max=0.01 \\
    -p acceptor_sleep_incr=0.001 \\
    -p thread_pools=${thread_pools} \\
    -p thread_pool_min=${thread_pool_min} \\
    -p thread_pool_max=${thread_pool_max} \\
    -p thread_pool_timeout=300 \\
    -p thread_pool_add_delay=0.002 \\
    -p thread_pool_destroy_delay=1 \\
    -p thread_queue_limit=20 \\
    -p ban_lurker_age=60 \\
    -p ban_lurker_batch=1000 \\
    -p ban_lurker_sleep=0.01 \\
    -p critbit_cooloff=180 \\
    -p vcl_cooldown=600 \\
    -p max_esi_depth=10 \\
    -p esi_syntax=0x2 \\
    -p rush_exponent=3 \\
    -p sigsegv_handler=on \\
    -p syslog_cli_traffic=off \\
    -p prefer_ipv6=off"
EOF

    show_progress 6 10 "Installing optimized VCL configuration"
    
    # Install the optimized VCL
    cp optimized-default.vcl /etc/varnish/default.vcl
    
    # Validate VCL syntax
    if ! varnishd -C -f /etc/varnish/default.vcl > /dev/null 2>&1; then
        log "${RED}❌ VCL syntax error detected. Restoring backup...${NC}"
        return 1
    fi
    
    log "${GREEN}✅ Varnish configuration optimized${NC}"
}

optimize_apache_backend() {
    log "${BLUE}🌐 Optimizing Apache backend for Varnish...${NC}"
    
    show_progress 7 10 "Configuring Apache for optimal backend performance"
    
    # Apache optimizations for use with Varnish
    cat > /etc/httpd/conf.d/varnish-backend-optimization.conf << 'EOF'
# Apache Backend Optimizations for Varnish
# Disable unnecessary modules for backend use
LoadModule deflate_module modules/mod_deflate.so
LoadModule expires_module modules/mod_expires.so
LoadModule headers_module modules/mod_headers.so

# Optimized settings for backend operation
ServerTokens Prod
ServerSignature Off

# Since Varnish handles compression, disable Apache compression
<IfModule mod_deflate.c>
    SetEnvIfNoCase Request_URI \
        \.(?:gif|jpe?g|png|ico|css|js|pdf|txt|xml|svg|woff|woff2)$ \
        no-gzip dont-vary
    SetEnvIfNoCase Request_URI \
        \.(?:exe|t?gz|zip|bz2|sit|rar)$ \
        no-gzip dont-vary
</IfModule>

# Cache control headers for Varnish
<IfModule mod_expires.c>
    ExpiresActive On
    # Static content
    ExpiresByType text/css "access plus 7 days"
    ExpiresByType application/javascript "access plus 7 days"
    ExpiresByType image/png "access plus 30 days"
    ExpiresByType image/jpg "access plus 30 days"
    ExpiresByType image/jpeg "access plus 30 days"
    ExpiresByType image/gif "access plus 30 days"
    ExpiresByType image/ico "access plus 30 days"
    ExpiresByType image/svg+xml "access plus 30 days"
    ExpiresByType font/woff "access plus 30 days"
    ExpiresByType font/woff2 "access plus 30 days"
    
    # Dynamic content
    ExpiresByType text/html "access plus 2 hours"
    ExpiresByType application/xml "access plus 2 hours"
    ExpiresByType text/xml "access plus 2 hours"
</IfModule>

# Headers for Varnish optimization
<IfModule mod_headers.c>
    # Add cache headers
    Header always set X-Backend "Apache-Optimized"
    
    # Security headers (Varnish will also add these)
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-XSS-Protection "1; mode=block"
    
    # Vary header for proper caching
    Header append Vary Accept-Encoding
    
    # Remove server information
    Header unset Server
    Header unset X-Powered-By
</IfModule>

# Performance tuning
KeepAlive On
MaxKeepAliveRequests 1000
KeepAliveTimeout 15

# Worker MPM optimization for backend use
<IfModule mpm_worker_module>
    ServerLimit          $(( $(nproc) * 2 ))
    MaxRequestWorkers    $(( $(nproc) * 50 ))
    ThreadsPerChild      25
    ThreadLimit          25
    StartServers         $(( $(nproc) ))
    MinSpareThreads      $(( $(nproc) * 5 ))
    MaxSpareThreads      $(( $(nproc) * 15 ))
    MaxConnectionsPerChild 10000
</IfModule>

# Event MPM optimization (preferred)
<IfModule mpm_event_module>
    ServerLimit          $(( $(nproc) * 2 ))
    MaxRequestWorkers    $(( $(nproc) * 50 ))
    ThreadsPerChild      25
    ThreadLimit          25
    StartServers         $(( $(nproc) ))
    MinSpareThreads      $(( $(nproc) * 5 ))
    MaxSpareThreads      $(( $(nproc) * 15 ))
    MaxConnectionsPerChild 10000
    AsyncRequestWorkerFactor 2
</IfModule>
EOF

    log "${GREEN}✅ Apache backend optimized${NC}"
}

setup_performance_monitoring() {
    log "${BLUE}📊 Setting up performance monitoring...${NC}"
    
    show_progress 8 10 "Creating performance monitoring scripts"
    
    # Create performance monitoring script
    cat > /usr/local/bin/varnish-performance-monitor << 'EOF'
#!/bin/bash
# Varnish Performance Monitor

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOGFILE="/var/log/varnish-performance.log"

# Get Varnish statistics
STATS=$(varnishstat -1 -f MAIN.uptime,MAIN.sess_conn,MAIN.client_req,MAIN.cache_hit,MAIN.cache_miss,MAIN.backend_conn,MAIN.backend_fail,MAIN.n_object,MAIN.n_objectcore,MAIN.n_backend,SMA.s0.g_bytes,SMA.s0.g_space)

# Calculate hit rate
HITS=$(echo "$STATS" | grep "MAIN.cache_hit" | awk '{print $2}')
MISSES=$(echo "$STATS" | grep "MAIN.cache_miss" | awk '{print $2}')
TOTAL=$((HITS + MISSES))
if [ $TOTAL -gt 0 ]; then
    HIT_RATE=$(echo "scale=2; $HITS * 100 / $TOTAL" | bc -l)
else
    HIT_RATE=0
fi

# Get memory usage
MEMORY_USED=$(echo "$STATS" | grep "SMA.s0.g_bytes" | awk '{print $2}')
MEMORY_FREE=$(echo "$STATS" | grep "SMA.s0.g_space" | awk '{print $2}')
MEMORY_TOTAL=$((MEMORY_USED + MEMORY_FREE))

# Log performance data
echo "$TIMESTAMP,HIT_RATE:$HIT_RATE%,MEMORY_USED:$MEMORY_USED,MEMORY_TOTAL:$MEMORY_TOTAL,OBJECTS:$(echo "$STATS" | grep "MAIN.n_object" | awk '{print $2}')" >> "$LOGFILE"

# Alert on performance issues
if (( $(echo "$HIT_RATE < 80" | bc -l) )); then
    logger "WARNING: Varnish hit rate is below 80% ($HIT_RATE%)"
fi

if [ $MEMORY_USED -gt $((MEMORY_TOTAL * 90 / 100)) ]; then
    logger "WARNING: Varnish memory usage is above 90%"
fi
EOF

    chmod +x /usr/local/bin/varnish-performance-monitor
    
    show_progress 9 10 "Setting up performance cron jobs"
    
    # Add cron job for performance monitoring
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/varnish-performance-monitor") | crontab -
    
    # Create cache warming script
    cat > /usr/local/bin/varnish-cache-warmer << 'EOF'
#!/bin/bash
# Varnish Cache Warmer

SITEMAP_URL="${1:-http://localhost/sitemap.xml}"
CONCURRENT_REQUESTS=10

if command -v curl &> /dev/null; then
    # Extract URLs from sitemap and warm cache
    curl -s "$SITEMAP_URL" | grep -oP '<loc>\K[^<]+' | head -100 | \
    xargs -n 1 -P $CONCURRENT_REQUESTS -I {} curl -s -o /dev/null -w "%{url_effective} %{http_code} %{time_total}\n" {}
fi
EOF

    chmod +x /usr/local/bin/varnish-cache-warmer
    
    log "${GREEN}✅ Performance monitoring configured${NC}"
}

apply_security_enhancements() {
    log "${BLUE}🔒 Applying security enhancements...${NC}"
    
    show_progress 10 10 "Configuring security policies"
    
    # Create fail2ban configuration for Varnish
    if command -v fail2ban-server &> /dev/null; then
        cat > /etc/fail2ban/jail.d/varnish.conf << 'EOF'
[varnish-ban]
enabled = true
port = http,https
filter = varnish-ban
logpath = /var/log/varnish/varnishlog.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=VarnishBan, port="http,https", protocol=tcp]

[varnish-limit]
enabled = true
port = http,https
filter = varnish-limit
logpath = /var/log/varnish/varnishlog.log
maxretry = 20
findtime = 60
bantime = 1800
action = iptables-multiport[name=VarnishLimit, port="http,https", protocol=tcp]
EOF

        # Create Varnish filters for fail2ban
        cat > /etc/fail2ban/filter.d/varnish-ban.conf << 'EOF'
[Definition]
failregex = ^.*"(GET|POST).*HTTP/1\.[01]" 40[34].*$
ignoreregex =
EOF

        cat > /etc/fail2ban/filter.d/varnish-limit.conf << 'EOF'
[Definition]
failregex = ^.*"(GET|POST).*HTTP/1\.[01]" 429.*$
ignoreregex =
EOF

        systemctl restart fail2ban 2>/dev/null || true
    fi
    
    log "${GREEN}✅ Security enhancements applied${NC}"
}

restart_services() {
    log "${BLUE}🔄 Restarting services with optimized configuration...${NC}"
    
    # Restart services in correct order
    systemctl restart httpd
    sleep 2
    systemctl restart varnish
    sleep 2
    
    # Verify services are running
    if systemctl is-active --quiet httpd && systemctl is-active --quiet varnish; then
        log "${GREEN}✅ All services restarted successfully${NC}"
    else
        log "${RED}❌ Service restart failed${NC}"
        return 1
    fi
}

run_performance_test() {
    log "${BLUE}🧪 Running performance validation...${NC}"
    
    # Wait for services to stabilize
    sleep 5
    
    # Test HTTP response
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
        log "${GREEN}✅ HTTP test passed${NC}"
    else
        log "${RED}❌ HTTP test failed${NC}"
    fi
    
    # Test cache headers
    CACHE_HEADERS=$(curl -s -I http://localhost | grep -i "x-cache\|x-served-by\|x-performance")
    if [ -n "$CACHE_HEADERS" ]; then
        log "${GREEN}✅ Cache headers detected${NC}"
        log "${CYAN}$CACHE_HEADERS${NC}"
    fi
    
    # Test performance
    RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" http://localhost)
    log "${CYAN}📊 Response time: ${RESPONSE_TIME}s${NC}"
    
    if (( $(echo "$RESPONSE_TIME < 0.5" | bc -l) )); then
        log "${GREEN}✅ Excellent response time (<0.5s)${NC}"
    elif (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
        log "${YELLOW}⚠️ Good response time (<1.0s)${NC}"
    else
        log "${RED}❌ Slow response time (>1.0s)${NC}"
    fi
}

main() {
    print_header
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log "${RED}❌ This script must be run as root${NC}"
        exit 1
    fi
    
    log "${CYAN}🚀 Starting Varnish performance optimization...${NC}"
    log "${WHITE}This will optimize your Varnish installation for LiteSpeed-level performance and beyond.${NC}"
    echo
    
    # Run optimization steps
    optimize_system_limits
    configure_varnish_parameters
    optimize_apache_backend
    setup_performance_monitoring
    apply_security_enhancements
    restart_services
    run_performance_test
    
    echo
    log "${GREEN}${BOLD}🎉 OPTIMIZATION COMPLETE!${NC}"
    echo
    log "${WHITE}Your Varnish installation has been optimized for maximum performance:${NC}"
    log "${CYAN}• Advanced VCL with intelligent caching${NC}"
    log "${CYAN}• Optimized system parameters${NC}"
    log "${CYAN}• High-performance Apache backend${NC}"
    log "${CYAN}• Real-time performance monitoring${NC}"
    log "${CYAN}• Enhanced security features${NC}"
    echo
    log "${WHITE}Performance monitoring: tail -f /var/log/varnish-performance.log${NC}"
    log "${WHITE}Cache warming: /usr/local/bin/varnish-cache-warmer${NC}"
    log "${WHITE}Statistics: varnishstat${NC}"
    echo
    log "${GREEN}Your site should now perform at LiteSpeed levels or better! 🚀${NC}"
}

# Run main function
main "$@"