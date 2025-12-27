#!/bin/bash

# 1. Pembersihan Sesi Sebelumnya (Menggunakan Path Absolut)
USER_HOME=$HOME
VPN_DIR="$USER_HOME/vpn"

echo "Membersihkan proses lama..."
pkill -f xray
pkill -f cloudflared
rm -rf "$VPN_DIR"
mkdir -p "$VPN_DIR" && cd "$VPN_DIR"

# 2. Download Xray Core
echo "Mendownload Xray Core..."
wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -q Xray-linux-64.zip
chmod +x "$VPN_DIR/xray"
rm Xray-linux-64.zip

# 3. Download Cloudflared
echo "Mendownload Cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x "$VPN_DIR/cloudflared-linux-amd64"

# 4. Generate UUID dan Buat Config Xray
MY_UUID=$("$VPN_DIR/xray" uuid)
cat <<EOF > "$VPN_DIR/config.json"
{
    "log": {
        "loglevel": "none"
    },
    "inbounds": [{
        "port": 8100,
        "listen": "127.0.0.1",
        "protocol": "vless",
        "settings": {
            "clients": [{
                "id": "$MY_UUID",
                "level": 0
            }],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {
                "path": "/vless"
            },
            "sockopt": {
                "tcpFastOpen": true
            }
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "settings": {
            "domainStrategy": "UseIP"
        },
        "streamSettings": {
            "sockopt": {
                "tcpFastOpen": true
            }
        }
    }]
}
EOF

# 5. Menjalankan Xray di Background (Path Absolut)
echo "Menjalankan Xray..."
nohup "$VPN_DIR/xray" run -c "$VPN_DIR/config.json" > "$VPN_DIR/xray.log" 2>&1 &

# 6. Menjalankan Cloudflared Tunnel di Background (Path Absolut)
echo "Menghubungkan ke Cloudflare Tunnel (Mohon tunggu)..."
nohup "$VPN_DIR/cloudflared-linux-amd64" tunnel --url http://127.0.0.1:8100 > "$VPN_DIR/tunnel.log" 2>&1 &

# 7. Proses Pengambilan Link
MAX_RETRIES=15
COUNT=0
TUNNEL_URL=""

while [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 3
    TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' "$VPN_DIR/tunnel.log" | head -n 1 | sed 's/https:\/\///')
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
    ((COUNT++))
    echo "Sedang menjemput link tunnel ($COUNT/$MAX_RETRIES)..."
done

# 8. Output Akhir
echo -e "\n=================================================="
if [ -z "$TUNNEL_URL" ]; then
    echo "Gagal mendapatkan link tunnel secara otomatis."
else
    VLESS_LINK="vless://$MY_UUID@$TUNNEL_URL:443?encryption=none&security=tls&type=ws&host=$TUNNEL_URL&path=%2Fvless&sni=$TUNNEL_URL#Vless-Optimized"
    echo "INSTALASI BERHASIL!"
    echo "--------------------------------------------------"
    echo "UUID       : $MY_UUID"
    echo "DOMAIN     : $TUNNEL_URL"
    echo "--------------------------------------------------"
    echo "SALIN LINK VLESS DI BAWAH INI:"
    echo -e "\033[0;32m$VLESS_LINK\033[0m"
    echo "--------------------------------------------------"
fi
echo "Gunakan 'disown -a && exit' untuk keluar dari SSH."
echo "=================================================="
