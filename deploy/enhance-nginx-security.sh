#!/usr/bin/env bash
# ==============================================================================
# Nginx 安全加固与性能调优脚本 (jiangxiai.top)
# 功能：
# 1. 开启 server_tokens off 隐藏 Nginx 与系统具体版本
# 2. 注入企业级安全响应头（X-Frame-Options, X-Content-Type-Options, Referrer-Policy）
# 3. 开启静态资源（CSS/JS/图片/字体）30 天强缓存，降低移动端加载耗时
# 4. 配置自定义 404 错误页路由 (/404.html)
# 5. 阻断外部直接访问 .sh / .bak / .log / .tar.gz 等敏感文件
# ==============================================================================
set -e

CONF_FILE="/etc/nginx/conf.d/jiangxiai.top.conf"

if [ ! -f "$CONF_FILE" ]; then
    CONF_FILE=$(find /etc/nginx/ -name "*jiangxiai*.conf" 2>/dev/null | head -n 1)
fi

if [ -z "$CONF_FILE" ] || [ ! -f "$CONF_FILE" ]; then
    echo "[-] 未在 /etc/nginx/ 中找到 jiangxiai 配置文件，请检查路径。"
    exit 1
fi

echo "[+] 找到配置文件: $CONF_FILE"
BACKUP_FILE="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONF_FILE" "$BACKUP_FILE"
echo "[+] 已安全备份至: $BACKUP_FILE"

python3 - << 'EOF' "$CONF_FILE"
import sys, re

conf_path = sys.argv[1]
with open(conf_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. 全局或 server 块增加 server_tokens off
if "server_tokens off;" not in content:
    # 插入到主 server 块顶部或首行
    content = re.sub(
        r'(server\s*\{[\s\n]*listen\s+443[^\n]*;)',
        r'\1\n    server_tokens off;',
        content,
        count=1
    )

# 2. 注入安全响应头
security_headers = """    # [安全防护] 防止点击劫持、MIME 嗅探与隐私保护
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
"""
if "X-Frame-Options" not in content:
    content = re.sub(
        r'(strict-transport-security[^\n]*;)',
        r'\1\n' + security_headers,
        content
    )

# 3. 静态资源长效缓存与 404 自定义错误页
enhancement_blocks = """
    # [用户体验] 自定义 404 错误页
    error_page 404 /404.html;
    location = /404.html {
        internal;
    }

    # [访问安全] 禁止直接请求敏感脚本与归档文件
    location ~* \.(sh|bak|log|tar\.gz)$ {
        deny all;
        return 404;
    }

    # [性能加速] 静态资源客户端 30 天强缓存 (CSS, JS, 图片, 字体)
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|webp|svg|woff2|woff|ttf)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
        access_log off;
        try_files $uri =404;
    }
"""

if "location = /404.html" not in content and "expires 30d;" not in content:
    # 在主 server 块的最后一个大括号前插入
    # 找到 server_name jiangxiai.top; 所在的那个 block
    pattern = r'(server\s*\{[^}]*?server_name\s+jiangxiai\.top;[\s\S]*?)(\n\})'
    match = re.search(pattern, content)
    if match:
        content = content[:match.end(1)] + enhancement_blocks + content[match.end(1):]
    else:
        # fallback 插入
        content = content.rstrip() + "\n"

with open(conf_path, "w", encoding="utf-8") as f:
    f.write(content)

print("[+] Nginx 配置文件语法加固已写入。")
EOF

echo "[+] 正在进行 Nginx 配置语法自检..."
if nginx -t; then
    echo "[+] 语法自检通过，正在热重载 Nginx..."
    nginx -s reload
    echo "[√] Nginx 安全响应头、静态缓存与 404 错误页配置生效成功！"
else
    echo "[-] 语法检查失败，正在紧急回滚..."
    cp "$BACKUP_FILE" "$CONF_FILE"
    nginx -s reload || true
    echo "[-] 已安全回滚至备份文件。"
    exit 1
fi
