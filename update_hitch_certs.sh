#!/bin/bash

# Exit on any error
set -e

# Log file for troubleshooting
LOG_FILE="/var/log/update_hitch_certs.log"

# Log a message
log_message() {
    echo "$(date): $1" >> $LOG_FILE
}

log_message "Starting update_hitch_certs.sh script."

# Get SSL certificate locations from WHM and cPanel
log_message "Extracting SSL certificate locations..."
SSL_CERTS=$(grep SSLCertificate /etc/apache2/conf/httpd.conf | awk '{print $2}' | sort -u)

if [ -z "$SSL_CERTS" ]; then
    log_message "No SSL certificates found."
    exit 1
fi

# Write the static part of the configuration to hitch.conf
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

log_message "Written static configuration to /etc/hitch/hitch.conf."

# Add the SSL certificates to the Hitch configuration
for CERT in $SSL_CERTS; do
    if [ -f "$CERT" ]; then
        echo "pem-file = \"$CERT\"" >> /etc/hitch/hitch.conf
        log_message "Added certificate $CERT to hitch.conf."
    else
        log_message "Certificate $CERT not found."
    fi
done

# Comment out pem-dir
echo "# pem-dir = \"/etc/pki/tls/private\"" >> /etc/hitch/hitch.conf
log_message "Appended pem-dir comment to hitch.conf."

# Restart Hitch to apply changes
systemctl restart hitch
log_message "Hitch restarted to apply new configuration."

log_message "update_hitch_certs.sh script completed."
