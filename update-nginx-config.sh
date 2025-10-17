#!/bin/bash

# Скрипт для обновления конфигурации nginx с поддержкой админки
# Запускать с правами sudo

set -e

echo "🔧 Updating nginx configuration for MYTRON with Admin Panel..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run this script with sudo${NC}"
    exit 1
fi

# Проверка существования директории админки
ADMIN_DIR="/var/www/tronadmin"
if [ ! -d "$ADMIN_DIR" ]; then
    echo -e "${RED}❌ Admin directory not found: $ADMIN_DIR${NC}"
    echo "Please make sure the admin panel is deployed to /var/www/tronadmin"
    exit 1
fi

# Проверка владельца директории админки
echo -e "${YELLOW}📁 Checking admin directory permissions...${NC}"
chown -R www-data:www-data "$ADMIN_DIR"
chmod -R 755 "$ADMIN_DIR"
echo -e "${GREEN}✅ Admin directory permissions updated${NC}"

# Бэкап текущей конфигурации
NGINX_CONFIG="/etc/nginx/sites-available/aversbg.su"
BACKUP_CONFIG="/etc/nginx/sites-available/aversbg.su.backup.$(date +%Y%m%d_%H%M%S)"

if [ -f "$NGINX_CONFIG" ]; then
    echo -e "${YELLOW}📋 Creating backup of current configuration...${NC}"
    cp "$NGINX_CONFIG" "$BACKUP_CONFIG"
    echo -e "${GREEN}✅ Backup created: $BACKUP_CONFIG${NC}"
fi

# Копирование новой конфигурации
echo -e "${YELLOW}📝 Installing new nginx configuration...${NC}"

cat > "$NGINX_CONFIG" << 'EOF'
# Nginx configuration for MYTRON API server with Admin Panel
# File: /etc/nginx/sites-available/aversbg.su

# Log format with additional info (must be in http context)
log_format mytron_log '$remote_addr - $remote_user [$time_local] "$request" '
                     '$status $body_bytes_sent "$http_referer" '
                     '"$http_user_agent" "$http_x_forwarded_for" '
                     'rt=$request_time uct="$upstream_connect_time" '
                     'uht="$upstream_header_time" urt="$upstream_response_time"';

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=30r/m;
limit_req_zone $binary_remote_addr zone=admin_limit:10m rate=20r/m;
limit_req_zone $binary_remote_addr zone=sse_limit:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=general_limit:10m rate=100r/m;

# Upstream for MYTRON Node.js application
upstream mytron_backend {
    server [::1]:3000 max_fails=3 fail_timeout=30s;  # IPv6 localhost
    server 127.0.0.1:3000 max_fails=3 fail_timeout=30s backup;  # IPv4 fallback
    keepalive 32;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name aversbg.su www.aversbg.su;

    # Security headers even for redirects
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;

    # Redirect all HTTP requests to HTTPS
    return 301 https://$server_name$request_uri;
}

