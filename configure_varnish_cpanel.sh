#!/bin/bash

# Script to configure Varnish with cPanel following the QualityUnit guide
# https://support.qualityunit.com/496090-How-to-install-Varnish-with-CPanel-and-CentOS-to-cache-static-content-on-server

# Exit on any error
set -e

echo "=== Varnish cPanel Configuration Script ==="
echo "Configuring Varnish to work with cPanel/WHM..."

# Function to get the system's primary IP address
get_server_ip() {
    # Try multiple methods to get the server's IP address
    local server_ip=""
    
    # Method 1: Try to get IP from hostname
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")
    
    # Method 2: If that fails, try ip command
    if [ -z "$server_ip" ]; then
        server_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo "")
    fi
    
    # Method 3: If that fails, try interface parsing
    if [ -z "$server_ip" ]; then
        server_ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n 1 2>/dev/null || echo "")
    fi
    
    # Method 4: Last resort - curl external service
    if [ -z "$server_ip" ]; then
        server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "")
    fi
    
    echo "$server_ip"
}

# Get the server's IP address
SERVER_IP=$(get_server_ip)

if [ -z "$SERVER_IP" ]; then
    echo "ERROR: Could not determine the server's IP address."
    echo "Please manually specify the IP address:"
    read -p "Enter server IP address: " SERVER_IP
    
    if [ -z "$SERVER_IP" ]; then
        echo "ERROR: No IP address provided. Exiting."
        exit 1
    fi
fi

echo "Detected server IP: $SERVER_IP"

# Backup original configuration files
echo "Creating backups of original configuration files..."
[ -f /etc/httpd/conf/httpd.conf ] && cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.backup.$(date +%Y%m%d_%H%M%S)
[ -f /etc/sysconfig/varnish ] && cp /etc/sysconfig/varnish /etc/sysconfig/varnish.backup.$(date +%Y%m%d_%H%M%S)
[ -f /etc/varnish/default.vcl ] && cp /etc/varnish/default.vcl /etc/varnish/default.vcl.backup.$(date +%Y%m%d_%H%M%S)

# Step 1: Configure Apache to listen on port 8080
echo "Step 1: Configuring Apache to listen on port 8080..."

# Check if httpd.conf exists
if [ ! -f /etc/httpd/conf/httpd.conf ]; then
    echo "ERROR: /etc/httpd/conf/httpd.conf not found. Make sure Apache is installed."
    exit 1
fi

# Update Listen directive in httpd.conf
if grep -q "^Listen 80$" /etc/httpd/conf/httpd.conf; then
    sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
    echo "✓ Changed Apache Listen directive from 80 to 8080"
elif grep -q "^Listen 8080$" /etc/httpd/conf/httpd.conf; then
    echo "✓ Apache is already configured to listen on port 8080"
else
    # Add Listen 8080 if no Listen directive found
    echo "Listen 8080" >> /etc/httpd/conf/httpd.conf
    echo "✓ Added Listen 8080 to Apache configuration"
fi

# Update any VirtualHost entries that might be using port 80
if grep -q "<VirtualHost \*:80>" /etc/httpd/conf/httpd.conf; then
    sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/g' /etc/httpd/conf/httpd.conf
    echo "✓ Updated VirtualHost entries to use port 8080"
fi

# Step 2: Configure Varnish to listen on port 80
echo "Step 2: Configuring Varnish to listen on port 80..."

# Check if /etc/sysconfig/varnish exists
if [ ! -f /etc/sysconfig/varnish ]; then
    echo "WARNING: /etc/sysconfig/varnish not found. Creating basic configuration..."
    cat > /etc/sysconfig/varnish <<EOF
