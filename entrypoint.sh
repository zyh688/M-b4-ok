#!/usr/bin/env bash

DISPLAY_NAME=${DISPLAY_NAME:-'Argo_xray_'}

# 定义 UUID 及 伪装路径,请自行修改.(注意:伪装路径以 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
UUID=${UUID:-'966b4678-366c-40a6-8526-f8f8b81448a6'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VMESS_WARP_WSPATH=${VMESS_WARP_WSPATH:-'/vmess_warp'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}
VLESS_WARP_WSPATH=${VLESS_WARP_WSPATH:-'/vless_warp'}
TROJAN_WSPATH=${TROJAN_WSPATH:-'/trojan'}
TROJAN_WARP_WSPATH=${TROJAN_WARP_WSPATH:-'/trojan_warp'}
SS_WSPATH=${SS_WSPATH:-'/shadowsocks'}
SS_WARP_WSPATH=${SS_WARP_WSPATH:-'/shadowsocks_warp'}

VAR_NAMES=("UUID" "VMESS_WSPATH" "VMESS_WARP_WSPATH" "VLESS_WSPATH" "VLESS_WARP_WSPATH" "TROJAN_WSPATH" "TROJAN_WARP_WSPATH" "SS_WSPATH" "SS_WARP_WSPATH")

# Function to perform variable substitution in a text file
perform_variable_substitution() {
	local text_file="$1"  # Text file to be processed
	shift  # Shift the arguments to remove the text_file argument
	local var_names=("$@")  # Array of variable names

	# Iterate over each variable name in the array
	for var_name in "${var_names[@]}"; do
		# Get the value of the variable
		local var_value="${!var_name}"
		local escaped_value="${var_value//\//\\/}"  # Escape forward slashes

		# Replace the placeholder with the variable value in the text file
		sed -i "s/#$var_name#/$escaped_value/g" "$text_file"
	done
}

perform_substitutions() {
	[ -f "$2" ] && rm "$2"
	cp "$1" "$2"
	perform_variable_substitution "$2" "${VAR_NAMES[@]}"
}

perform_substitutions template_config.json config.json
perform_substitutions template_nginx.conf /etc/nginx/nginx.conf

# 配置并启动SSH服务器
KEYS_FILE="/root/.ssh/authorized_keys"
mkdir -p /root/.ssh
echo $SSH_PUBKEY > $KEYS_FILE
echo $SSH_PUBKEY2 >> $KEYS_FILE
echo $SSH_PUBKEY3 >> $KEYS_FILE
echo $SSH_PUBKEY4 >> $KEYS_FILE
chmod 644 $KEYS_FILE
/etc/init.d/ssh restart

# 设置 nginx 伪装站
rm -rf /usr/share/nginx/*
unzip -o "./mikutap.zip" -d /usr/share/nginx/html

# 伪装 xray 执行文件
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
[ -f "exec.txt" ] && RELEASE_RANDOMNESS=$(<exec.txt tr -d '\n') || echo -n $RELEASE_RANDOMNESS > exec.txt
mv xray $RELEASE_RANDOMNESS
[ -f "geoip.dat" ] && rm "geoip.dat"
[ -f "geosite.dat" ] && rm "geosite.dat"
wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
cat config.json | base64 > config
rm -f config.json

# 如果有设置哪吒探针三个变量,会安装。如果不填或者不全,则不会安装
[ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ] && wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh && ./nezha.sh install_agent $NEZHA_SERVER $NEZHA_PORT $NEZHA_KEY

# Start Cloudflare free tunnel
# Time to wait before checking the URL
CFTUNNEL_WAIT=${CFTUNNEL_WAIT:-5}
# Set default retry limit to 3
CFTUNNEL_RETRY_LIMIT=${CFTUNNEL_RETRY_LIMIT:-3}
# Time to wait before the next attempt
CFTUNNEL_RETRY_DELAY=${CFTUNNEL_RETRY_DELAY:-5}

counter=0
while true
do
	((counter++))

	# Attempt to create the tunnel
	cloudflared tunnel --url http://localhost:80 --no-autoupdate > argo.log 2>&1 &
	sleep $CFTUNNEL_WAIT
	ARGO_URL=$(cat argo.log | grep -oE "https://.*[a-z]+cloudflare.com" | sed "s#https://##")

	# Check if ARGO_URL is empty and retry if necessary
	if [[ -z $ARGO_URL ]]; then
		echo "ERROR: Failed to start Cloudflare tunnel. Retrying in $CFTUNNEL_RETRY_DELAY seconds..."
		sleep $CFTUNNEL_RETRY_DELAY
	else
		break
	fi

	# Exit loop if retry limit is reached
	if [[ $counter -ge $CFTUNNEL_RETRY_LIMIT ]] && [[ $CFTUNNEL_RETRY_LIMIT -ne 0 ]]; then
		ARGO_URL="Unable to obtain Cloudflare Tunnel URL"
		echo "ERROR: Failed to start Cloudflare tunnel. Maximum retry limit reached."
		break
	fi
done

VAR_NAMES=("${VAR_NAMES[@]}" "ARGO_URL")

# 方便查找CF地址
echo $ARGO_URL > /usr/share/nginx/html/cf.txt

# 启动Warp, 需要在Dockerfile中启用安装Warp官方客户端
# warp-svc &
# warp-cli register
# warp-cli set-custom-endpoint <xxx>
# warp-cli set-mode proxy
# warp-cli set-proxy-port 1080
# warp-cli connect

# 输出vmess客户端配置文件到$UUID.json
CLIENT_JSON_PATH="/usr/share/nginx/html/$UUID.json"
cp template_client_config.json $CLIENT_JSON_PATH
perform_variable_substitution $CLIENT_JSON_PATH ${VAR_NAMES[@]}

# 生成qr码以及网页
vmlink=$(echo -e '\x76\x6d\x65\x73\x73')://$(echo -n "{\"v\":\"2\",\"ps\":\"${DISPLAY_NAME}vmess\",\"add\":\"$ARGO_URL\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$ARGO_URL\",\"path\":\"$VMESS_WSPATH?ed=2048\",\"tls\":\"tls\"}" | base64 -w 0)
vmlink_warp=$(echo -e '\x76\x6d\x65\x73\x73')://$(echo -n "{\"v\":\"2\",\"ps\":\"${DISPLAY_NAME}vmess(WARP)\",\"add\":\"$ARGO_URL\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$ARGO_URL\",\"path\":\"$VMESS_WARP_WSPATH?ed=2048\",\"tls\":\"tls\"}" | base64 -w 0)
vllink=$(echo -e '\x76\x6c\x65\x73\x73')"://"$UUID"@"$ARGO_URL":443?encryption=none&security=tls&type=ws&host="$ARGO_URL"&path="$VLESS_WSPATH"?ed=2048#${DISPLAY_NAME}vless"
vllink_warp=$(echo -e '\x76\x6c\x65\x73\x73')"://"$UUID"@"$ARGO_URL":443?encryption=none&security=tls&type=ws&host="$ARGO_URL"&path="$VLESS_WARP_WSPATH"?ed=2048#${DISPLAY_NAME}vless(WARP)"
trlink=$(echo -e '\x74\x72\x6f\x6a\x61\x6e')"://"$UUID"@"$ARGO_URL":443?security=tls&type=ws&host="$ARGO_URL"&path="$TROJAN_WSPATH"?ed2048#${DISPLAY_NAME}trojan"
trlink_warp=$(echo -e '\x74\x72\x6f\x6a\x61\x6e')"://"$UUID"@"$ARGO_URL":443?security=tls&type=ws&host="$ARGO_URL"&path="$TROJAN_WARP_WSPATH"?ed2048#${DISPLAY_NAME}trojan(WARP)"

# 产生订阅
echo -e "$vmlink\n$vmlink_warp\n$vllink\n$vllink_warp\n$trlink\n$trlink_warp" | base64 -w 0 > /usr/share/nginx/html/$UUID.txt

qrencode -o /usr/share/nginx/html/M$UUID.png $vmlink
qrencode -o /usr/share/nginx/html/MW$UUID.png $vmlink_warp
qrencode -o /usr/share/nginx/html/L$UUID.png $vllink
qrencode -o /usr/share/nginx/html/LW$UUID.png $vllink_warp
qrencode -o /usr/share/nginx/html/T$UUID.png $trlink
qrencode -o /usr/share/nginx/html/TW$UUID.png $trlink_warp

HTML_PATH="/usr/share/nginx/html/$UUID.html"
VAR_NAMES=("${VAR_NAMES[@]}" "vmlink" "vmlink_warp" "vllink" "vllink_warp" "trlink" "trlink_warp")
cp template_webpage.html $HTML_PATH
perform_variable_substitution $HTML_PATH ${VAR_NAMES[@]}

echo $ARGO_URL

# WARP 优选IP
n=0
iplist=100
while true; do
	temp[$n]=$(echo 162.159.192.$(($RANDOM % 256)))
	n=$(($n + 1))
	if [ $n -ge $iplist ]; then
		break
	fi
	temp[$n]=$(echo 162.159.193.$(($RANDOM % 256)))
	n=$(($n + 1))
	if [ $n -ge $iplist ]; then
		break
	fi
	temp[$n]=$(echo 162.159.195.$(($RANDOM % 256)))
	n=$(($n + 1))
	if [ $n -ge $iplist ]; then
		break
	fi
	temp[$n]=$(echo 188.114.96.$(($RANDOM % 256)))
	n=$(($n + 1))
	if [ $n -ge $iplist ]; then
		break
	fi
	temp[$n]=$(echo 188.114.97.$(($RANDOM % 256)))
	n=$(($n + 1))
	if [ $n -ge $iplist ]; then
		break
	fi
	temp[$n]=$(echo 188.114.98.$(($RANDOM % 256)))
	n=$(($n + 1))
	if [ $n -ge $iplist ]; then
		break
	fi
	temp[$n]=$(echo 188.114.99.$(($RANDOM % 256)))
	n=$(($n + 1))
	if [ $n -ge $iplist ]; then
		break
	fi
done
while true; do
	if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
		break
	else
		temp[$n]=$(echo 162.159.192.$(($RANDOM % 256)))
		n=$(($n + 1))
	fi
	if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
		break
	else
		temp[$n]=$(echo 162.159.193.$(($RANDOM % 256)))
		n=$(($n + 1))
	fi
	if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
		break
	else
		temp[$n]=$(echo 162.159.195.$(($RANDOM % 256)))
		n=$(($n + 1))
	fi
	if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
		break
	else
		temp[$n]=$(echo 188.114.96.$(($RANDOM % 256)))
		n=$(($n + 1))
	fi
	if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
		break
	else
		temp[$n]=$(echo 188.114.97.$(($RANDOM % 256)))
		n=$(($n + 1))
	fi
	if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
		break
	else
		temp[$n]=$(echo 188.114.98.$(($RANDOM % 256)))
		n=$(($n + 1))
	fi
	if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
		break
	else
		temp[$n]=$(echo 188.114.99.$(($RANDOM % 256)))
		n=$(($n + 1))
	fi
done
echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u > ip.txt
chmod +x ./warp-yxip && ./warp-yxip
best_endpoint=$(cat result.csv | sed -n 2p | awk -F ',' '{print $1}')

nginx
base64 -d config > config.json
sed -i "s/engage.cloudflareclient.com:2408/${best_endpoint}/g" config.json
./$RELEASE_RANDOMNESS -config=config.json
