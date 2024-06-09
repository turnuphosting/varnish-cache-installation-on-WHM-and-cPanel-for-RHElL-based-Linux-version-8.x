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

# Step 4: Modify the Varnish service file to add proxy backend
echo "Modifying Varnish service file to add proxy backend..."
sed -i 's|ExecStart=/usr/sbin/varnishd -a :80 -f /etc/varnish/default.vcl -s malloc,256m|ExecStart=/usr/sbin/varnishd -a :80 -a 127.0.0.1:4443,proxy -f /etc/varnish/default.vcl -s malloc,256m|' /etc/systemd/system/varnish.service

# Step 5: Edit the Varnish backend configuration and replace 127.0.0.1 with the system's IP
echo "Updating Varnish backend configuration with the system's IP address..."
sed -i "s/127.0.0.1/$SYSTEM_IP/" /etc/varnish/default.vcl

# Step 6: Edit the default.vcl file to include additional configurations
echo "Editing /etc/varnish/default.vcl to include additional configurations..."

# Include import proxy; above backend default {
sed -i '/backend default {/i import proxy;' /etc/varnish/default.vcl

# Include ACL purge configuration above sub vcl_recv {
sed -i '/sub vcl_recv {/i \
# Add hostnames, IP addresses and subnets that are allowed to purge content\
acl purge {\
    "localhost";\
    "'$SYSTEM_IP'";\
    "127.0.0.1";\
    "::1";\
}\
' /etc/varnish/default.vcl

