#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "  江西 AI 圈 (jiangxiai.top) 部署与 HTTPS 配置"
echo "========================================="

# 1. 检查必要文件
KEY="/etc/nginx/ssl/jiangxiai.top/www.jiangxiai.top.key"
PEM="/etc/nginx/ssl/jiangxiai.top/www.jiangxiai.top.pem"
PKG="$HOME/jiangxi-deploy/site.tar.gz"

if [[ ! -f "$KEY" || ! -f "$PEM" ]]; then
  echo "❌ 错误: 证书或私钥不存在于 /etc/nginx/ssl/jiangxiai.top/"
  exit 1
fi

if [[ ! -f "$PKG" ]]; then
  if [[ -f "./site.tar.gz" ]]; then
    PKG="./site.tar.gz"
  else
    echo "❌ 错误: 未找到 site.tar.gz 网站包"
    exit 1
  fi
fi

# 2. 设置证书权限
echo "[1/4] 设置证书文件权限..."
chmod 600 "$KEY"
chmod 644 "$PEM"

# 3. 备份旧网站并解压新网站
echo "[2/4] 备份旧网站并解压最新网站包..."
mkdir -p /var/backups/jiangxi-old
if [[ -d "/www/wwwroot/jiangxiai.top" ]]; then
  cp -r /www/wwwroot/jiangxiai.top "/var/backups/jiangxi-old/site-$(date +%Y%m%d%H%M%S)"
else
  mkdir -p /www/wwwroot/jiangxiai.top
fi

tar -xzf "$PKG" -C /www/wwwroot/jiangxiai.top/
rm -f /www/wwwroot/jiangxiai.top/services.html /www/wwwroot/jiangxiai.top/news.html
chown -R www-data:www-data /www/wwwroot/jiangxiai.top
find /www/wwwroot/jiangxiai.top -type d -exec chmod 755 {} +
find /www/wwwroot/jiangxiai.top -type f -exec chmod 644 {} +

# 4. 备份并写入 Nginx 配置
echo "[3/4] 写入 Nginx HTTPS 生产配置..."
mkdir -p /etc/nginx/conf.d
if [[ -f "/etc/nginx/conf.d/jiangxiai.top.conf" ]]; then
  cp /etc/nginx/conf.d/jiangxiai.top.conf "/etc/nginx/conf.d/jiangxiai.top.conf.bak-$(date +%Y%m%d%H%M%S)"
fi

cat > /etc/nginx/conf.d/jiangxiai.top.conf << 'NGINX_CONF'
# ---------- 80 端口：强制跳转 HTTPS ----------
server {
    listen 80;
    listen [::]:80;
    server_name jiangxiai.top www.jiangxiai.top;

    location /.well-known/acme-challenge/ {
        root /www/wwwroot/jiangxiai.top;
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# ---------- 443 端口：HTTPS 主站 ----------
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name jiangxiai.top www.jiangxiai.top;

    root /www/wwwroot/jiangxiai.top;
    index index.html;

    # SSL 证书配置
    ssl_certificate     /etc/nginx/ssl/jiangxiai.top/www.jiangxiai.top.pem;
    ssl_certificate_key /etc/nginx/ssl/jiangxiai.top/www.jiangxiai.top.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;

    # 安全响应头
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip 压缩优化
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/javascript application/json application/xml
               image/svg+xml font/woff font/woff2;

    # HTML 网页不强缓存
    location ~* \.html$ {
        add_header Cache-Control "no-cache" always;
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    }

    # CSS / JS 静态资源长缓存
    location ~* \.(css|js|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable" always;
    }

    # 图片长缓存
    location ~* \.(webp|jpg|jpeg|png|gif|ico|svg)$ {
        expires 90d;
        add_header Cache-Control "public" always;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
    }

    # 404 错误页
    error_page 404 /404.html;
    location = /404.html {
        internal;
    }

    # 默认请求处理
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX_CONF

# 5. 测试并重载
echo "[4/4] 检查 Nginx 配置并重载服务..."
nginx -t
nginx -s reload

echo "========================================="
echo "🎉 部署成功！"
echo "请在浏览器访问: https://jiangxiai.top"
echo "========================================="
