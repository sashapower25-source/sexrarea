#!/bin/bash

# Простое обновление nginx конфигурации для админки
# Запускать с правами sudo

set -e

echo "🔧 Updating nginx configuration for admin panel..."

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

# Настройка прав доступа
echo -e "${YELLOW}📁 Setting up admin directory permissions...${NC}"
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

# Добавление админ API роута и админки
echo -e "${YELLOW}📝 Adding admin panel configuration...${NC}"

# Находим место для вставки конфигурации админки (перед # API endpoints)
sed -i '/# API endpoints with special CORS settings/i\    # Admin API endpoints - Proxy to Node.js\
    location /admin/api/ {\
        # Custom logging for admin API\
        access_log /var/log/nginx/aversbg.su.admin-api.log mytron_log;\
\
        # Rate limiting\
        limit_req zone=api_limit burst=10 nodelay;\
        limit_req_status 429;\
\
        # Admin API CORS headers\
        add_header Access-Control-Allow-Origin "https://aversbg.su" always;\
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;\
        add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With, Accept, Origin" always;\
        add_header Access-Control-Allow-Credentials "true" always;\
        add_header Access-Control-Max-Age 3600 always;\
\
        # Handle preflight requests\
        if ($request_method = OPTIONS) {\
            add_header Access-Control-Allow-Origin "https://aversbg.su";\
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";\
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With, Accept, Origin";\
            add_header Access-Control-Allow-Credentials "true";\
            add_header Access-Control-Max-Age 3600;\
            add_header Content-Length 0;\
            add_header Content-Type text/plain;\
            return 204;\
        }\
\
        # Proxy settings\
        proxy_pass http://mytron_backend;\
        proxy_http_version 1.1;\
        proxy_set_header Upgrade $http_upgrade;\
        proxy_set_header Connection "upgrade";\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
        proxy_set_header X-Forwarded-Host $host;\
\
        # Timeouts\
        proxy_connect_timeout 60s;\
        proxy_send_timeout 60s;\
        proxy_read_timeout 300s;\
\
        proxy_cache_bypass $http_upgrade;\
        proxy_buffering off;\
    }\
\
    # Admin Panel - Static Files\
    location /admin {\
        # Custom logging for admin panel\
        access_log /var/log/nginx/aversbg.su.admin.log mytron_log;\
\
        # Rate limiting for admin\
        limit_req zone=api_limit burst=15 nodelay;\
        limit_req_status 429;\
\
        # Admin panel security headers\
        add_header Content-Security-Policy "default-src '\''self'\''; script-src '\''self'\'' '\''unsafe-inline'\'' '\''unsafe-eval'\'' https://cdn.jsdelivr.net; style-src '\''self'\'' '\''unsafe-inline'\'' https://cdn.jsdelivr.net; img-src '\''self'\'' data: https:; font-src '\''self'\'' data: https://cdn.jsdelivr.net; connect-src '\''self'\'' https: wss:; frame-src '\''none'\'';" always;\
\
        # Serve static files from tronadmin directory\
        alias /var/www/tronadmin/;\
        index index.html index.htm;\
        try_files $uri $uri/ /admin/index.html;\
\
        # Enable caching for static assets\
        location ~* \\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {\
            expires 1y;\
            add_header Cache-Control "public, immutable";\
            add_header Vary Accept-Encoding;\
        }\
\
        # Disable caching for HTML files\
        location ~* \\.(html|htm)$ {\
            expires -1;\
            add_header Cache-Control "no-cache, no-store, must-revalidate";\
            add_header Pragma "no-cache";\
        }\
    }\
' "$NGINX_CONFIG"

echo -e "${GREEN}✅ Admin configuration added to nginx${NC}"

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

# Создание логов админки
touch /var/log/nginx/aversbg.su.admin.log
touch /var/log/nginx/aversbg.su.admin-api.log
chown www-data:adm /var/log/nginx/aversbg.su.admin*.log

echo -e "${GREEN}🎉 Admin panel configuration completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Summary:${NC}"
echo -e "• Admin panel: ${GREEN}https://aversbg.su/admin${NC}"
echo -e "• Admin API: ${GREEN}https://aversbg.su/admin/api/*${NC}"
echo -e "• Public API: ${GREEN}https://aversbg.su/api/*${NC}"
echo -e "• Static files: ${GREEN}/var/www/tronadmin${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Make sure your Node.js app uses /admin/api prefix for admin routes"
echo "2. Deploy admin panel files to /var/www/tronadmin"
echo "3. Test admin access: https://aversbg.su/admin"
echo "4. Test admin API: https://aversbg.su/admin/api/auth/profile"