# Include other configuration files after sub vcl_recv {
sed -i '/sub vcl_recv {/a \
    # Happens before we check if we have this in cache already.\
    #\
    # Typically you clean up the request here, removing cookies you don't need,\
    # rewriting the request, etc.\
    # Remove empty query string parameters\
    # e.g.: www.example.com/index.html?\
    if (req.url ~ "\?$") {\
        set req.url = regsub(req.url, "\?$", "");\
    }\
    # Remove port number from host header\
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");\
    # Sorts query string parameters alphabetically for cache normalization purposes\
   # set req.url = std.querysort(req.url);\
    # Remove the proxy header to mitigate the httpoxy vulnerability\
    # See https://httpoxy.org/\
    unset req.http.proxy;\
    # Add X-Forwarded-Proto header when using https\
    if(!req.http.X-Forwarded-Proto) {\
        if (proxy.is_ssl()) {\
            set req.http.X-Forwarded-Proto = "https";\
        } else {\
            set req.http.X-Forwarded-Proto = "http";\
        }\
    }\
    # Purge logic to remove objects from the cache.\
    # Tailored to the Proxy Cache Purge WordPress plugin\
    # See https://wordpress.org/plugins/varnish-http-purge/\
    if(req.method == "PURGE") {\
        if(!client.ip ~ purge) {\
            return(synth(405,"PURGE not allowed for this IP address"));\
        }\
        if (req.http.X-Purge-Method == "regex") {\
            ban("obj.http.x-url ~ " + req.url + " && obj.http.x-host == " + req.http.host);\
            return(synth(200, "Purged"));\
        }\
        ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);\
        return(synth(200, "Purged"));\
    }\
    # Only handle relevant HTTP request methods\
    if (\
        req.method != "GET" &&\
        req.method != "HEAD" &&\
        req.method != "PUT" &&\
        req.method != "POST" &&\
        req.method != "PATCH" &&\
        req.method != "TRACE" &&\
        req.method != "OPTIONS" &&\
        req.method != "DELETE"\
    ) {\
        return (pipe);\
    }\
    # Remove tracking query string parameters used by analytics tools\
    if (req.url ~ "(\?|&)(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=") {\
        set req.url = regsuball(req.url, "&(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "");\
        set req.url = regsuball(req.url, "\?(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "?");\
        set req.url = regsub(req.url, "\?&", "?");\
        set req.url = regsub(req.url, "\?$", "");\
    }\
    # Only cache GET and HEAD requests\
    if (req.method != "GET" && req.method != "HEAD") {\
        set req.http.X-Cacheable = "NO:REQUEST-METHOD";\
        return(pass);\
    }\
    # Mark static files with the X-Static-File header, and remove any cookies\
    # X-Static-File is also used in vcl_backend_response to identify static files\
    if (req.url ~ "^[^?]*\.(7z|avi|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {\
        set req.http.X-Static-File = "true";\
        unset req.http.Cookie;\
        return(hash);\
    }\
    # No caching of special URLs, logged in users and some plugins\
    if (\
        req.http.Cookie ~ "wordpress_(?!test_)[a-zA-Z0-9_]+|wp-postpass|comment_author_[a-zA-Z0-9_]+|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+|wordpress_logged_in_|comment_author|PHPSESSID" ||\
        req.http.Authorization ||\
        req.url ~ "add_to_cart" ||\
        req.url ~ "edd_action" ||\
        req.url ~ "nocache" ||\
        req.url ~ "^/addons" ||\
        req.url ~ "^/bb-admin" ||\
        req.url ~ "^/bb-login.php" ||\
        req.url ~ "^/bb-reset-password.php" ||\
        req.url ~ "^/cart" ||\
        req.url ~ "^/checkout" ||\
        req.url ~ "^/control.php" ||\
        req.url ~ "^/login" ||\
        req.url ~ "^/logout" ||\
        req.url ~ "^/lost-password" ||\
        req.url ~ "^/my-account" ||\
        req.url ~ "^/product" ||\
        req.url ~ "^/register" ||\
        req.url ~ "^/register.php" ||\
        req.url ~ "^/server-status" ||\
        req.url ~ "^/signin" ||\
        req.url ~ "^/signup" ||\
        req.url ~ "^/stats" ||\
        req.url ~ "^/wc-api" ||\
        req.url ~ "^/wp-admin" ||\
        req.url ~ "^/wp-comments-post.php" ||\
        req.url ~ "^/wp-cron.php" ||\
        req.url ~ "^/wp-login.php" ||\
        req.url ~ "^/wp-activate.php" ||\
        req.url ~ "^/wp-mail.php" ||\
        req.url ~ "^/wp-login.php" ||\
        req.url ~ "^\?add-to-cart=" ||\
        req.url ~ "^\?wc-api=" ||\
        req.url ~ "^/preview=" ||\
        req.url ~ "^/\.well-known/acme-challenge/"\
    ) {\
             set req.http.X-Cacheable = "NO:Logged in/Got Sessions";\
             if(req.http.X-Requested-With == "XMLHttpRequest") {\
                     set req.http.X-Cacheable = "NO:Ajax";\
             }\
        return(pass);\
    }\
    # Remove any cookies left\
    unset req.http.Cookie;\
    return(hash);\
' /etc/varnish/default.vcl

# Include hash variations based on X-Forwarded-Proto after sub vcl_hash {
sed -i '/sub vcl_hash {/a \
if(req.http.X-Forwarded-Proto) {\
    # Create cache variations depending on the request protocol\
    hash_data(req.http.X-Forwarded-Proto);\
}\
' /etc/varnish/default.vcl

# Include backend response configuration after sub vcl_backend_response {
sed -i '/sub vcl_backend_response {/a \
# Happens after we have read the response headers from the backend.\
# Here you clean the response headers, removing silly Set-Cookie headers\
# and other mistakes your backend does.\
if(beresp.http.Vary) {\
    set beresp.http.Vary = beresp.http.Vary + ", X-Forwarded-Proto";\
} else {\
    set beresp.http.Vary = "X-Forwarded-Proto";\
}\
# Inject URL & Host header into the object for asynchronous banning purposes\
set beresp.http.x-url = bereq.url;\
set beresp.http.x-host = bereq.http.host;\
# If we dont get a Cache-Control header from the backend\
# we default to 1h cache for all objects\
if (!beresp.http.Cache-Control) {\
    set beresp.ttl = 1h;\
    set beresp.http.X-Cacheable = "YES:Forced";\
}\
# If the file is marked as static we cache it for 1 day\
if (bereq.http.X-Static-File == "true") {\
    unset beresp.http.Set-Cookie;\
    set beresp.http.X-Cacheable = "YES:Forced";\
    set beresp.ttl = 1d;\
}\
# Remove the Set-Cookie header when a specific Wordfence cookie is set\
if (beresp.http.Set-Cookie ~ "wfvt_|wordfence_verifiedHuman") {\
    unset beresp.http.Set-Cookie;\
}\
if (beresp.http.Set-Cookie) {\
    set beresp.http.X-Cacheable = "NO:Got Cookies";\
} elseif(beresp.http.Cache-Control ~ "private") {\
    set beresp.http.X-Cacheable = "NO:Cache-Control=private";\
}\
' /etc/varnish/default.vcl

# Include deliver configuration after sub vcl_deliver {
sed -i '/sub vcl_deliver {/a \
# Happens when we have all the pieces we need, and are about to send the\
# response to the client.\
# You can do accounting or modifying the final object here.\
# Debug header\
if(req.http.X-Cacheable) {\
    set resp.http.X-Cacheable = req.http.X-Cacheable;\
} elseif(obj.uncacheable) {\
    if(!resp.http.X-Cacheable) {\
        set resp.http.X-Cacheable = "NO:UNCACHEABLE";\
    }\
} elseif(!resp.http.X-Cacheable) {\
    set resp.http.X-Cacheable = "YES";\
}\
# Cleanup of headers\
unset resp.http.x-url;\
unset resp.http.x-host;\
' /etc/varnish/default.vcl

# Step 7: Reload Systemd and Start Varnish
echo "Reloading Systemd and starting Varnish..."
systemctl daemon-reload
systemctl start varnish
systemctl enable varnish

# Step 8: Install Hitch
echo "Installing Hitch..."
dnf install -y hitch

# Step 9: Get SSL certificate locations from WHM and cPanel
echo "Extracting SSL certificate locations..."
SSL_CERTS=$(grep SSLCertificate /etc/apache2/conf/httpd.conf | awk '{print $2}' | sort -u)

# Step 10: Configure Hitch
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

# Step 11: Start and enable Hitch
echo "Starting and enabling Hitch..."
systemctl start hitch
systemctl enable hitch


# Step 12: Restart Apache
echo "Restarting Apache..."
systemctl restart httpd

echo "Varnish Cache and Hitch installation and configuration completed successfully."
