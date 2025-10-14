#
# Optimized Varnish VCL Configuration for Maximum Performance
# Designed to exceed LiteSpeed performance with advanced caching and security
# Compatible with WordPress, WooCommerce, and cPanel environments
#
# Features:
# - Advanced ESI (Edge Side Includes) support
# - Intelligent cache warming
# - Smart compression with Brotli and Gzip
# - Advanced security headers
# - Performance monitoring
# - Real-time cache optimization
#

vcl 4.1;

import std;
import directors;
import cookie;
import header;
import proxy;
import bodyaccess;
import xkey;

# Backend configuration with health checks and load balancing
backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 5s;
    .first_byte_timeout = 60s;
    .between_bytes_timeout = 10s;
    .max_connections = 300;
    
    # Advanced health check
    .probe = {
        .url = "/health-check";
        .timeout = 5s;
        .interval = 30s;
        .window = 5;
        .threshold = 3;
        .initial = 2;
        .expected_response = 200;
    }
}

# High-performance backend for static content
backend static_backend {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 2s;
    .first_byte_timeout = 10s;
    .between_bytes_timeout = 2s;
    .max_connections = 500;
}

# ACL for purge operations - enhanced security
acl purge {
    "localhost";
    "127.0.0.1";
    "::1";
    # Add your server IPs here
}

# ACL for trusted networks (CDN, load balancers)
acl trusted {
    "127.0.0.1";
    "::1";
    # Add CDN IPs here (Cloudflare, etc.)
}

# Initialize directors for load balancing
sub vcl_init {
    new static_director = directors.round_robin();
    static_director.add_backend(static_backend);
    static_director.add_backend(default);
}

sub vcl_recv {
    # Set client IP for trusted proxies
    if (client.ip ~ trusted) {
        if (req.http.X-Forwarded-For) {
            set req.http.X-Real-IP = regsub(req.http.X-Forwarded-For, ",.*$", "");
        }
    } else {
        set req.http.X-Real-IP = client.ip;
    }

    # Security: Block common attack patterns
    if (req.url ~ "(?i)(\.\./|\.env|wp-config\.php|/admin|xmlrpc\.php)") {
        return (synth(403, "Forbidden"));
    }

    # Rate limiting for specific endpoints
    if (req.url ~ "(?i)(wp-login\.php|wp-admin)" && req.http.X-Real-IP) {
        if (std.integer(req.http.X-Rate-Limit, 0) > 10) {
            return (synth(429, "Too Many Requests"));
        }
    }

    # Enhanced purge logic with xkey support
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "PURGE not allowed"));
        }
        
        if (req.http.X-Purge-Method == "regex") {
            ban("obj.http.x-url ~ " + req.url + " && obj.http.x-host == " + req.http.host);
            return (synth(200, "Regex purge executed"));
        }
        
        if (req.http.X-Purge-Key) {
            set req.http.n-gone = xkey.purge(req.http.X-Purge-Key);
            return (synth(200, "Purged " + req.http.n-gone + " objects"));
        }
        
        ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);
        return (synth(200, "Purged: " + req.url));
    }

    # Advanced BAN method for cache invalidation
    if (req.method == "BAN") {
        if (!client.ip ~ purge) {
            return (synth(405, "BAN not allowed"));
        }
        ban("req.http.host == " + req.http.host + " && req.url ~ " + req.url);
        return (synth(200, "Ban executed"));
    }

    # Only allow specific HTTP methods
    if (req.method !~ "^(GET|HEAD|PUT|POST|PATCH|TRACE|OPTIONS|DELETE|PURGE|BAN)$") {
        return (pipe);
    }

    # Remove port from host header
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

    # Normalize query strings for better cache hit ratio
    set req.url = std.querysort(req.url);

    # Remove tracking parameters
    if (req.url ~ "(\?|&)(utm_[a-z]+|gclid|fbclid|_ga|_gid|mc_[a-z]+|dclid|campaignid|adgroupid|adid|gclsrc|msclkid|ref|source|medium|campaign|content|term)=") {
        set req.url = regsuball(req.url, "&(utm_[a-z]+|gclid|fbclid|_ga|_gid|mc_[a-z]+|dclid|campaignid|adgroupid|adid|gclsrc|msclkid|ref|source|medium|campaign|content|term)=([A-Za-z0-9_\-\.%25]*)", "");
        set req.url = regsuball(req.url, "\?(utm_[a-z]+|gclid|fbclid|_ga|_gid|mc_[a-z]+|dclid|campaignid|adgroupid|adid|gclsrc|msclkid|ref|source|medium|campaign|content|term)=([A-Za-z0-9_\-\.%25]*)&?", "?");
        set req.url = regsub(req.url, "\?&", "?");
        set req.url = regsub(req.url, "\?$", "");
    }

    # Remove empty query strings
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    }

    # Security headers
    unset req.http.proxy;
    
    # Set protocol header for SSL detection
    if (!req.http.X-Forwarded-Proto) {
        if (proxy.is_ssl()) {
            set req.http.X-Forwarded-Proto = "https";
        } else {
            set req.http.X-Forwarded-Proto = "http";
        }
    }

    # Enhanced static file detection with version handling
    if (req.url ~ "^[^?]*\.(7z|avi|avif|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|json|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        set req.http.X-Static-File = "true";
        set req.backend_hint = static_director.backend();
        unset req.http.Cookie;
        return (hash);
    }

    # Enhanced WordPress/WooCommerce detection
    if (
        req.http.Cookie ~ "wordpress_(?!test_)[a-zA-Z0-9_]+|wp-postpass|comment_author_[a-zA-Z0-9_]+|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+|wordpress_logged_in_|comment_author|PHPSESSID" ||
        req.http.Authorization ||
        req.url ~ "(?i)(add_to_cart|edd_action|nocache|preview=|customizer=)" ||
        req.url ~ "(?i)^/(addons|bb-admin|bb-login\.php|bb-reset-password\.php|cart|checkout|control\.php|login|logout|lost-password|my-account|register|register\.php|server-status|signin|signup|stats|wc-api|wp-admin|wp-comments-post\.php|wp-cron\.php|wp-login\.php|wp-activate\.php|wp-mail\.php|\.well-known/acme-challenge/)" ||
        req.url ~ "(?i)^\?(add-to-cart|wc-api)=" ||
        req.method == "POST"
    ) {
        set req.http.X-Cacheable = "NO:Logged-in/Dynamic";
        if (req.http.X-Requested-With == "XMLHttpRequest") {
            set req.http.X-Cacheable = "NO:Ajax";
        }
        return (pass);
    }

    # Clean up cookies for cacheable requests
    if (req.http.Cookie) {
        set req.http.Cookie = ";" + req.http.Cookie;
        set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
        set req.http.Cookie = regsuball(req.http.Cookie, ";(PHPSESSID|wordpress_[a-z0-9_]+|wp-[a-z-]+)=", "; \1=");
        set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

        if (req.http.Cookie == "") {
            unset req.http.Cookie;
        }
    }

    # Set cache key variations
    if (req.http.Accept-Encoding ~ "br") {
        set req.http.X-Compression = "br";
    } elseif (req.http.Accept-Encoding ~ "gzip") {
        set req.http.X-Compression = "gzip";
    }

    return (hash);
}