# Main HTTPS server
server {
    listen 443 ssl;
    server_name aversbg.su www.aversbg.su;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/aversbg.su/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/aversbg.su/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/aversbg.su/fullchain.pem;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Basic settings
    client_max_body_size 10M;
    client_header_timeout 60s;
    client_body_timeout 60s;
    send_timeout 60s;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;

    # Admin Panel - Static Files
    location /admin {
        # Custom logging for admin panel
        access_log /var/log/nginx/aversbg.su.admin.log mytron_log;

        # Rate limiting for admin
        limit_req zone=admin_limit burst=15 nodelay;
        limit_req_status 429;

        # Admin panel security headers
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net https://code.jquery.com https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com; img-src 'self' data: https:; font-src 'self' data: https://cdn.jsdelivr.net https://cdnjs.cloudflare.com; connect-src 'self' https: wss:; frame-src 'none';" always;

        # Try files first, then fallback to Node.js backend for /admin API routes
        try_files $uri $uri/ @admin_backend;

        # Serve static files from tronadmin directory
        root /var/www;
        index index.html index.htm;

        # Enable caching for static assets
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            add_header Vary Accept-Encoding;
        }

        # Disable caching for HTML files
        location ~* \.(html|htm)$ {
            expires -1;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
        }
    }

    # Admin API endpoints - Proxy to Node.js
    location @admin_backend {
        # Custom logging for admin API
        access_log /var/log/nginx/aversbg.su.admin-api.log mytron_log;

        # Rate limiting
        limit_req zone=admin_limit burst=10 nodelay;
        limit_req_status 429;

        # Admin API CORS headers (more restrictive)
        add_header Access-Control-Allow-Origin "https://aversbg.su" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With, Accept, Origin" always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Max-Age 3600 always;

        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin "https://aversbg.su";
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With, Accept, Origin";
            add_header Access-Control-Allow-Credentials "true";
            add_header Access-Control-Max-Age 3600;
            add_header Content-Length 0;
            add_header Content-Type text/plain;
            return 204;
        }

        # Proxy settings
        proxy_pass http://mytron_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 300s;  # 5 minutes for admin operations

        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
    }

    # API endpoints with special CORS settings (keep for redotpay-check.com)
    location /api/ {
        # Custom logging for API
        access_log /var/log/nginx/aversbg.su.api.log mytron_log;

        # Rate limiting
        limit_req zone=api_limit burst=10 nodelay;
        limit_req_status 429;

        # CORS заголовки для API (более открытые для клиентов)
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With, Accept, Origin, X-Forwarded-For, X-Forwarded-Host, X-Real-IP, X-Original-URI, X-Original-Method" always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Max-Age 3600 always;

        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin "*";
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With, Accept, Origin, X-Forwarded-For, X-Forwarded-Host, X-Real-IP, X-Original-URI, X-Original-Method";
            add_header Access-Control-Allow-Credentials "true";
            add_header Access-Control-Max-Age 3600;
            add_header Content-Length 0;
            add_header Content-Type text/plain;
            return 204;
        }

        # Proxy settings
        proxy_pass http://mytron_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Проброс прокси заголовков
        proxy_set_header X-Original-URI $http_x_original_uri;
        proxy_set_header X-Original-Method $http_x_original_method;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 3600s;  # Увеличено для SSE

        # Настройки для SSE
        proxy_cache_bypass $http_upgrade;
        proxy_no_cache $http_upgrade;
        proxy_buffering off;  # Отключаем буферизацию для SSE
        proxy_cache off;
    }

    # Test endpoints
    location /test/ {
        # Custom logging for test endpoints
        access_log /var/log/nginx/aversbg.su.test.log mytron_log;

        # Rate limiting
        limit_req zone=general_limit burst=20 nodelay;
        limit_req_status 429;

        # CORS headers for test endpoints
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With, Accept, Origin" always;
        add_header Access-Control-Max-Age 3600 always;

        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin "*";
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With, Accept, Origin";
            add_header Access-Control-Max-Age 3600;
            add_header Content-Length 0;
            add_header Content-Type text/plain;
            return 204;
        }

        # Proxy settings
        proxy_pass http://mytron_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
    }

    # Root endpoint - handles everything else
    location / {
        # Basic rate limiting
        limit_req zone=general_limit burst=20 nodelay;

        # Proxy to Node.js application
        proxy_pass http://mytron_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;

        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Security: Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~ \.(env|config|ini|log|bak|backup|sql|git)$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Block common exploit attempts (admin removed from blocked list)
    location ~* (wp-admin|wp-login|phpmyadmin|administrator|manager|mysql) {
        return 444;
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;

    # Custom error pages
    location = /404.html {
        internal;
        return 404 '{"error": "Not Found", "message": "The requested resource was not found"}';
        add_header Content-Type application/json;
    }

    location = /50x.html {
        internal;
        return 500 '{"error": "Internal Server Error", "message": "The server encountered an internal error"}';
        add_header Content-Type application/json;
    }

    # Logging
    access_log /var/log/nginx/aversbg.su.access.log combined;
    error_log /var/log/nginx/aversbg.su.error.log warn;
}

# Additional security server block (catch-all)
server {
    listen 443 ssl default_server;
    server_name _;

    # Use same SSL certificates
    ssl_certificate /etc/letsencrypt/live/aversbg.su/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/aversbg.su/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Return 444 for unknown hosts
    return 444;
}
EOF

echo -e "${GREEN}✅ New nginx configuration installed${NC}"

# Проверка синтаксиса nginx
echo -e "${YELLOW}🔍 Testing nginx configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ Nginx configuration test passed${NC}"
    
    # Перезагрузка nginx
    echo -e "${YELLOW}🔄 Reloading nginx...${NC}"
    systemctl reload nginx
    echo -e "${GREEN}✅ Nginx reloaded successfully${NC}"
    
    # Проверка статуса
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✅ Nginx is running${NC}"
    else
        echo -e "${RED}❌ Nginx is not running${NC}"
        systemctl status nginx
    fi
    
else
    echo -e "${RED}❌ Nginx configuration test failed${NC}"
    echo -e "${YELLOW}📋 Restoring backup configuration...${NC}"
    cp "$BACKUP_CONFIG" "$NGINX_CONFIG"
    echo -e "${GREEN}✅ Backup configuration restored${NC}"
    exit 1
fi

# Создание директории для логов админки если не существует
mkdir -p /var/log/nginx
touch /var/log/nginx/aversbg.su.admin.log
touch /var/log/nginx/aversbg.su.admin-api.log
chown www-data:adm /var/log/nginx/aversbg.su.admin*.log

echo -e "${GREEN}🎉 Configuration update completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Summary:${NC}"
echo -e "• Admin panel: ${GREEN}https://aversbg.su/admin${NC}"
echo -e "• API endpoints: ${GREEN}https://aversbg.su/api/*${NC}"
echo -e "• Admin API: ${GREEN}https://aversbg.su/admin/*${NC} (proxied to Node.js)"
echo -e "• Static files: ${GREEN}/var/www/tronadmin${NC}"
echo -e "• Admin logs: ${GREEN}/var/log/nginx/aversbg.su.admin*.log${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Deploy your admin panel files to /var/www/tronadmin"
echo "2. Ensure your Node.js app handles /admin/* API routes"
echo "3. Test admin panel access: https://aversbg.su/admin"
echo "4. Monitor logs: sudo tail -f /var/log/nginx/aversbg.su.admin.log"