# Configuration file for varnish
RELOAD_VCL=1
VARNISH_VCL_CONF=/etc/varnish/default.vcl
VARNISH_LISTEN_PORT=80
VARNISH_ADMIN_LISTEN_ADDRESS=127.0.0.1
VARNISH_ADMIN_LISTEN_PORT=6082
VARNISH_SECRET_FILE=/etc/varnish/secret
VARNISH_STORAGE="malloc,256m"
VARNISH_USER=varnish
VARNISH_TTL=120
EOF
else
    # Update existing configuration
    if grep -q "^VARNISH_LISTEN_PORT=" /etc/sysconfig/varnish; then
        sed -i 's/^VARNISH_LISTEN_PORT=.*/VARNISH_LISTEN_PORT=80/' /etc/sysconfig/varnish
        echo "✓ Updated VARNISH_LISTEN_PORT to 80"
    else
        echo "VARNISH_LISTEN_PORT=80" >> /etc/sysconfig/varnish
        echo "✓ Added VARNISH_LISTEN_PORT=80 to Varnish configuration"
    fi
fi

# Step 3: Configure Varnish default.vcl with server IP
echo "Step 3: Configuring Varnish VCL with server IP ($SERVER_IP)..."

# Check if default.vcl exists
if [ ! -f /etc/varnish/default.vcl ]; then
    echo "Creating /etc/varnish/default.vcl..."
    cat > /etc/varnish/default.vcl <<EOF
vcl 4.1;

backend default {
    .host = "$SERVER_IP";
    .port = "8080";
}

sub vcl_recv {
    if (req.url ~ "\.(png|gif|jpg|swf|css|js)$") {
        return(hash);
    }
}

# Strip the cookie before the image is inserted into cache
sub vcl_backend_response {
    if (bereq.url ~ "\.(png|gif|jpg|swf|css|js)$") {
        unset beresp.http.set-cookie;
    }
}
EOF
    echo "✓ Created new default.vcl with server IP $SERVER_IP"
else
    # Update existing backend configuration
    if grep -q "backend default" /etc/varnish/default.vcl; then
        # Update the host IP in the backend configuration
        sed -i "/backend default/,/}/ s/\.host = \"[^\"]*\"/\.host = \"$SERVER_IP\"/" /etc/varnish/default.vcl
        sed -i "/backend default/,/}/ s/\.port = \"[^\"]*\"/\.port = \"8080\"/" /etc/varnish/default.vcl
        echo "✓ Updated backend configuration with server IP $SERVER_IP and port 8080"
    else
        # Add backend configuration
        sed -i '1a\\nbackend default {\n    .host = "'$SERVER_IP'";\n    .port = "8080";\n}' /etc/varnish/default.vcl
        echo "✓ Added backend configuration with server IP $SERVER_IP and port 8080"
    fi
fi

# Step 4: Test configuration syntax
echo "Step 4: Testing configuration syntax..."

# Test Apache configuration
if httpd -t 2>/dev/null; then
    echo "✓ Apache configuration syntax is valid"
else
    echo "WARNING: Apache configuration syntax check failed. Please review manually."
fi

# Test Varnish configuration
if varnishd -C -f /etc/varnish/default.vcl >/dev/null 2>&1; then
    echo "✓ Varnish VCL configuration syntax is valid"
else
    echo "WARNING: Varnish VCL syntax check failed. Please review manually."
fi

# Step 5: Restart services
echo "Step 5: Restarting services..."

# Restart Apache
if systemctl restart httpd; then
    echo "✓ Apache restarted successfully"
else
    echo "ERROR: Failed to restart Apache"
    exit 1
fi

# Restart Varnish
if systemctl restart varnish; then
    echo "✓ Varnish restarted successfully"
else
    echo "ERROR: Failed to restart Varnish"
    exit 1
fi

# Enable services to start on boot
systemctl enable httpd varnish

echo ""
echo "=== Configuration Summary ==="
echo "✓ Apache configured to listen on port 8080"
echo "✓ Varnish configured to listen on port 80"
echo "✓ Varnish backend configured to use $SERVER_IP:8080"
echo "✓ Services restarted and enabled"
echo ""
echo "Configuration completed successfully!"
echo ""
echo "You can now:"
echo "1. Access your website through Varnish on port 80"
echo "2. Access Apache directly on port 8080"
echo "3. Monitor Varnish with: varnishstat"
echo "4. View Varnish logs with: varnishlog"
echo ""
echo "Note: Make sure your firewall allows traffic on ports 80 and 8080"