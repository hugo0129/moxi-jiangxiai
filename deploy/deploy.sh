#!/bin/bash
# jiangxiai.top 部署脚本
# 在阿里云 ECS 上运行，从 GitHub 拉取最新代码并部署到 Nginx 目录
#
# 用法:
#   chmod +x deploy.sh
#   ./deploy.sh
#
# 首次使用前:
#   1. 确保 git 已配置 SSH key
#   2. 确保 Nginx 已安装并配置好 nginx.conf
#   3. 修改下面的变量以匹配你的环境

set -e

# ---------- 配置 ----------
GIT_REPO="git@github.com:hugo0129/hugo0129.github.io.git"
DEPLOY_DIR="/var/www/jiangxiai.top"
TMP_DIR="/tmp/jiangxiai-deploy"
BRANCH="main"

echo "===== jiangxiai.top 部署开始 ====="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ---------- 拉取代码 ----------
echo "[1/4] 从 GitHub 拉取代码..."
rm -rf "$TMP_DIR"
git clone --depth 1 -b "$BRANCH" "$GIT_REPO" "$TMP_DIR"
echo "  完成"

# ---------- 同步文件 ----------
echo "[2/4] 同步到 Nginx 目录..."
mkdir -p "$DEPLOY_DIR"
rsync -av --delete \
  --exclude='.git' \
  --exclude='.github' \
  --exclude='remotion-videos' \
  --exclude='node_modules' \
  --exclude='deploy' \
  --exclude='.gitignore' \
  --exclude='README.md' \
  "$TMP_DIR/" "$DEPLOY_DIR/"
echo "  完成"

# ---------- 设置权限 ----------
echo "[3/4] 设置文件权限..."
chown -R www-data:www-data "$DEPLOY_DIR"
find "$DEPLOY_DIR" -type f -exec chmod 644 {} \;
find "$DEPLOY_DIR" -type d -exec chmod 755 {} \;
echo "  完成"

# ---------- 重载 Nginx ----------
echo "[4/4] 重载 Nginx..."
nginx -t && nginx -s reload
echo "  完成"

# ---------- 清理 ----------
rm -rf "$TMP_DIR"

echo ""
echo "===== 部署完成 ====="
echo "站点: https://jiangxiai.top"
echo "文件数: $(find $DEPLOY_DIR -type f | wc -l)"
echo "大小: $(du -sh $DEPLOY_DIR | awk '{print $1}')"