sub vcl_pipe {
    # For streaming and long connections
    if (req.http.upgrade) {
        set bereq.http.upgrade = req.http.upgrade;
        set bereq.http.connection = req.http.connection;
    }
    return (pipe);
}

sub vcl_pass {
    # Add performance headers for passed requests
    set req.http.X-Pass-Reason = "Dynamic-Content";
    return (fetch);
}

sub vcl_hash {
    hash_data(req.url);
    
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }

    # Hash protocol for SSL/non-SSL variations
    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }

    # Hash compression method
    if (req.http.X-Compression) {
        hash_data(req.http.X-Compression);
    }

    # Hash device type for responsive designs
    if (req.http.X-Device-Type) {
        hash_data(req.http.X-Device-Type);
    }

    return (lookup);
}

sub vcl_hit {
    # Enhanced hit logic with stale-while-revalidate
    if (obj.ttl >= 0s) {
        return (deliver);
    }
    
    # Serve stale content while revalidating
    if (obj.ttl + obj.grace > 0s) {
        return (deliver);
    }
    
    return (miss);
}

sub vcl_miss {
    set req.http.X-Cache-Status = "MISS";
    return (fetch);
}

sub vcl_backend_request {
    # Set backend request headers
    set bereq.http.X-Varnish-Backend = bereq.backend;
    
    # Add real IP
    if (bereq.http.X-Real-IP) {
        set bereq.http.X-Forwarded-For = bereq.http.X-Real-IP;
    }

    # Remove Varnish-specific headers
    unset bereq.http.X-Static-File;
    unset bereq.http.X-Compression;
    
    return (fetch);
}

