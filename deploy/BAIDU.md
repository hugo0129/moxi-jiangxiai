# 百度云交互式部署

适用：Ubuntu/Debian、systemd、sudo 权限。其他系统及宝塔环境会停止；不要在生产服务器上为适配脚本重装系统。

## 本地

在项目根目录执行 `bash deploy/package-baidu.sh`。
输出到项目上一级的 `baidu-release`，包括网站包、校验文件、安装脚本和本文。
仅打包静态资源，不包含 Git、部署配置、密钥或 node_modules。发布内容仍是当前江西 AI 圈版本。

把这四个文件通过百度云上传功能或 SFTP 上传到服务器同一目录，例如 `/tmp/jiangxi-upload`。
也可在本地执行（请自行替换 SSH 用户和已确认的公网 IP）：

```bash
ssh USER@SERVER_IP 'mkdir -p /tmp/jiangxi-upload'
scp ../baidu-release/* USER@SERVER_IP:/tmp/jiangxi-upload/
ssh USER@SERVER_IP
cd /tmp/jiangxi-upload
sudo bash install-baidu.sh
```

## 服务器交互步骤

1. 输入域名，选择是否启用 www。
2. 核对目录、配置路径与要公开的内容，输入 y 开始安装部署。
3. 到 DNS 服务商处把主域名以及选择的 www 的 A 记录指向服务器公网 IP；处理旧 CNAME 和旧 AAAA。安全组及系统防火墙放行 TCP 80/443，SSH 端口按需要限制来源。
4. DNS 就绪再选择 HTTPS。未就绪可选 N；以后重新运行脚本也可以，仅会增加一个发布版本。
5. 输入邮箱、阅读并确认证书协议，然后申请证书和测试续期。
6. 从其他网络访问正式域名，确认页面、图片、跳转和备案链接。

脚本不会修改 DNS、安全组、其他站点，不需要 GitHub 凭据。摘要校验用于检测传输损坏，并非包签名。
首次安装 Nginx 可能启动系统默认站点。脚本只新增自己的域名配置；如需移除默认欢迎页，请确认未承载其他业务后自行处理。
已有同域名且非脚本管理的 Nginx 配置将被拒绝；已安装宝塔同样拒绝。脚本管理的配置在再次部署时保留，避免覆盖 HTTPS；若更改域名列表，需人工调整。

## 更新与回滚

更新：重新本地打包，上传新包和摘要，重新运行安装脚本。每次都使用全新发布目录，不会残留旧版本删除的页面。
历史版本在 `/var/www/你的域名/releases`，配置备份在 `backups`。不自动清理，请关注磁盘空间。
发布阶段 nginx 检查、重载或 HTTP 检查失败会恢复旧入口及配置。包校验/解压阶段失败不会切换入口；依赖安装不会回滚。证书阶段失败不会撤销已完成的网站发布，请按输出检查配置。

手动回滚（以下以默认域名为例，确认 previous-release.txt 指向你要恢复的版本）：

```bash
sudo cat /var/www/jiangxiai.top/previous-release.txt
sudo bash -c '
set -e
site=/var/www/jiangxiai.top
previous=$(cat "$site/previous-release.txt")
test -d "$previous"
ln -s "$previous" "$site/manual-rollback-$$"
mv -Tf "$site/manual-rollback-$$" "$site/current"
nginx -t
systemctl reload nginx
'
```

首次部署没有上一版本。回滚只恢复网站文件，不撤销 DNS、软件安装或证书；配置备份应由管理员检查后恢复。图片可能缓存一天，若需要立即更新同名图片，请修改资源 URL。

## 排错

- nginx -t：查看配置错误。
- sudo systemctl status nginx：查看服务状态。
- sudo journalctl -u nginx -n 50：查看日志。
- sudo ss -ltnp：检查端口监听。
- HTTPS 失败：检查所有所选域名的 A/AAAA、公网 80 端口及 Certbot 输出，不要连续重复申请。
- sudo systemctl list-timers --all：确认 certbot 自动续期任务。

本地已检查 Bash 语法、真实打包内容及部署包路径安全校验；尚未在你的百度云服务器上执行安装和证书申请。
