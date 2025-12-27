#!/bin/bash

# --- KONFIGURASI TELEGRAM (SUDAH TERISI) ---
TOKEN="7484227045:AAENQc5Dp8_Nno8Oarl79IfAZZtbg4eIQC0"
CHAT_ID="5026145251"
# ----------------------------

# 1. Cek apakah proses cloudflared masih berjalan
if pgrep -f "cloudflared-linux-amd64" > /dev/null
then
    echo "VPN masih berjalan dengan baik."
else
    echo "VPN terdeteksi mati! Memulai proses pemulihan..."
    
    # 2. Pembersihan proses lama dan folder
    pkill -f xray
    pkill -f cloudflared
    rm -rf ~/vpn
    mkdir -p ~/vpn && cd ~/vpn

    # 3. Download Xray dan Cloudflared
    echo "Mendownload komponen terbaru..."
    wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    unzip -q Xray-linux-64.zip
    chmod +x xray
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared-linux-amd64

    # 4. Generate UUID dan Config Xray
    MY_UUID=$(./xray uuid)
    cat <<EOF > config.json
{
    "inbounds": [{
        "port": 8100,
        "listen": "127.0.0.1",
        "protocol": "vless",
        "settings": {
            "clients": [{"id": "$MY_UUID"}],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "/vless"}
        }
    }],
    "outbounds": [{"protocol": "freedom"}]
}
EOF

    # 5. Jalankan layanan
    nohup ./xray run -c config.json > xray.log 2>&1 &
    nohup ./cloudflared-linux-amd64 tunnel --url http://127.0.0.1:8100 > tunnel.log 2>&1 &

    # 6. Menunggu Link Cloudflare
    echo "Menunggu link tunnel..."
    sleep 25
    TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' tunnel.log | head -n 1 | sed 's/https:\/\///')

    if [ -n "$TUNNEL_URL" ]; then
        # Menyusun Link VLESS lengkap
        VLESS_LINK="vless://$MY_UUID@$TUNNEL_URL:443?encryption=none&security=tls&type=ws&host=$TUNNEL_URL&path=%2Fvless&sni=$TUNNEL_URL#Alwaysdata-Bot"
        
        # 7. Membuat Pesan Rapi dengan Baris Baru Nyata
        PESAN="⚠️ <b>VPN RESTARTED</b> ⚠️

<i>Klik link di bawah untuk salin:</i>

<code>$VLESS_LINK</code>

Status: <b>Online</b>"
        
        # 8. Kirim ke Telegram (Mode Aman)
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
             --data-urlencode "chat_id=$CHAT_ID" \
             --data-urlencode "text=$PESAN" \
             --data-urlencode "parse_mode=HTML"
        
        echo -e "\nSelesai! Link rapi telah dikirim ke Telegram."
    else
        echo "Gagal mendapatkan link tunnel."
    fi
fi