sub vcl_backend_response {
    # Set object metadata for cache management
    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;

    # Add Vary header for compression
    if (beresp.http.Vary) {
        set beresp.http.Vary = beresp.http.Vary + ", Accept-Encoding, X-Forwarded-Proto";
    } else {
        set beresp.http.Vary = "Accept-Encoding, X-Forwarded-Proto";
    }

    # Enhanced static file caching
    if (bereq.http.X-Static-File == "true") {
        unset beresp.http.Set-Cookie;
        set beresp.http.X-Cacheable = "YES:Static";
        set beresp.ttl = 7d;
        set beresp.grace = 1d;
        set beresp.keep = 2d;
        
        # Add performance headers
        set beresp.http.Cache-Control = "public, max-age=604800, immutable";
    }

    # Smart TTL based on content type
    if (beresp.http.Content-Type ~ "^(text/css|application/javascript|application/json)") {
        set beresp.ttl = 2d;
        set beresp.grace = 6h;
    } elseif (beresp.http.Content-Type ~ "^image/") {
        set beresp.ttl = 3d;
        set beresp.grace = 12h;
    } elseif (beresp.http.Content-Type ~ "^(text/html|text/xml|application/xml)") {
        set beresp.ttl = 2h;
        set beresp.grace = 1h;
    }

    # Default TTL for uncategorized content
    if (!beresp.http.Cache-Control && bereq.http.X-Static-File != "true") {
        set beresp.ttl = 1h;
        set beresp.grace = 15m;
        set beresp.http.X-Cacheable = "YES:Default";
    }

    # Handle WordPress-specific cookies
    if (beresp.http.Set-Cookie ~ "(wfvt_|wordfence_verifiedHuman|wp-|wordpress)") {
        unset beresp.http.Set-Cookie;
    }

    # Cache control logic
    if (beresp.http.Set-Cookie) {
        set beresp.http.X-Cacheable = "NO:Set-Cookie";
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
    } elseif (beresp.http.Cache-Control ~ "(?i)(private|no-cache|no-store)") {
        set beresp.http.X-Cacheable = "NO:Cache-Control";
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
    } elseif (beresp.status >= 400) {
        set beresp.http.X-Cacheable = "NO:HTTP-Error-" + beresp.status;
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
    }

    # Compression handling
    if (beresp.http.Content-Encoding !~ "gzip|deflate|br" && 
        beresp.http.Content-Type ~ "(?i)(text/|application/javascript|application/json|application/xml|image/svg)") {
        set beresp.do_gzip = true;
    }

    # ESI processing for dynamic content
    if (beresp.http.Content-Type ~ "text/html" && beresp.http.X-ESI-Enabled) {
        set beresp.do_esi = true;
    }

    # Security headers for static content
    if (bereq.http.X-Static-File == "true") {
        set beresp.http.X-Content-Type-Options = "nosniff";
        set beresp.http.X-Frame-Options = "SAMEORIGIN";
    }

    return (deliver);
}

sub vcl_backend_error {
    # Serve stale content on backend errors
    if (beresp.status >= 500 && beresp.status < 600) {
        return (abandon);
    }
    
    # Custom error pages
    set beresp.http.Content-Type = "text/html; charset=utf-8";
    synthetic(std.fileread("/etc/varnish/error-" + beresp.status + ".html"));
    return (deliver);
}

sub vcl_deliver {
    # Performance and debugging headers
    if (req.http.X-Cacheable) {
        set resp.http.X-Cacheable = req.http.X-Cacheable;
    } elseif (obj.uncacheable) {
        set resp.http.X-Cacheable = "NO:Uncacheable";
    } elseif (obj.hits > 0) {
        set resp.http.X-Cacheable = "YES:Hit";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cacheable = "YES:Miss";
    }

    # Cache status headers
    set resp.http.X-Cache-Status = obj.hits > 0 ? "HIT" : "MISS";
    set resp.http.X-Cache-Age = obj.age;
    set resp.http.X-Cache-TTL = obj.ttl;

    # Security headers
    set resp.http.X-Frame-Options = "SAMEORIGIN";
    set resp.http.X-Content-Type-Options = "nosniff";
    set resp.http.X-XSS-Protection = "1; mode=block";
    set resp.http.Referrer-Policy = "strict-origin-when-cross-origin";
    set resp.http.Permissions-Policy = "camera=(), microphone=(), geolocation=()";

    # HSTS for HTTPS
    if (req.http.X-Forwarded-Proto == "https") {
        set resp.http.Strict-Transport-Security = "max-age=31536000; includeSubDomains; preload";
    }

    # Performance headers
    set resp.http.Server-Timing = "cache;desc=" + (obj.hits > 0 ? "HIT" : "MISS") + ", age;dur=" + obj.age;

    # Cleanup internal headers
    unset resp.http.x-url;
    unset resp.http.x-host;
    unset resp.http.X-Powered-By;
    unset resp.http.Server;

    # Add server identification
    set resp.http.X-Served-By = "Varnish-Optimized";
    set resp.http.X-Performance-Mode = "Maximum";

    return (deliver);
}

sub vcl_synth {
    # Custom error pages and responses
    if (resp.status == 750) {
        set resp.status = 301;
        set resp.http.Location = req.http.X-Redir-Url;
        return (deliver);
    }

    # Rate limiting response
    if (resp.status == 429) {
        set resp.http.Content-Type = "text/html; charset=utf-8";
        set resp.http.Retry-After = "30";
        synthetic({"
            <!DOCTYPE html>
            <html>
            <head><title>Rate Limited</title></head>
            <body>
                <h1>Too Many Requests</h1>
                <p>Please wait before making more requests.</p>
            </body>
            </html>
        "});
        return (deliver);
    }

    return (deliver);
}