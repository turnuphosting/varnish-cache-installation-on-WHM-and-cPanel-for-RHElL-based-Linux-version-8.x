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

# Step 1: Install EPEL Repository
echo "Installing EPEL repository..."
dnf install -y epel-release

# Step 2: Install Varnish Cache from the specified repository
echo "Installing Varnish Cache from the specified repository..."
curl -s https://packagecloud.io/install/repositories/varnishcache/varnish70/script.rpm.sh | bash
dnf install -y varnish

# Step 3: Copy Varnish service file to /etc/systemd/system and modify it
echo "Copying Varnish service file and modifying it..."
cp /usr/lib/systemd/system/varnish.service /etc/systemd/system/
sed -i 's/-a :6081/-a :80/' /etc/systemd/system/varnish.service

# Step 4: Change the backend port to 8080
echo "Changing the backend port to 8080..."
sed -i 's/.port = "8080"/.port = "8443"/' /etc/varnish/default.vcl

# Step 5: Edit the Varnish backend configuration and replace 127.0.0.1 with the system's IP
echo "Updating Varnish backend configuration with the system's IP address..."
sed -i "s/127.0.0.1/$SYSTEM_IP/" /etc/varnish/default.vcl

# Step 6: Reload Systemd and Start Varnish
echo "Reloading Systemd and starting Varnish..."
systemctl daemon-reload
systemctl start varnish
systemctl enable varnish

# Step 7: Install Hitch
echo "Installing Hitch..."
dnf install -y hitch

# Step 8: Get SSL certificate locations from WHM and cPanel
echo "Extracting SSL certificate locations..."
SSL_CERTS=$(grep SSLCertificate /etc/apache2/conf/httpd.conf | awk '{print $2}' | sort -u)

# Step 9: Configure Hitch
echo "Configuring Hitch..."
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

# Step 10: Start and enable Hitch
echo "Starting and enabling Hitch..."
systemctl start hitch
systemctl enable hitch

# Step 11: Configure Apache to use port 8080
echo "Configuring Apache to use port 8080..."
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

# Step 12: Restart Apache
echo "Restarting Apache..."
systemctl restart httpd

echo "Varnish Cache and Hitch installation and configuration completed successfully."
