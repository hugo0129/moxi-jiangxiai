#!/usr/bin/env bash
# Ubuntu/Debian, systemd, interactive terminal.
set -euo pipefail
BASE=$(cd "$(dirname "$0")" && pwd)
confirm() { local answer; read -r -p "$1 [y/N] " answer; [[ "$answer" == y || "$answer" == Y ]]; }
[[ ${1:-} != --help ]] || { echo 'sudo bash install-baidu.sh [site.tar.gz]'; exit 0; }
[[ $EUID == 0 && -t 0 ]] || { echo '请在交互终端使用 sudo bash install-baidu.sh'; exit 1; }
. /etc/os-release
case "$ID" in ubuntu|debian) ;; *) echo "仅支持 Ubuntu/Debian，当前为 $ID。未修改系统。"; exit 1;; esac
[[ ! -d /www/server/panel ]] || { echo '检测到宝塔，请使用面板部署，避免配置冲突。'; exit 1; }
command -v systemctl >/dev/null
ARCHIVE=${1:-"$BASE/site.tar.gz"}
[[ -f "$ARCHIVE" && -f "$ARCHIVE.sha256" ]] || { echo '请同时上传网站包和 .sha256 校验文件。'; exit 1; }
EXPECTED=$(awk 'NR==1 {print $1}' "$ARCHIVE.sha256")
ACTUAL=$(sha256sum "$ARCHIVE" | awk '{print $1}')
[[ "$EXPECTED" == "$ACTUAL" ]] || { echo '文件校验失败。'; exit 1; }
read -r -p '网站域名 [jiangxiai.top]: ' DOMAIN
DOMAIN=${DOMAIN:-jiangxiai.top}
[[ "$DOMAIN" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ && ${#DOMAIN} -le 253 ]] || { echo '请输入不含协议和路径的小写域名。'; exit 1; }
DOMAINS="$DOMAIN"
if confirm "同时配置 www.$DOMAIN？"; then DOMAINS="$DOMAIN www.$DOMAIN"; fi
SITE="/var/www/$DOMAIN"
CONF="/etc/nginx/conf.d/$DOMAIN.conf"
MARKER='# managed-by: jiangxi-baidu-installer'
if [[ -e "$CONF" ]] && ! grep -qF "$MARKER" "$CONF"; then echo "已有配置 $CONF，停止避免覆盖。"; exit 1; fi
if [[ -e "$SITE/current" && ! -L "$SITE/current" ]]; then echo 'current 不是符号链接，停止。'; exit 1; fi
if command -v nginx >/dev/null; then
  nginx -t
  EXISTING=$(nginx -T 2>&1)
  if [[ ! -f "$CONF" ]] && grep -Fq "$DOMAIN" <<< "$EXISTING"; then echo '现有配置包含此域名，请人工整合。'; exit 1; fi
elif command -v ss >/dev/null && ss -ltnH | awk '{print $4}' | grep -Eq ':80$|:443$'; then
  echo '80/443 端口已被其他服务使用。'; exit 1
fi
printf '\n域名：%s\n目录：%s\n配置：%s\n将安装 nginx、python3、curl，保留旧发布版本。不会自动修改 DNS 或防火墙。\n' "$DOMAINS" "$SITE" "$CONF"
echo '发布包为当前江西 AI 圈内容，尚未包含备案内容整改。'
confirm '确认安装依赖并公开部署这些内容？' || exit 0
apt-get update
apt-get install -y nginx python3 curl
mkdir -p "$SITE/releases" "$SITE/backups" /etc/nginx/conf.d
RELEASE=$(mktemp -d "$SITE/releases/release-XXXXXXXX")
python3 - "$ARCHIVE" "$RELEASE" <<'PY'
import pathlib, sys, tarfile
with tarfile.open(sys.argv[1], 'r:gz') as tf:
    members = tf.getmembers()
    for m in members:
        p = pathlib.PurePosixPath(m.name)
        if p.is_absolute() or '..' in p.parts or not (m.isfile() or m.isdir()) or any(x.startswith('.') for x in p.parts):
            raise SystemExit('Unsafe archive member: '+m.name)
        if not (len(p.parts) == 1 or p.parts[0] == 'img'):
            raise SystemExit('Unexpected path: '+m.name)
    if not any(m.name == 'index.html' and m.isfile() for m in members): raise SystemExit('Missing index.html')
    if sum(m.size for m in members) > 512*1024*1024: raise SystemExit('Archive exceeds 512 MB')
    tf.extractall(sys.argv[2], members=members)
PY
find "$RELEASE" -type d -exec chmod 755 {} +
find "$RELEASE" -type f -exec chmod 644 {} +
chmod 755 "$SITE" "$SITE/releases"
OLD=$(readlink "$SITE/current" || true)
STAMP=$(date +%Y%m%d-%H%M%S)-$$
HAD_CONF=0
if [[ -f "$CONF" ]]; then
  HAD_CONF=1
  cp -a "$CONF" "$SITE/backups/nginx-$STAMP.conf"
else
  cat > "$CONF" <<NGINX
$MARKER
server {
    listen 80;
    server_name $DOMAINS;
    root $SITE/current;
    index index.html;
    gzip on;
    gzip_types text/css application/javascript application/json application/xml image/svg+xml;
    location / { try_files \$uri \$uri/ =404; }
    location ~* \.(html|css|js|json)\$ { add_header Cache-Control "no-cache"; }
    location ~* \.(png|jpg|jpeg|webp|gif|svg|ico)\$ { expires 1d; }
    error_page 404 /404.html;
}
NGINX
fi
rollback() {
  echo '部署失败，恢复原入口和配置。'
  if [[ -n "$OLD" ]]; then ln -s "$OLD" "$SITE/rollback-$$"; mv -Tf "$SITE/rollback-$$" "$SITE/current"; else rm -f "$SITE/current"; fi
  if [[ $HAD_CONF == 1 ]]; then cp -a "$SITE/backups/nginx-$STAMP.conf" "$CONF"; else rm -f "$CONF"; fi
  nginx -t && systemctl reload nginx || true
}
trap rollback ERR
ln -s "$RELEASE" "$SITE/next-$$"
mv -Tf "$SITE/next-$$" "$SITE/current"
nginx -t
systemctl enable --now nginx
systemctl reload nginx
curl -fsS -o /dev/null -H "Host: $DOMAIN" http://127.0.0.1/
trap - ERR
[[ -z "$OLD" ]] || printf '%s\n' "$OLD" > "$SITE/previous-release.txt"
printf '\n部署成功：%s\n上一版本：%s\n' "$RELEASE" "${OLD:-首次部署}"
echo '已有配置原样保留，包括 HTTPS；改变域名列表需人工调整配置。'
printf '请把 %s 的 DNS 指向服务器公网 IP，处理冲突 CNAME/AAAA，并在安全组和系统防火墙放行 TCP 80/443。\n' "$DOMAINS"
confirm '现在配置 HTTPS？DNS 未就绪选 N，之后重新运行。' || exit 0
read -r -p '证书联系邮箱：' EMAIL
[[ "$EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || { echo '邮箱格式不正确。'; exit 1; }
echo '将安装 Certbot，申请 Let’s Encrypt 证书并启用 HTTPS 跳转。请阅读 https://letsencrypt.org/repository/ 的订阅协议。'
confirm '确认域名解析和 80 端口可用，并同意证书协议，继续？' || exit 0
apt-get install -y certbot python3-certbot-nginx
cp -a "$CONF" "$SITE/backups/pre-https-$STAMP.conf"
CERT_ARGS=()
for NAME in $DOMAINS; do CERT_ARGS+=(-d "$NAME"); done
if ! certbot --nginx "${CERT_ARGS[@]}" --email "$EMAIL" --agree-tos --non-interactive --redirect; then
  echo '证书申请失败，网站文件已部署。请检查 DNS、端口及 Certbot 输出，勿反复申请。'; exit 1
fi
nginx -t
certbot renew --dry-run
printf '完成：https://%s\n请从外网检查，并确认 systemctl list-timers 中的证书续期任务。\n' "$DOMAIN"
