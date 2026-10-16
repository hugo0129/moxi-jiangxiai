#!/usr/bin/env bash
# 把网站发布到服务器（与 moxiai.top 的 deploy/deploy.sh 同一套做法）
# 用法：DEPLOY_HOST=<服务器地址> ./deploy/deploy.sh
#   也可以把 DEPLOY_HOST 等写进 deploy/.env（已被 .gitignore 忽略，不会提交），之后直接运行 ./deploy/deploy.sh
# 可选：DEPLOY_USER、DEPLOY_PATH、DEPLOY_KEY（私钥路径）
#
# 做法：合规词检查 → 打包 git 已跟踪的网页文件 → 在服务器解压到临时目录 → 统一属主和权限
#       → 旧版本改名为 .old 留作回滚 → 新版本换上 → 百度推送 → 线上状态检查。
# 回滚：ssh 到服务器执行 mv /www/wwwroot/jiangxiai.top /www/wwwroot/jiangxiai.top.bad && mv /www/wwwroot/jiangxiai.top.old /www/wwwroot/jiangxiai.top
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/deploy/.env" ] && . "$ROOT/deploy/.env"
HOST="${DEPLOY_HOST:?请设置 DEPLOY_HOST（命令行或 deploy/.env）}"
USER="${DEPLOY_USER:-root}"
DEST="${DEPLOY_PATH:-/www/wwwroot/jiangxiai.top}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
[ -n "${DEPLOY_KEY:-}" ] && SSH_OPTS+=(-i "$DEPLOY_KEY")

cd "$ROOT"

# 只发布 git 已跟踪的网页文件：未跟踪的文件（备份、草稿、其他项目）不会上线
FILES="$(git -c core.quotepath=off ls-files | grep -vE '^(docs|deploy|\.github|\.workbuddy)/|^\.|\.(sh|md)$|^LICENSE$' || true)"
[ -n "$FILES" ] || { echo "错误：没有找到可发布的网页文件" >&2; exit 1; }
[ -z "$(git status --porcelain -- $FILES)" ] || echo "提示：有未提交的改动，会按当前工作区内容发布"

# ICP 个人备案合规词检查
FOUND="$(printf '%s\n' "$FILES" | tr '\n' '\0' | xargs -0 grep -nE '夜校|68元|报名中|开始报名|官方合作伙伴|合伙人招募' 2>/dev/null || true)"
if [ -n "$FOUND" ]; then
  echo "合规检查未通过，请先清理以下内容：" >&2
  echo "$FOUND" >&2
  exit 1
fi

printf '%s\n' "$FILES" | COPYFILE_DISABLE=1 tar -czf - -T - |
  ssh "${SSH_OPTS[@]}" "$USER@$HOST" "set -e
    rm -rf '$DEST.new' && mkdir -p '$DEST.new'
    tar -xzf - -C '$DEST.new' --no-same-owner
    chown -R www-data:www-data '$DEST.new'
    find '$DEST.new' -type d -exec chmod 755 {} + && find '$DEST.new' -type f -exec chmod 644 {} +
    rm -rf '$DEST.old'
    [ -d '$DEST' ] && mv '$DEST' '$DEST.old'
    mv '$DEST.new' '$DEST'
    echo \"已发布：\$(find '$DEST' -type f | wc -l) 个文件 → $DEST\"
    if [ -x /root/push-baidu.sh ]; then /root/push-baidu.sh || true; fi"

echo "线上状态：jiangxiai.top $(curl -s -o /dev/null -w '%{http_code}' https://jiangxiai.top/)（应为 200），www $(curl -s -o /dev/null -w '%{http_code}' https://www.jiangxiai.top/)（应为 301）"
