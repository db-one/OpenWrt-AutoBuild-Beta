
#!/bin/bash

# 安装额外依赖软件包
# sudo -E apt-get -y install rename

# 更新feeds文件
# sed -i 's@#src-git helloworld@src-git helloworld@g' feeds.conf.default # 启用helloworld
# sed -i 's@src-git luci@# src-git luci@g' feeds.conf.default # 禁用18.06Luci
# sed -i 's@## src-git luci@src-git luci@g' feeds.conf.default # 启用23.05Luci
cat feeds.conf.default

# 更新源
# ./scripts/feeds clean
./scripts/feeds update

# 添加第三方软件包
git clone https://github.com/db-one/dbone-packages.git -b 23.05 package/dbone-packages

# 删除部分默认包
rm -rf feeds/luci/applications/luci-app-qbittorrent
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/themes/luci-theme-argon

# 安装源
./scripts/feeds install -a -f

# 自定义定制选项
NET="package/base-files/luci2/bin/config_generate"
ZZZ="package/lean/default-settings/files/zzz-default-settings"
# 读取内核版本
KERNEL_PATCHVER=$(cat target/linux/x86/Makefile|grep KERNEL_PATCHVER | sed 's/^.\{17\}//g')
KERNEL_TESTING_PATCHVER=$(cat target/linux/x86/Makefile|grep KERNEL_TESTING_PATCHVER | sed 's/^.\{25\}//g')
if [[ $KERNEL_TESTING_PATCHVER > $KERNEL_PATCHVER ]]; then
  sed -i "s/$KERNEL_PATCHVER/$KERNEL_TESTING_PATCHVER/g" target/linux/x86/Makefile        # 修改内核版本为最新
  echo "内核版本已更新为 $KERNEL_TESTING_PATCHVER"
else
  echo "内核版本不需要更新"
fi

#
sed -i 's#192.168.1.1#10.0.0.1#g' $NET                                                    # 定制默认IP
# sed -i 's#LEDE#OpenWrt-X86#g' $NET                                                     # 修改默认名称为OpenWrt-X86
sed -i 's@.*CYXluq4wUazHjmCDBCqXF*@#&@g' $ZZZ                                             # 取消系统默认密码
sed -i "s/LEDE /ONE build $(TZ=UTC-8 date "+%Y.%m.%d") @ LEDE /g" $ZZZ              # 增加自己个性名称
echo "uci set luci.main.mediaurlbase=/luci-static/argon" >> $ZZZ                      # 设置默认主题(如果编译可会自动修改默认主题的，有可能会失效)

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #

sed -i 's#localtime  = os.date()#localtime  = os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")#g' package/lean/autocore/files/*/index.htm               # 修改默认时间格式
sed -i 's#%D %V, %C#%D %V, %C Lean_x86_64#g' package/base-files/files/etc/banner               # 自定义banner显示
# sed -i 's@list listen_https@# list listen_https@g' package/network/services/uhttpd/files/uhttpd.config               # 停止监听443端口
# sed -i 's#option commit_interval 24h#option commit_interval 10m#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计写入为10分钟
# sed -i 's#option database_generations 10#option database_generations 3#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计数据周期
# sed -i 's#option database_directory /var/lib/nlbwmon#option database_directory /etc/config/nlbwmon_data#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计数据存放默认位置
# sed -i 's#interval: 5#interval: 1#g' feeds/luci/applications/luci-app-wrtbwmon/htdocs/luci-static/wrtbwmon/wrtbwmon.js               # wrtbwmon默认刷新时间更改为1秒
sed -i '/exit 0/i\ethtool -s eth0 speed 10000 duplex full' package/base-files/files//etc/rc.local               # 强制显示2500M和全双工（默认PVE下VirtIO不识别）

# ●●●●●●●●●●●●●●●●●●●●●●●●定制部分●●●●●●●●●●●●●●●●●●●●●●●● #

# ========================性能跑分========================
echo "rm -f /rom/etc/uci-defaults/xxx-coremark" >> "$ZZZ"
cat >> $ZZZ <<EOF
cat /dev/null > /etc/bench.log
echo " (CpuMark : 191219.823122" >> /etc/bench.log
echo " Scores)" >> /etc/bench.log
EOF

# ================ 网络设置 =======================================

cat >> $ZZZ <<-EOF
# 设置网络-旁路由模式
uci set network.lan.gateway='10.0.0.254'                     # 旁路由设置 IPv4 网关
uci set network.lan.dns='223.5.5.5 119.29.29.29'            # 旁路由设置 DNS(多个DNS要用空格分开)
uci set dhcp.lan.ignore='1'                                  # 旁路由关闭DHCP功能
uci delete network.lan.type                                  # 旁路由桥接模式-禁用
uci set network.lan.delegate='0'                             # 去掉LAN口使用内置的 IPv6 管理(若用IPV6请把'0'改'1')
uci set dhcp.@dnsmasq[0].filter_aaaa='0'                     # 禁止解析 IPv6 DNS记录(若用IPV6请把'1'改'0')

# 设置防火墙-旁路由模式
uci set firewall.@defaults[0].syn_flood='0'                  # 禁用 SYN-flood 防御
uci set firewall.@defaults[0].flow_offloading='0'           # 禁用基于软件的NAT分载
uci set firewall.@defaults[0].flow_offloading_hw='0'       # 禁用基于硬件的NAT分载
uci set firewall.@defaults[0].fullcone='0'                   # 禁用 FullCone NAT
uci set firewall.@defaults[0].fullcone6='0'                  # 禁用 FullCone NAT6
uci set firewall.@zone[0].masq='1'                             # 启用LAN口 IP 动态伪装

# 旁路IPV6需要全部禁用
uci del network.lan.ip6assign                                 # IPV6分配长度-禁用
uci del dhcp.lan.ra                                             # 路由通告服务-禁用
uci del dhcp.lan.dhcpv6                                        # DHCPv6 服务-禁用
uci del dhcp.lan.ra_management                               # DHCPv6 模式-禁用

# 如果有用IPV6的话,可以使用以下命令创建IPV6客户端(LAN口)（去掉全部代码uci前面#号生效）
uci set network.ipv6=interface
uci set network.ipv6.proto='dhcpv6'
uci set network.ipv6.ifname='@lan'
uci set network.ipv6.reqaddress='try'
uci set network.ipv6.reqprefix='auto'
uci set firewall.@zone[0].network='lan ipv6'

uci commit dhcp
uci commit network
uci commit firewall

EOF

# =======================================================

# 移除对uhttpd的依赖
sed -i '/luci-light/d' feeds/luci/collections/luci/Makefile
# 设置 Nginx 默认配置
nginx_config_path="feeds/packages/net/nginx-util/files/nginx.config"
# 使用 cat 和 heredoc 覆盖写入 nginx.config 文件
cat > "$nginx_config_path" <<'EOF'
config main 'global'
        option uci_enable 'true'

config server '_lan'
        list listen '443 ssl default_server'
        list listen '[::]:443 ssl default_server'
        option server_name '_lan'
        list include 'restrict_locally'
        list include 'conf.d/*.locations'
        option uci_manage_ssl 'self-signed'
        option ssl_certificate '/etc/nginx/conf.d/_lan.crt'
        option ssl_certificate_key '/etc/nginx/conf.d/_lan.key'
        option ssl_session_cache 'shared:SSL:32k'
        option ssl_session_timeout '64m'
        option access_log 'off; # logd openwrt'

config server 'http_only'
        list listen '80'
        list listen '[::]:80'
        option server_name 'http_only'
        list include 'conf.d/*.locations'
        option access_log 'off; # logd openwrt'
EOF


nginx_template="feeds/packages/net/nginx-util/files/uci.conf.template"
if [ -f "$nginx_template" ]; then
  # 检查是否已存在配置，避免重复添加
  if ! grep -q "client_body_in_file_only clean;" "$nginx_template"; then
    sed -i "/client_max_body_size 128M;/a\\
        client_body_in_file_only clean;\\
        client_body_temp_path /mnt/tmp;" "$nginx_template"
  fi
fi

luci_support_script="feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support"
if [ -f "$luci_support_script" ]; then
  # 检查是否已经为 ubus location 应用了修复
  if ! grep -q "client_body_in_file_only off;" "$luci_support_script"; then
    echo "正在为 Nginx ubus location 配置应用修复..."
    sed -i "/ubus_parallel_req 2;/a\\
        client_body_in_file_only off;\\
        client_max_body_size 1M;" "$luci_support_script"
  fi
fi
sed -i 's|install_cron_job(CRON_C.*);|// &|' feeds/packages/net/nginx-util/src/nginx-ssl-util.hpp
sed -i 's/remove_cron_job(CRON_CHECK);/// &/' feeds/packages/net/nginx-util/src/nginx-ssl-util.hpp

# 检查 OpenClash 是否启用编译
if grep -qE '^(CONFIG_PACKAGE_luci-app-openclash=n|# CONFIG_PACKAGE_luci-app-openclash=)' "${WORKPATH}/$CUSTOM_SH"; then
  # OpenClash 未启用，不执行任何操作
  echo "OpenClash 未启用编译"
  echo 'rm -rf /etc/openclash' >> $ZZZ
else
  # OpenClash 已启用，执行配置
  if grep -q "CONFIG_PACKAGE_luci-app-openclash=y" "${WORKPATH}/$CUSTOM_SH"; then
    # 判断系统架构
    arch=$(uname -m)  # 获取系统架构
    case "$arch" in
      x86_64)
        arch="amd64"
        ;;
      aarch64|arm64)
        arch="arm64"
        ;;
    esac
    # OpenClash Meta 开始配置内核
    echo "正在执行：为OpenClash下载内核"
    mkdir -p $HOME/clash-core
    mkdir -p $HOME/files/etc/openclash/core
    cd $HOME/clash-core
    # 下载Meta内核
    wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-$arch.tar.gz
    if [[ $? -ne 0 ]];then
      wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-$arch.tar.gz
    else
      echo "OpenClash Meta内核压缩包下载成功，开始解压文件"
    fi
    tar -zxvf clash-linux-$arch.tar.gz
    if [[ -f "$HOME/clash-core/clash" ]]; then
      mv -f $HOME/clash-core/clash $HOME/files/etc/openclash/core/clash_meta
      chmod +x $HOME/files/etc/openclash/core/clash_meta
      echo "OpenClash Meta内核配置成功"
    else
      echo "OpenClash Meta内核配置失败"
    fi
    rm -rf $HOME/clash-core/clash-linux-$arch.tar.gz
    rm -rf $HOME/clash-core
  fi
  # 写入 proxy-server-nameserver 参数
  sed -i '/ruby_edit "$CONFIG_FILE" "\[.dns.\]\[.proxy-server-nameserver.\]"/a\    ruby_edit "$CONFIG_FILE" "['\''dns'\''\]['\''proxy-server-nameserver'\'']" "['\''https://doh.pub/dns-query'\'','\''https://dns.alidns.com/dns-query'\'','\''https://223.5.5.5:443/dns-query'\'','\''https://dns.cloudflare.com/dns-query'\'','\''https://dns.google/dns-query'\'']"' luci-app-openclash/root/etc/openclash/custom/openclash_custom_overwrite.sh
  
  # 写入自定义规则
  cat >> /etc/openclash/custom/openclash_custom_rules.list <<EOF


##########################################################################################
##########################################################################################


##域名黑名单/强制走代理的域名/代理列表
##- DOMAIN-SUFFIX,google.com,Proxy #匹配域名后缀(交由Proxy代理服务器组)
# ==========自定义规则==========
- DOMAIN-SUFFIX,api.telegram.org,🚀 节点选择
- DOMAIN-SUFFIX,rizonesoft.com,🚀 节点选择
- DOMAIN-SUFFIX,cordcloud.one,🚀 节点选择
- DOMAIN-SUFFIX,namecheap.com,🚀 节点选择
- DOMAIN-SUFFIX,555dianying.cc,🚀 节点选择
- DOMAIN-SUFFIX,apkpure.com,🚀 节点选择
- DOMAIN-SUFFIX,time.android.com,🚀 节点选择
- DOMAIN-SUFFIX,wangzi.uk,🚀 节点选择
- DOMAIN-SUFFIX,telegra.ph,🚀 节点选择

# ==========微软TTS规则==========
- DOMAIN-SUFFIX,eastus.tts.speech.microsoft.com,🚀 节点选择

# ==========微软New Bing规则==========
- DOMAIN-SUFFIX,bing.com,💬 Ai平台
- DOMAIN-SUFFIX,bingapis.com,💬 Ai平台
- DOMAIN-SUFFIX,edge.microsoft.com,💬 Ai平台
- DOMAIN-SUFFIX,copilot.microsoft.com,💬 Ai平台

# ==========TMM==========
- DOMAIN-SUFFIX,tmdb.org,🚀 节点选择
- DOMAIN-SUFFIX,themoviedb.org,🚀 节点选择

# ==========Docker规则==========
- DOMAIN-SUFFIX,gcr.io,🚀 节点选择
- DOMAIN-SUFFIX,quay.io,🚀 节点选择
- DOMAIN-SUFFIX,ghcr.io,🚀 节点选择
- DOMAIN-SUFFIX,k8s.gcr.io,🚀 节点选择
- DOMAIN-SUFFIX,docker.io,🚀 节点选择
- DOMAIN-SUFFIX,docker.com,🚀 节点选择

# ==========GitHub==========
- DOMAIN-SUFFIX,github.io,🚀 节点选择
- DOMAIN-SUFFIX,github.com,🚀 节点选择
- DOMAIN-SUFFIX,githubstatus.com,🚀 节点选择
- DOMAIN-SUFFIX,githubassets.com,🚀 节点选择
- DOMAIN-SUFFIX,github.community,🚀 节点选择
- DOMAIN-SUFFIX,github.map.fastly.net,🚀 节点选择
- DOMAIN-SUFFIX,githubusercontent.com,🚀 节点选择
- DOMAIN-SUFFIX,github-com.s3.amazonaws.com,🚀 节点选择
- DOMAIN-SUFFIX,github.global.ssl.fastly.net,🚀 节点选择
- DOMAIN-SUFFIX,github-cloud.s3.amazonaws.com,🚀 节点选择
- DOMAIN-SUFFIX,github-production-user-asset-6210df.s3.amazonaws.com,🚀 节点选择
- DOMAIN-SUFFIX,github-production-release-asset-2e65be.s3.amazonaws.com,🚀 节点选择
- DOMAIN-SUFFIX,github-production-repository-file-5c1aeb.s3.amazonaws.com,🚀 节点选择

# ==========谷歌规则==========
- DOMAIN-SUFFIX,youtube.com,📹 油管视频
- DOMAIN-SUFFIX,google.com,📹 油管视频
- DOMAIN-SUFFIX,google.com.hk,📹 油管视频
- DOMAIN-SUFFIX,hegoogle.com.sgroku,📹 油管视频
- DOMAIN-SUFFIX,google.com.tw,📹 油管视频
- DOMAIN-SUFFIX,googleapis.com,📹 油管视频
- DOMAIN-SUFFIX,googleapis.cn,📹 油管视频
- DOMAIN-SUFFIX,googletagmanager.com,📹 油管视频
- DOMAIN-SUFFIX,googleusercontent.com,📹 油管视频
- DOMAIN-SUFFIX,googlevideo.com,📹 油管视频
- DOMAIN-SUFFIX,www.google.com,📹 油管视频
- DOMAIN-SUFFIX,translate.google.com,📹 油管视频
- DOMAIN-SUFFIX,voice.google.com,📹 油管视频

## ==========游戏规则==========
- DOMAIN-SUFFIX,epicgames.com,🎮 游戏平台
- DOMAIN-SUFFIX,ol.epicgames.com,🎮 游戏平台
- DOMAIN-SUFFIX,store.epicgames.com,🎮 游戏平台
- DOMAIN-SUFFIX,www.epicgames.com,🎮 游戏平台
- DOMAIN-SUFFIX,steamcontent.com,🎮 游戏平台
- DOMAIN-SUFFIX,dl.steam.clngaa.com,🎮 游戏平台
- DOMAIN-SUFFIX,dl.steam.ksyna.com,🎮 游戏平台
- DOMAIN-SUFFIX,st.dl.bscstorage.net,🎮 游戏平台
- DOMAIN-SUFFIX,st.dl.eccdnx.com,🎮 游戏平台
- DOMAIN-SUFFIX,st.dl.pinyuncloud.com,🎮 游戏平台
- DOMAIN-SUFFIX,test.steampowered.com,🎮 游戏平台
- DOMAIN-SUFFIX,media.steampowered.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn.cloudflare.steamstatic.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn.akamai.steamstatic.com,🎮 游戏平台
- DOMAIN-SUFFIX,steampowered.com,🎮 游戏平台
- DOMAIN-SUFFIX,store.steampowered.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn.mileweb.cs.steampowered.com.8686c.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn-ws.content.steamchina.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn-qc.content.steamchina.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn-ali.content.steamchina.com,🎮 游戏平台
- DOMAIN-SUFFIX,epicgames-download1-1251447533.file.myqcloud.com,🎮 游戏平台

##域名白名单/不走代理的域名/直连列表
##- DOMAIN-SUFFIX,alipay.com,DIRECT #匹配域名后缀(直连)
##- DOMAIN-KEYWORD,google,DIRECT #匹配域名关键字(直连)
- DOMAIN-KEYWORD,alipay,DIRECT
- DOMAIN-KEYWORD,taobao,DIRECT
- DOMAIN-KEYWORD,aliexpress,DIRECT
- DOMAIN-KEYWORD,pinduoduo,DIRECT
- DOMAIN-KEYWORD,speedtest,DIRECT
- DOMAIN-KEYWORD,mxnas,DIRECT

#域名解析
- DOMAIN-SUFFIX,api.cloudflare.com,🚀 节点选择
##IP获取
- DOMAIN-SUFFIX,ip.cip.cc,DIRECT
- DOMAIN-SUFFIX,ip.3322.net,DIRECT
- DOMAIN-SUFFIX,myip.ipip.net,DIRECT
##https://api.ip.sb/ip
- DOMAIN-SUFFIX,api.ip.sb,DIRECT
##https://api-ipv4.ip.sb/ip
- DOMAIN-SUFFIX,api-ipv4.ip.sb,DIRECT
##http://members.3322.org/dyndns/getip
- DOMAIN-SUFFIX,members.3322.org,DIRECT
##icanhazip.com
- DOMAIN-SUFFIX,icanhazip.com,DIRECT
##cip.cc
- DOMAIN-SUFFIX,cip.cc,DIRECT


## DNS
- DOMAIN-SUFFIX,cloudflare-dns.com,🚀 节点选择
- DOMAIN-SUFFIX,dns.google,🚀 节点选择
- DOMAIN-SUFFIX,dns.adguard.com,🚀 节点选择
- DOMAIN-SUFFIX,doh.opendns.com,🚀 节点选择

##IP白名单/不走代理的IP/直连列表
##- IP-CIDR,127.0.0.0/8,DIRECT #匹配数据目标IP(直连)
## VPN DDNS服务
- IP-CIDR,130.158.75.0/24,DIRECT
- IP-CIDR,130.158.6.0/24,DIRECT

##########################################################################################
##########################################################################################
EOF

fi

# =======================================================

# 修改退出命令到最后
cd $HOME && sed -i '/exit 0/d' $ZZZ && echo "exit 0" >> $ZZZ
echo "查看 default-settings 文件"
cat $ZZZ

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #


# 创建自定义配置文件

cd $WORKPATH
touch ./.config

#
# ●●●●●●●●●●●●●●●●●●●●●●●●固件定制部分●●●●●●●●●●●●●●●●●●●●●●●●
# 

# 
# 如果不对本区块做出任何编辑, 则生成默认配置固件. 
# 

# 以下为定制化固件选项和说明:
#

#
# 有些插件/选项是默认开启的, 如果想要关闭, 请参照以下示例进行编写:
# 
#          ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
#        ■|  # 取消编译VMware镜像:                    |■
#        ■|  cat >> .config <<EOF                   |■
#        ■|  # CONFIG_VMDK_IMAGES is not set        |■
#        ■|  EOF                                    |■
#          ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
#

# 
# 以下是一些提前准备好的一些插件选项.
# 直接取消注释相应代码块即可应用. 不要取消注释代码块上的汉字说明.
# 如果不需要代码块里的某一项配置, 只需要删除相应行.
#
# 如果需要其他插件, 请按照示例自行添加.
# 注意, 只需添加依赖链顶端的包. 如果你需要插件 A, 同时 A 依赖 B, 即只需要添加 A.
# 
# 无论你想要对固件进行怎样的定制, 都需要且只需要修改 EOF 回环内的内容.
# 

# 编译x64固件:
cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
EOF

# 设置固件大小:
cat >> .config <<EOF
CONFIG_TARGET_KERNEL_PARTSIZE=16
CONFIG_TARGET_ROOTFS_PARTSIZE=360
EOF

# 固件压缩:
cat >> .config <<EOF
CONFIG_TARGET_IMAGES_GZIP=y
EOF

# 编译UEFI固件:
cat >> .config <<EOF
CONFIG_EFI_IMAGES=y
EOF

# IPv6支持:
cat >> .config <<EOF
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_ipv6helper=y
EOF

# 编译PVE/KVM、Hyper-V、VMware镜像以及镜像填充
cat >> .config <<EOF
CONFIG_QCOW2_IMAGES=y
CONFIG_VHDX_IMAGES=y
CONFIG_VMDK_IMAGES=y
CONFIG_TARGET_IMAGES_PAD=y
EOF

# 多文件系统支持:
# cat >> .config <<EOF
# CONFIG_PACKAGE_kmod-fs-nfs=y
# CONFIG_PACKAGE_kmod-fs-nfs-common=y
# CONFIG_PACKAGE_kmod-fs-nfs-v3=y
# CONFIG_PACKAGE_kmod-fs-nfs-v4=y
# CONFIG_PACKAGE_kmod-fs-ntfs=y
# CONFIG_PACKAGE_kmod-fs-squashfs=y
# EOF

# USB3.0支持:
# cat >> .config <<EOF
# CONFIG_PACKAGE_kmod-usb-ohci=y
# CONFIG_PACKAGE_kmod-usb-ohci-pci=y
# CONFIG_PACKAGE_kmod-usb2=y
# CONFIG_PACKAGE_kmod-usb2-pci=y
# CONFIG_PACKAGE_kmod-usb3=y
# EOF

# 多线多拨:
# cat >> .config <<EOF
# CONFIG_PACKAGE_luci-app-syncdial=y #多拨虚拟WAN
# CONFIG_PACKAGE_luci-app-mwan3=y #MWAN负载均衡
# CONFIG_PACKAGE_luci-app-mwan3helper=n #MWAN3分流助手
# EOF

# 第三方插件选择:
cat >> .config <<EOF
# CONFIG_PACKAGE_luci-app-oaf=y #应用过滤
CONFIG_PACKAGE_luci-app-openclash=y #OpenClash客户端
CONFIG_PACKAGE_luci-app-nikki=y #nikki 客户端
# CONFIG_PACKAGE_luci-app-serverchan=y #微信推送
# CONFIG_PACKAGE_luci-app-eqos=y #IP限速
# CONFIG_PACKAGE_luci-app-control-weburl=y #网址过滤
# CONFIG_PACKAGE_luci-app-smartdns=y #smartdns服务器
# CONFIG_PACKAGE_luci-app-adguardhome=y #ADguardhome
CONFIG_PACKAGE_luci-app-poweroff=y #关机（增加关机功能）
# CONFIG_PACKAGE_luci-app-argon-config=y #argon主题设置
# CONFIG_PACKAGE_luci-app-autotimeset=y #定时重启系统，网络
# CONFIG_PACKAGE_luci-app-ddnsto=y #小宝开发的DDNS.to内网穿透
# CONFIG_PACKAGE_ddnsto=y #DDNS.to内网穿透软件包
EOF

# ShadowsocksR插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-ssr-plus=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_SagerNet_Core is not set
EOF

# Passwall插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-passwall=y
# CONFIG_PACKAGE_luci-app-passwall2=y
# CONFIG_PACKAGE_naiveproxy=y
CONFIG_PACKAGE_chinadns-ng=y
# CONFIG_PACKAGE_brook=y
CONFIG_PACKAGE_trojan-go=y
CONFIG_PACKAGE_xray-plugin=n
CONFIG_PACKAGE_shadowsocks-rust-sslocal=n
EOF

# 禁用默认的 Dropbear
cat >> .config <<EOF
CONFIG_PACKAGE_dropbear=n
EOF

# 启用 OpenSSH-Server
cat >> .config <<EOF
CONFIG_PACKAGE_openssh-server=y # 安装 OpenSSH 服务
CONFIG_PACKAGE_openssh-sftp-server=y # 安装 SFTP 支持
EOF

# 禁用 uhttpd ，替换 nginx
cat >> .config <<EOF
CONFIG_PACKAGE_luci-light=n
CONFIG_PACKAGE_uhttpd=n
CONFIG_PACKAGE_uhttpd-mod-ubus=n
CONFIG_PACKAGE_luci-nginx=y
CONFIG_PACKAGE_nginx-util=y
EOF

# Turbo ACC 网络加速:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-turboacc=y
EOF

# 常用LuCI插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-adbyby-plus=n #adbyby去广告
CONFIG_PACKAGE_luci-app-webadmin=n #Web管理页面设置
CONFIG_PACKAGE_luci-app-ddns=n #DDNS服务
CONFIG_DEFAULT_luci-app-vlmcsd=n #KMS激活服务器
CONFIG_PACKAGE_luci-app-filetransfer=y #系统-文件传输
CONFIG_PACKAGE_luci-app-autoreboot=n #定时重启
CONFIG_PACKAGE_luci-app-upnp=n #通用即插即用UPnP(端口自动转发)
CONFIG_PACKAGE_luci-app-arpbind=n #IP/MAC绑定
CONFIG_PACKAGE_luci-app-accesscontrol=n #上网时间控制
CONFIG_PACKAGE_luci-app-wol=n #网络唤醒
CONFIG_PACKAGE_luci-app-nps=n #nps内网穿透
CONFIG_PACKAGE_luci-app-frpc=y #Frp内网穿透
CONFIG_PACKAGE_luci-app-nlbwmon=n #宽带流量监控
CONFIG_PACKAGE_luci-app-wrtbwmon=n #实时流量监测
CONFIG_PACKAGE_luci-app-haproxy-tcp=n #Haproxy负载均衡
CONFIG_PACKAGE_luci-app-diskman=n #磁盘管理磁盘信息
CONFIG_PACKAGE_luci-app-transmission=n #Transmission离线下载
CONFIG_PACKAGE_luci-app-qbittorrent=n #qBittorrent离线下载
CONFIG_PACKAGE_luci-app-amule=n #电驴离线下载
CONFIG_PACKAGE_luci-app-xlnetacc=n #迅雷快鸟
CONFIG_PACKAGE_luci-app-zerotier=n #zerotier内网穿透
CONFIG_PACKAGE_luci-app-hd-idle=n #磁盘休眠
CONFIG_PACKAGE_luci-app-unblockmusic=n #解锁网易云灰色歌曲
CONFIG_PACKAGE_luci-app-airplay2=n #Apple AirPlay2音频接收服务器
CONFIG_PACKAGE_luci-app-music-remote-center=n #PCHiFi数字转盘遥控
CONFIG_PACKAGE_luci-app-usb-printer=n #USB打印机
CONFIG_PACKAGE_luci-app-sqm=n #SQM智能队列管理
CONFIG_PACKAGE_luci-app-jd-dailybonus=n #京东签到服务
CONFIG_PACKAGE_luci-app-uugamebooster=n #UU游戏加速器
CONFIG_PACKAGE_luci-app-dockerman=n #Docker管理
CONFIG_PACKAGE_luci-app-ttyd=n #ttyd
CONFIG_PACKAGE_luci-app-wireguard=n #wireguard端
#
# VPN相关插件(禁用):
#
CONFIG_PACKAGE_luci-app-v2ray-server=y #V2ray服务器
CONFIG_PACKAGE_luci-app-pptp-server=n #PPTP VPN 服务器
CONFIG_PACKAGE_luci-app-ipsec-vpnd=n #ipsec VPN服务
CONFIG_PACKAGE_luci-app-openvpn-server=n #openvpn服务
CONFIG_PACKAGE_luci-app-softethervpn=n #SoftEtherVPN服务器
#
# 文件共享相关(禁用):
#
CONFIG_PACKAGE_luci-app-minidlna=n #miniDLNA服务
CONFIG_PACKAGE_luci-app-vsftpd=n #FTP 服务器
CONFIG_PACKAGE_luci-app-samba=n #网络共享
CONFIG_PACKAGE_autosamba=n #网络共享
CONFIG_PACKAGE_samba36-server=n #网络共享
EOF

# LuCI主题:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-theme-edge=n
EOF

# 常用软件包:
cat >> .config <<EOF
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
# CONFIG_PACKAGE_screen=y
# CONFIG_PACKAGE_tree=y
# CONFIG_PACKAGE_vim-fuller=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_snmpd=y
CONFIG_PACKAGE_libcap=y
CONFIG_PACKAGE_libcap-bin=y
CONFIG_PACKAGE_ip6tables-mod-nat=y
CONFIG_PACKAGE_iptables-mod-extra=y
CONFIG_PACKAGE_vsftpd=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_qemu-ga=y
CONFIG_PACKAGE_autocore-x86=y
EOF

# 其他软件包:
cat >> .config <<EOF
CONFIG_HAS_FPU=y
EOF


# 
# ●●●●●●●●●●●●●●●●●●●●●●●●固件定制部分结束●●●●●●●●●●●●●●●●●●●●●●●● #
# 

sed -i 's/^[ \t]*//g' ./.config

# 返回目录
cd $HOME

# 配置文件创建完成
