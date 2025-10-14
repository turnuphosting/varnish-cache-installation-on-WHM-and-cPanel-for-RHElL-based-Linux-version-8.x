#!/bin/bash

# Varnish cPanel Configuration Validator
# This script checks if Varnish and Apache are properly configured for cPanel

echo "=== Varnish cPanel Configuration Validator ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    
    if [ "$status" == "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" == "WARNING" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_status "ERROR" "This script must be run as root"
    exit 1
fi

echo "Checking Varnish and Apache configuration..."
echo

# 1. Check Apache configuration
echo "1. Apache Configuration:"
if [ -f /etc/httpd/conf/httpd.conf ]; then
    if grep -q "^Listen 8080$" /etc/httpd/conf/httpd.conf; then
        print_status "OK" "Apache is configured to listen on port 8080"
    else
        print_status "ERROR" "Apache is not configured to listen on port 8080"
    fi
    
    # Check if Apache is running on port 8080
    if netstat -tlnp 2>/dev/null | grep -q ":8080.*httpd" || ss -tlnp 2>/dev/null | grep -q ":8080.*httpd"; then
        print_status "OK" "Apache is running and listening on port 8080"
    else
        print_status "ERROR" "Apache is not running on port 8080"
    fi
else
    print_status "ERROR" "Apache configuration file not found"
fi
echo

# 2. Check Varnish configuration
echo "2. Varnish Configuration:"
if [ -f /etc/sysconfig/varnish ]; then
    if grep -q "^VARNISH_LISTEN_PORT=80" /etc/sysconfig/varnish; then
        print_status "OK" "Varnish is configured to listen on port 80"
    else
        print_status "ERROR" "VARNISH_LISTEN_PORT is not set to 80"
    fi
else
    print_status "WARNING" "/etc/sysconfig/varnish not found (might be using systemd service file)"
fi

# Check if Varnish is running on port 80
if netstat -tlnp 2>/dev/null | grep -q ":80.*varnishd" || ss -tlnp 2>/dev/null | grep -q ":80.*varnishd"; then
    print_status "OK" "Varnish is running and listening on port 80"
else
    print_status "ERROR" "Varnish is not running on port 80"
fi
echo

# 3. Check Varnish VCL configuration
echo "3. Varnish VCL Configuration:"
if [ -f /etc/varnish/default.vcl ]; then
    if grep -q "backend default" /etc/varnish/default.vcl; then
        backend_host=$(grep -A 5 "backend default" /etc/varnish/default.vcl | grep "\.host" | sed 's/.*"\(.*\)".*/\1/')
        backend_port=$(grep -A 5 "backend default" /etc/varnish/default.vcl | grep "\.port" | sed 's/.*"\(.*\)".*/\1/')
        
        if [ ! -z "$backend_host" ] && [ "$backend_port" == "8080" ]; then
            print_status "OK" "Backend configured with host: $backend_host, port: $backend_port"
            
            # Test if backend is reachable
            if curl -s --connect-timeout 5 "http://$backend_host:$backend_port" >/dev/null 2>&1; then
                print_status "OK" "Backend server is reachable"
            else
                print_status "WARNING" "Backend server may not be reachable"
            fi
        else
            print_status "ERROR" "Backend configuration is incomplete or incorrect"
        fi
    else
        print_status "ERROR" "No backend configuration found in VCL"
    fi
    
    # Test VCL syntax
    if varnishd -C -f /etc/varnish/default.vcl >/dev/null 2>&1; then
        print_status "OK" "VCL syntax is valid"
    else
        print_status "ERROR" "VCL syntax is invalid"
    fi
else
    print_status "ERROR" "Varnish VCL file not found"
fi
echo

# 4. Check service status
echo "4. Service Status:"
if systemctl is-active --quiet httpd; then
    print_status "OK" "Apache service is running"
else
    print_status "ERROR" "Apache service is not running"
fi

if systemctl is-active --quiet varnish; then
    print_status "OK" "Varnish service is running"
else
    print_status "ERROR" "Varnish service is not running"
fi
echo

# 5. Port usage summary
echo "5. Port Usage Summary:"
echo "Port 80 (should be Varnish):"
netstat -tlnp 2>/dev/null | grep ":80 " || ss -tlnp 2>/dev/null | grep ":80 "

echo "Port 8080 (should be Apache):"
netstat -tlnp 2>/dev/null | grep ":8080 " || ss -tlnp 2>/dev/null | grep ":8080 "
echo

# 6. Quick functional test
echo "6. Functional Test:"
echo "Testing Varnish response..."

# Get server IP for testing
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null)

if [ ! -z "$SERVER_IP" ]; then
    if curl -s -I "http://$SERVER_IP" | head -1 | grep -q "200\|301\|302"; then
        print_status "OK" "Varnish is responding to HTTP requests"
        
        # Check for Varnish headers
        if curl -s -I "http://$SERVER_IP" | grep -qi "via.*varnish\|x-varnish\|x-cache"; then
            print_status "OK" "Varnish headers detected in response"
        else
            print_status "WARNING" "No Varnish headers detected (might be configured to hide them)"
        fi
    else
        print_status "ERROR" "Varnish is not responding properly to HTTP requests"
    fi
else
    print_status "WARNING" "Could not determine server IP for testing"
fi

echo
echo "=== Configuration Check Complete ==="
echo
echo "If you see any errors above, please run the configuration script again:"
echo "sudo ./configure_varnish_cpanel.sh"