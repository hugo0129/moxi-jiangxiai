# jiangxiai.top 阿里云部署指南

## 一、购买阿里云轻量应用服务器

1. 登录阿里云控制台 → 轻量应用服务器
2. 推荐配置：
   - 地域：杭州 / 北京 / 深圳（选离你最近的）
   - 镜像：Ubuntu 22.04 LTS
   - 套餐：2核2G 3M带宽（活动价约 108 元/年）
3. 购买后记录服务器公网 IP

## 二、ICP 备案（关键，约 2-3 周）

1. 阿里云控制台 → ICP 备案
2. 准备材料：
   - 身份证正反面
   - 域名证书（域名管理页面下载）
   - 服务器实例 ID
3. 填写信息：
   - 主办单位：个人
   - 网站名称：江西 AI 圈（不要含"中国""中华"等字样）
   - 网站域名：jiangxiai.top
4. 通过阿里云初审 → 工信部审核 → 备案号下发
5. 备案通过后，在网站底部添加备案号

## 三、DNS 切换

备案通过后，将域名 DNS 从 GitHub 切到阿里云：

1. 阿里云控制台 → 云解析 DNS
2. 添加域名 jiangxiai.top
3. 在域名注册商处修改 DNS 服务器为阿里云：
   - dns1.hichina.com
   - dns2.hichina.com
4. 添加解析记录：
   - A 记录：@ → 服务器公网 IP
   - A 记录：www → 服务器公网 IP
   - CNAME：配合 CDN 使用时改为 CNAME 记录

## 四、服务器初始化

SSH 连接到服务器后执行：

```bash
# 更新系统
apt update && apt upgrade -y

# 安装 Nginx
apt install -y nginx

# 安装 Git
apt install -y git

# 创建网站目录
mkdir -p /var/www/jiangxiai.top

# 配置 Nginx
cp /tmp/nginx.conf /etc/nginx/sites-available/jiangxiai.top
ln -s /etc/nginx/sites-available/jiangxiai.top /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# 测试并重启
nginx -t && systemctl restart nginx
```

## 五、SSL 证书

1. 阿里云控制台 → 数字证书管理 → SSL 证书
2. 申请免费 DV 证书（每年 20 个免费额度）
3. 域名：jiangxiai.top + www.jiangxiai.top
4. DNS 验证（自动添加 TXT 记录）
5. 下载证书（Nginx 格式）
6. 上传到服务器：
   ```bash
   mkdir -p /etc/nginx/ssl
   # 上传 .pem 和 .key 文件
   scp jiangxiai.top.pem <登录用户>@<服务器地址>:/etc/nginx/ssl/
   scp jiangxiai.top.key <登录用户>@<服务器地址>:/etc/nginx/ssl/
   chmod 600 /etc/nginx/ssl/jiangxiai.top.key
   ```

## 六、部署网站

首次部署：

```bash
# 在服务器上配置 SSH key 用于拉取 GitHub 仓库
ssh-keygen -t ed25519 -C "deploy@jiangxiai.top"
cat ~/.ssh/id_ed25519.pub
# 将公钥添加到 GitHub 仓库的 Deploy Keys

# 部署
chmod +x deploy/deploy.sh
./deploy/deploy.sh
```

后续更新只需再次运行 `./deploy.sh`。

## 七、CDN 加速（可选但推荐）

1. 阿里云控制台 → CDN
2. 添加加速域名：jiangxiai.top
3. 源站信息：服务器公网 IP，端口 443，协议 HTTPS
4. 加速类型：全站加速
5. HTTPS 配置：上传 SSL 证书
6. 缓存配置：
   - HTML：不缓存（0 秒）
   - CSS/JS：30 天
   - 图片：90 天
7. DNS 修改：将 A 记录改为 CNAME 指向 CDN 域名

## 八、百度站长提交

1. 登录百度搜索资源平台 (ziyuan.baidu.com)
2. 添加站点：https://jiangxiai.top
3. 验证方式：已有 baidu-site-verification 标签
4. 提交 sitemap：https://jiangxiai.top/sitemap.xml
5. 使用主动推送 API（见下方）

### 百度主动推送脚本

```bash
# 添加到部署脚本末尾，每次部署后自动推送
curl -H "Content-Type:text/plain" --data-binary @urls.txt \
  "http://data.zz.baidu.com/urls?site=jiangxiai.top&token=YOUR_TOKEN"
```

## 九、Google Search Console

1. 访问 search.google.com/search-console
2. 添加属性：https://jiangxiai.top
3. 验证方式：HTML 标签（将验证码添加到 index.html 的 <head> 中）
4. 提交 sitemap：https://jiangxiai.top/sitemap.xml

## 十、安全头验证

部署完成后验证安全头是否生效：

```bash
curl -sI https://jiangxiai.top/ | grep -iE "strict-transport|x-frame|x-content-type|referrer-policy"
```

预期输出：
- Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- Referrer-Policy: strict-origin-when-cross-origin
