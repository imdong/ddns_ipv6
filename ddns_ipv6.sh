#!/bin/bash

# DNSPod 的 API Token (Url: https://www.dnspod.cn/console/user/security)
DNSPOD_API_TOKEN='9***4,8755*********fa39';

# 要解析的主域名
DOMAIN_HOST='qs5.org'

# 要解析的子域名记录(请确保已经添加 此 AAAA 记录)
DOMAIN_SUB='ddns'

# DNSPod 的 API 接口地址
DNSPOD_API_HOST='https://dnsapi.cn/'

#=========== 下面为脚本区，无需配置 ===========

BIN_JQ='/usr/local/bin/jq'

# 获取本机当前 IP
get_ip() {
    # 通过网站 获取外网 IP
    # _ip_str=$(curl -s "http://ss1-v6.qs5.org/?ip")

    # 通过 ifconfig 截取外网 IP
    LOCAL_IP=`/sbin/ifconfig | grep 'inet6' | grep -v ' \(fe80:\|::1\)' | grep -o 'inet6 [a-fA-F0-9:]\+ ' | cut -d ' ' -f2`
}

# 使用 cUrl POST 一个 API 请求
api_send() {
    # 生成请求信息
    API_URL="${DNSPOD_API_HOST}${1}"
    POST_DATA="login_token=${DNSPOD_API_TOKEN}&format=json&lang=cn&${2}";

    # 发送请求捕获结果
    result=`/usr/bin/curl -s -X POST "${API_URL}" -d "${POST_DATA}"`;
    return_id=`echo ${result} | ${BIN_JQ} -r '.status.code'`;

    # 请求不成功则走异常处理
    if [ ${return_id} != 1 ]; then
        echo "Failure(${return_id}): `echo ${result} | ${BIN_JQ} -r '.status.message'`";
        echo -e "Url: ${API_URL}\nData: ${POST_DATA}\nResult: ${result}\n";
        exit ${return_id};
    fi

    return $return_id;
}

# 检测 IP 是否需要更新
check_update_ip() {
    # 输出当前时间
    date

    # 测试 获取版本号
    api_send 'Info.Version'
    echo "DNSPod API Version: `echo ${result} | ${BIN_JQ} -r '.status.message'`"

    # 获取记录详细信息
    api_send 'Record.List' "domain=${DOMAIN_HOST}&sub_domain=${DOMAIN_SUB}&record_type=AAAA"

    # 获取本机 IP
    get_ip

    # 获取记录原来的值
    DDNS_IP=`echo ${result} | ${BIN_JQ} -r '.records[0].value'`

    # 记录当前 IP
    echo -e "Local IP = '${LOCAL_IP}'\n DDNS IP = '${DDNS_IP}'";

    # 如果 IP 有变更则上报
    if [ ${LOCAL_IP} != ${DDNS_IP} ]; then
        record_id=`echo ${result} | ${BIN_JQ} -r '.records[0].id'`
        record_line_id=`echo ${result} | ${BIN_JQ} -r '.records[0].line_id'`
        api_send 'Record.Modify' "domain=${DOMAIN_HOST}&record_id=${record_id}&sub_domain=${DOMAIN_SUB}&record_type=AAAA&record_line_id=${record_line_id}&value=${LOCAL_IP}"
        echo -e "Sccuess: `echo ${result} | ${BIN_JQ} -r '.status.message'`\n";
    else
        echo -e 'None: IP 没有改变.\n'
    fi;
}

# 安装插件
install() {

    # 安装必须使用 root 权限
    if [ ! `id -u` -eq '0' ]; then
        echo "请使用 root 用户启动脚本安装";
        exit 1;
    fi

    # 检查 jq 是否安装
    ${BIN_JQ} --version
    if [ $? != 0 ]; then
        echo "依赖插件 jq, 请手动安装 jq 插件, yum/apt/brew 商店可直装.";
        exit 0;
    fi

    # 安装到系统目录
    mkdir -p /etc/cron.d/
    cp $0 /etc/cron.d/ddns_ipv6.sh
    chmod +x /etc/cron.d/ddns_ipv6.sh

    # 创建日志目录
    mkdir -p /usr/local/var/log/ddns_ipv6/

    # 创建临时文件
    tmp_file=$(mktemp) || exit 1

    # 输出到 cron
    crontab -l > "${tmp_file}" && echo "*/2 * * * * /etc/cron.d/ddns_ipv6.sh check >> /usr/local/var/log/ddns_ipv6/logs.log" >> "${tmp_file}" && crontab "${tmp_file}" && rm -f "${tmp_file}"

    echo '安装完毕...'
}

if [ "check" == "$1" ]; then
    # 检测 IP
    check_update_ip;
    exit;
fi

# 否则走安装流程
install;
