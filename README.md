# Argo xray for PaaS

## 项目特点

* 本项目用于在任意一家 PaaS 云服务商部署 xray ，采用的方案为 Argo + Nginx + WebSocket + VMess/Vless/Trojan/Shadowsocks + TLS
* xray 核心文件和配置文件作了“特殊处理”，每个项目都不同，大大降低被封和连坐风险
* vmess 和 vless 的 uuid 或 trojan 和 shadowsocks 的密码，路径既可以自定义，也可以使用默认值
* 默认已将 OpenAI 分流至 WARP
* 设置增强订阅功能，以实时获取最新分配的 CloudFlare Argo Tunnel 隧道地址
* 集成哪吒探针，可以自由选择是否安装
* 部署完成如发现不能上网，请检查域名是否被墙，可使用生成的 Argo 节点或 Cloudflare CDN 或者 worker 解决。

## 增强

* `https://<PaaS云服务商分配的域名>/<UUID>.html` 展示了各种配置以及客户端二维码。
* `https://<PaaS云服务商分配的域名>/<UUID>.json` 为对应的 v2ray 客户端文件。
* 增加订阅模式，以防止每次 CloudFlare 分配的域名改变。可在 V2rayA 和安卓上的 V2rayNG 中添加订阅，地址为`https://<PaaS云服务商分配的域名>/<UUID>.txt`。每次发现之前的地址不可用之后先刷新下订阅再尝试连接，如果还不行过30秒刷一次再试，因为容器启动需要时间。
* `https://<PaaS云服务商分配的域名>/cf.txt` 为最新的Cloudflare分配域名。
* 增加 Cloudflared 多次重试，应对 CloudFlare 偶尔抽风。
* 在连接路径后面增加 `_warp` 来使流量全程走Cloudflare WARP。
* `https://<PaaS云服务商分配的域名>/<UUID>.rootfs/` 可直接下载rootfs中的内容（可在nginx.conf中删除相关段以禁用）。
* 增加ssh服务器，可连接至后台。该ssh服务在公网上不可见，需要以无"_warp"的路径连接到节点，然后通过proxychains劫持来连接：`proxychains ssh root@127.0.0.1 -v`。
* ssh服务器仅支持Key的方式登录，可以设置环境变量 `SSH_PUBKEY`、`SSH_PUBKEY2`、`SSH_PUBKEY3` 和`SSH_PUBKEY4`，最多支持 4 个 Key。

## 部署

* 注册任意一家 PaaS 云服务商
* 根据 PaaS 云服务商的不同绑定自己的 GitHub 账户或使用项目提供的 Actions 生成 DockerHub 镜像，严重建议小号 + 私库
* 项目可用到的变量
  | 变量名 | 是否必须 | 默认值 | 备注 |
  | ------------ | ------ | ------ | ------ |
  | UUID         | 否 | 966b4678-366c-40a6-8526-f8f8b81448a6 | 可在线生成 https://www.uuidgenerator.net/ |
  | VMESS_WSPATH  | 否 | /vmess | 以 / 开头 |
  | VMESS_WSPATH_WARP  | 否 | /vmess_warp | 以 / 开头 |
  | VLESS_WSPATH  | 否 | /vless | 以 / 开头 |
  | VLESS_WSPATH_WARP  | 否 | /vless_warp | 以 / 开头 |
  | TROJAN_WSPATH | 否 | /trojan | 以 / 开头 |
  | TROJAN_WSPATH_WARP | 否 | /trojan_warp | 以 / 开头 |
  | SS_WSPATH     | 否 | /shadowsocks | 以 / 开头 |
  | SS_WSPATH_WARP     | 否 | /shadowsocks_warp | 以 / 开头 |
  | NEZHA_SERVER  | 否 |     | 哪吒探针服务端的 IP 或域名 |
  | NEZHA_PORT    | 否 |     | 哪吒探针服务端的端口 |
  | NEZHA_KEY     | 否 |     | 哪吒探针客户端专用 Key |

* GitHub Actions 用到的变量

  |    变量名     |      备注      |
  | ------------- | -------------- |
  |DOCKER_USERNAME|Docker Hub 用户名|
  |DOCKER_PASSWORD|Docker Hub 密码  |
  |DOCKER_REPO    |Docker Hub 仓库名|

![image](https://user-images.githubusercontent.com/116990986/211692321-34df154a-320a-448f-9abe-2efab9c53550.png)

## 鸣谢

* ifeng 的 v2ray 项目：https://github.com/hiifeng
* fscarmen2 的 argo xray 项目：https://github.com/fscarmen2

## 免责声明

* 本程序仅供学习了解, 非盈利目的，请于下载后 24 小时内删除, 不得用作任何商业用途, 文字、数据及图片均有所属版权, 如转载须注明来源。
* 使用本程序必循遵守部署免责声明。使用本程序必循遵守部署服务器所在地、所在国家和用户所在国家的法律法规, 程序作者不对使用者任何不当行为负责.

## 赞助

爱发电：https://afdian.net/a/Misaka-blog

![afdian-MisakaNo の 小破站](https://user-images.githubusercontent.com/122191366/211533469-351009fb-9ae8-4601-992a-abbf54665b68.jpg)
