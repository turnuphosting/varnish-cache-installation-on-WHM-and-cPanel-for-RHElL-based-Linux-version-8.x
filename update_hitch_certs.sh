#!/bin/bash

# Exit on any error
set -e

# Function to get the system's IP address
get_ip() {
    ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n 1
}

# Get the system's IP address
SYSTEM_IP=$(get_ip)

if [ -z "$SYSTEM_IP" ]; then
    echo "Could not determine the system's IP address."
    exit 1
fi

# Extract SSL certificate locations from WHM and cPanel
echo "Extracting SSL certificate locations..."
SSL_CERTS=$(grep SSLCertificate /etc/apache2/conf/httpd.conf | awk '{print $2}' | sort -u)

# Preserve the essential Hitch configuration and append SSL certificate paths
echo "Updating Hitch configuration..."
cat > /etc/hitch/hitch.conf <<EOL
frontend = "[*]:443"
backend = "[127.0.0.1]:4443"
workers = 4
daemon = on
user = "hitch"
group = "hitch"
write-proxy-v2 = on
ciphers = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
EOL

# Add the SSL certificates to the Hitch configuration
for CERT in $SSL_CERTS; do
    echo "pem-file = \"$CERT\"" >> /etc/hitch/hitch.conf
done

# Comment out pem-dir
echo "# pem-dir = \"/etc/pki/tls/private\"" >> /etc/hitch/hitch.conf

# Restart Hitch to apply the changes
echo "Restarting Hitch..."
systemctl restart hitch

echo "Hitch configuration updated with SSL certificates."
