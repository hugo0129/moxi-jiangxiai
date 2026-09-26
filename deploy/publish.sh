#!/usr/bin/env bash
# ==============================================================================
# 《智能实战笔记》Mac 本地一键打包发布流水线 (publish.sh)
# 用法：在 Mac 本地项目根目录下直接运行 ./publish.sh
# 流程：
# 1. [合规风控体检]：扫描 site-release/，拦截敏感词（夜校/68元/报名中/官方合作伙伴等）
# 2. [纯净防污染打包]：设置 COPYFILE_DISABLE=1，排除 .DS_Store 和 ._* 打包 site.tar.gz
# 3. [自动上传部署]：SCP 上传至服务器 /root/jiangxi-deploy/
# 4. [远端自动解压]：SSH 调用服务端的安全部署流水线 (deploy-site.sh)
# 5. [线上健康探针]：curl 快速自检生产环境 301 与 200 状态
# ==============================================================================
set -e

REMOTE_HOST="root@182.61.49.73"
REMOTE_DEPLOY_DIR="/root/jiangxi-deploy"
LOCAL_SITE_DIR="site-release"

echo "=========================================================="
echo " 🚀 开始《智能实战笔记》代码更新一键发布流程"
echo "=========================================================="

# 步骤 1：合规性体检
echo "[1/5] 执行 ICP 个人备案合规风控体检..."
SENSITIVE_WORDS=("夜校" "68元" "报名中" "开始报名" "官方合作伙伴" "合伙人招募")
HAS_VIOLATION=0

for word in "${SENSITIVE_WORDS[@]}"; do
    FOUND=$(grep -rn "$word" "$LOCAL_SITE_DIR" 2>/dev/null || true)
    if [ -n "$FOUND" ]; then
        echo "[-] 警告: 发现敏感合规词汇: '$word'"
        echo "$FOUND"
        HAS_VIOLATION=1
    fi
done

if [ "$HAS_VIOLATION" -eq 1 ]; then
    echo "[-] 体检未通过！请先清理以上违规词汇后再发布。"
    exit 1
fi
echo "[+] 合规体检通过 (0 违规敏感词)"

# 步骤 2：纯净防污染打包
echo "[2/5] 正在执行纯净打包 (防 macOS AppleDouble 污染)..."
export COPYFILE_DISABLE=1
(cd "$LOCAL_SITE_DIR" && tar --exclude='.DS_Store' --exclude='._*' -czvf ../site.tar.gz *)
shasum -a 256 site.tar.gz > site.tar.gz.sha256
echo "[+] 打包成功: site.tar.gz (SHA-256: $(cat site.tar.gz.sha256 | awk '{print $1}'))"

# 步骤 3：上传至服务器
echo "[3/5] 正在上传 site.tar.gz 与部署脚本至 $REMOTE_HOST:$REMOTE_DEPLOY_DIR/ ..."
scp site.tar.gz deploy-site.sh "$REMOTE_HOST:$REMOTE_DEPLOY_DIR/"

# 步骤 4：远程执行解压部署
echo "[4/5] 正在触发服务端自动化解压部署流水线..."
ssh "$REMOTE_HOST" "bash $REMOTE_DEPLOY_DIR/deploy-site.sh"

# 步骤 5：线上健康检查
echo "[5/5] 执行线上生产健康探测..."
STATUS_MAIN=$(curl -s -o /dev/null -w "%{http_code}" https://jiangxiai.top)
STATUS_WWW=$(curl -s -o /dev/null -w "%{http_code}" https://www.jiangxiai.top)

echo "[+] https://jiangxiai.top/ 响应码: $STATUS_MAIN (预期: 200)"
echo "[+] https://www.jiangxiai.top 响应码: $STATUS_WWW (预期: 301)"

if [ "$STATUS_MAIN" = "200" ] && [ "$STATUS_WWW" = "301" ]; then
    echo "=========================================================="
    echo " 🎉 全部发布与验证成功！站点已顺利上线运行。"
    echo "=========================================================="
else
    echo "[-] 警告: 状态码异常，请手动复核线上 Nginx 状态！"
fi
