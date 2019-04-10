# ddns_ipv6.sh
基于 DNSPod 实现的 IPv6的 DDNS 动态更新

解析 json 需要安装 jq
apt/brew/yum install jq

自行安装，没有做太多兼容判断。
自行配置 API Token 与域名信息。

子域名请先自行创建 AAAA 记录。