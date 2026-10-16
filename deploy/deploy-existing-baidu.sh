#!/usr/bin/env bash
# Adapt only the existing HTTP-only configuration shown by the user.
set -euo pipefail
[[ $EUID == 0 && -t 0 ]] || { echo '请在交互终端用 root 或 sudo 运行。'; exit 1; }
BASE=$(cd "$(dirname "$0")" && pwd)
CONF=/etc/nginx/conf.d/jiangxiai.top.conf
SITE=/www/wwwroot/jiangxiai.top
for tool in python3 nginx sha256sum cp mv; do command -v "$tool" >/dev/null || { echo "缺少 $tool，未修改。"; exit 1; }; done
[[ -f "$BASE/site.tar.gz" && -f "$BASE/site.tar.gz.sha256" ]] || { echo '请把网站包及校验文件放在脚本同一目录。'; exit 1; }
[[ -f "$CONF" && ! -L "$CONF" && ! -L "$SITE" ]] || { echo '配置不存在或路径是符号链接，需要人工检查。'; exit 1; }
nginx -t
EXPECTED=$(awk 'NR==1 {print $1}' "$BASE/site.tar.gz.sha256")
ACTUAL=$(sha256sum "$BASE/site.tar.gz" | awk '{print $1}')
[[ "$EXPECTED" == "$ACTUAL" ]] || { echo '网站包校验失败。'; exit 1; }
# Refuse to downgrade an existing HTTPS configuration or erase unknown directives.
python3 - "$CONF" <<'PY'
import re, sys
s=open(sys.argv[1]).read()
s=re.sub(r'#[^\n]*','',s)
expected='''server {
listen 80;
server_name jiangxiai.top www.jiangxiai.top;
root /www/wwwroot/jiangxiai.top;
index index.html;
location /.well-known/acme-challenge/ { try_files $uri =404; }
location / { return 301 https://$host$request_uri; }
}'''
normalize=lambda x:re.sub(r'\s+','',x)
if normalize(s)!=normalize(expected):
    raise SystemExit('配置与已确认的 HTTP 跳转配置不同，停止以保留现有设置。请发送最新配置。')
PY
printf '\n[1/5] 检查通过。将部署到 %s\n' "$SITE"
echo '将备份现有网站和配置，把 HTTP 强制 HTTPS 跳转改为直接提供网页。'
echo '不修改 DNS、防火墙、acme.sh 或证书，不启用 HTTPS。'
read -r -p '确认部署当前江西 AI 圈内容并修改此配置？[y/N] ' ANSWER
[[ "$ANSWER" == y || "$ANSWER" == Y ]] || exit 0
mkdir -p /www/wwwroot /var/backups/jiangxi-deploy
BACKUP=$(mktemp -d /var/backups/jiangxi-deploy/backup-XXXXXXXX)
STAGE=$(mktemp -d /www/wwwroot/.jiangxi-stage-XXXXXXXX)
cp -a "$CONF" "$BACKUP/nginx.conf"
HAD_SITE=0
if [[ -d "$SITE" ]]; then
  HAD_SITE=1
  echo '[2/5] 备份原网站（文件较多时需要等待）…'
  cp -a "$SITE" "$BACKUP/site"
fi
python3 - "$BASE/site.tar.gz" "$STAGE" <<'PY'
import tarfile,pathlib,sys
with tarfile.open(sys.argv[1],'r:gz') as t:
    members=t.getmembers()
    for m in members:
        p=pathlib.PurePosixPath(m.name)
        if p.is_absolute() or '..' in p.parts or not(m.isfile() or m.isdir()) or any(x.startswith('.') for x in p.parts):
            raise SystemExit('Unsafe archive path: '+m.name)
        if len(p.parts)>1 and p.parts[0]!='img': raise SystemExit('Unexpected path: '+m.name)
    if not any(m.name=='index.html' and m.isfile() for m in members): raise SystemExit('Missing index.html')
    if sum(m.size for m in members)>512*1024*1024: raise SystemExit('Archive exceeds limit')
    t.extractall(sys.argv[2],members=members)
PY
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f -exec chmod 644 {} +
if [[ -d "$SITE/.well-known" ]]; then cp -a "$SITE/.well-known" "$STAGE/"; fi
cat > "$BACKUP/new.conf" <<'NGINX'
# HTTP deployment; original config is stored in /var/backups/jiangxi-deploy.
server {
    listen 80;
    server_name jiangxiai.top www.jiangxiai.top;
    root /www/wwwroot/jiangxiai.top;
    index index.html;
    autoindex off;
    location ^~ /.well-known/acme-challenge/ { try_files $uri =404; }
    location ~ /\. { deny all; }
    location / { try_files $uri $uri/ =404; }
    location ~* \.(html|css|js|json)$ { add_header Cache-Control "no-cache"; }
    error_page 404 /404.html;
    gzip on;
    gzip_types text/css application/javascript application/json image/svg+xml;
}
NGINX
SWAPPED=0
OLD_MOVED=0
OLD_PATH="$STAGE-old"
rollback() {
  trap - ERR INT TERM
  echo "失败，正在恢复；备份在 $BACKUP"
  if [[ $SWAPPED == 1 ]]; then mv "$SITE" "$STAGE-failed"; fi
  if [[ $OLD_MOVED == 1 ]]; then mv "$OLD_PATH" "$SITE"; fi
  cp -a "$BACKUP/nginx.conf" "$CONF"
  nginx -t && nginx -s reload || true
  exit 1
}
trap rollback ERR INT TERM
echo '[3/5] 切换网站文件和配置…'
if [[ $HAD_SITE == 1 ]]; then mv "$SITE" "$OLD_PATH"; OLD_MOVED=1; fi
mv "$STAGE" "$SITE"
SWAPPED=1
cp "$BACKUP/new.conf" "$CONF"
echo '[4/5] 检查并重载 Nginx…'
nginx -t
nginx -s reload
echo '[5/5] 验证本机 HTTP 返回的首页内容…'
python3 - "$SITE/index.html" <<'PY'
import urllib.request,sys,time
expected=open(sys.argv[1],'rb').read()
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs): return None
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect())
for attempt in range(5):
    try:
        req=urllib.request.Request('http://127.0.0.1/',headers={'Host':'jiangxiai.top'})
        with opener.open(req,timeout=5) as response:
            if response.status==200 and response.read()==expected: break
    except Exception: pass
    time.sleep(1)
else: raise SystemExit('HTTP 首页检查失败')
PY
trap - ERR INT TERM
printf '\n部署成功：http://jiangxiai.top\n备份目录：%s\n' "$BACKUP"
[[ $OLD_MOVED == 0 ]] || printf '切换前目录保留在：%s\n' "$OLD_PATH"
echo '本脚本只恢复 HTTP。若浏览器记住 HTTPS/HSTS，可能仍无法打开，需要完成证书配置；不要绕过证书警告。'
echo '下一步检查 acme.sh 证书状态后再启用 HTTPS。公网访问还依赖 DNS 和安全组 80 端口。'
