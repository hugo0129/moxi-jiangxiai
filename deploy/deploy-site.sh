#!/usr/bin/env bash
# ==============================================================================
# 《智能实战笔记》服务端安全发布部署脚本 (deploy-site.sh)
# 存储位置：/root/jiangxi-deploy/deploy-site.sh
# 作用：
# 1. 安全解压 /root/jiangxi-deploy/site.tar.gz 到 /www/wwwroot/jiangxiai.top/
# 2. 自动清理 macOS AppleDouble (._*) 脏文件
# 3. 严格设置 Ubuntu Nginx 标准权限 (www-data:www-data, 目录 755, 文件 644)
# 4. 清理 Web 根目录可能残留的运维脚本 (如 fix-nginx-redirect.sh)
# 5. 自动触发百度 API 全量 URL 推送 (/root/push-baidu.sh)
# 核心原则：绝不覆写或触碰 /etc/nginx/ 基础配置，避免破坏 301 重定向与安全头！
# ==============================================================================
set -e

TAR_FILE="/root/jiangxi-deploy/site.tar.gz"
WEB_ROOT="/www/wwwroot/jiangxiai.top"

echo "[1/5] 检查待部署压缩包..."
if [ ! -f "$TAR_FILE" ]; then
    echo "[-] 错误: 未在 $TAR_FILE 找到发布包，请先上传 site.tar.gz！"
    exit 1
fi

echo "[2/5] 正在解压至生产目录: $WEB_ROOT ..."
tar -xzvf "$TAR_FILE" -C "$WEB_ROOT/"

echo "[3/5] 清理冗余元数据与脚本..."
find "$WEB_ROOT" -name "._*" -delete
rm -f "$WEB_ROOT/fix-nginx-redirect.sh"

echo "[4/5] 修正文件属主与权限 (www-data)..."
chown -R www-data:www-data "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} +
find "$WEB_ROOT" -type f -exec chmod 644 {} +

echo "[5/5] 触发百度搜索引擎 API 主动推送..."
if [ -x "/root/push-baidu.sh" ]; then
    /root/push-baidu.sh || true
else
    echo "[!] 提示: /root/push-baidu.sh 不存在或无执行权限，跳过推送。"
fi

echo "=========================================================="
echo " [√] 部署完成！站点已更新至最新静态版本并完成百度同步。"
echo "=========================================================="
