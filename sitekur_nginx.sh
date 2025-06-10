#!/bin/bash


# Kullanıcıdan domain ve kullanıcı adı alınır
read -p "Site için domain adı girin (örn: gencbilisim.net): " DOMAIN
read -p "Yeni sistem kullanıcı adı girin: " USERNAME

# Domain geçerli mi kontrol et (A kaydı var mı?)
if ! host "$DOMAIN" > /dev/null 2>&1; then
    echo "❌ $DOMAIN için DNS kaydı bulunamadı."
    echo "Geçici alt domain oluşturulacak: ${DOMAIN%%.*}.$CF_DOMAIN"
    SUBDOMAIN="${DOMAIN%%.*}.$CF_DOMAIN"
else
    echo "✅ $DOMAIN için DNS kaydı bulundu."
    SUBDOMAIN="$DOMAIN"
fi

# Kullanıcı oluştur (parolasız, sadece SSH key ile)
useradd -m -s /bin/bash "$USERNAME"
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
ssh-keygen -q -t rsa -b 2048 -N "" -f /home/$USERNAME/.ssh/id_rsa <<<y 2>/dev/null
cat /home/$USERNAME/.ssh/id_rsa.pub > /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

# Web dizinini oluştur
WEB_DIR="/home/$USERNAME/www/$SUBDOMAIN/public_html"
mkdir -p "$WEB_DIR"
chown -R $USERNAME:www-data "$WEB_DIR"
chmod -R 775 "$WEB_DIR"

# Üst dizinlerde Nginx'in erişebilmesi için +x izni
chmod +x /home/$USERNAME
chmod +x /home/$USERNAME/www

# Nginx yapılandırması (HTTP için)
VHOST_FILE="/etc/nginx/sites-available/$SUBDOMAIN"
cat <<EOF > "$VHOST_FILE"
server {
    listen 80;
    server_name $SUBDOMAIN;
    root $WEB_DIR;

    index index.php index.html index.htm;

    client_max_body_size 10M;

    access_log /var/log/nginx/${SUBDOMAIN}-access.log;
    error_log /var/log/nginx/${SUBDOMAIN}-error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
    

    # Güvenlik başlıkları
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=()" always;
}
EOF

# Siteyi etkinleştir
ln -s "$VHOST_FILE" /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Eğer geçici subdomain kullanılıyorsa, Cloudflare DNS kaydı oluştur
if [[ "$SUBDOMAIN" != "$DOMAIN" ]]; then
    echo "☁ Cloudflare'da geçici DNS kaydı oluşturuluyor: $SUBDOMAIN -> $SERVER_IP"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{
          "type": "A",
          "name": "'$SUBDOMAIN'",
          "content": "'$SERVER_IP'",
          "ttl": 120,
          "proxied": false
        }' > /dev/null
    echo "✅ DNS kaydı oluşturuldu."
fi

# Kullanıcıya HTTPS sertifikasını nasıl alacağını göster
echo ""
echo "🚨 HTTPS henüz etkin değil. Sertifika kurmak için şu komutu kullanabilirsiniz:"
echo "  sudo certbot --nginx -d $SUBDOMAIN"

# SSH private key dosyasını göster
echo ""
echo "🔑 SSH bağlantısı için private key:"
cat /home/$USERNAME/.ssh/id_rsa

# WordPress kurulumu seçeneği
read -p "📦 WordPress kurulumu yapılsın mı? (e/h): " INSTALL_WP

if [[ "$INSTALL_WP" == "e" || "$INSTALL_WP" == "E" ]]; then
    echo "📥 WordPress indiriliyor..."
    wget -q https://tr.wordpress.org/latest-tr_TR.zip -O /tmp/wordpress.zip
    unzip -q /tmp/wordpress.zip -d /tmp
    mv /tmp/wordpress/* "$WEB_DIR"
    chown -R $USERNAME:www-data "$WEB_DIR"
    chmod -R 775 "$WEB_DIR"
    echo "✅ WordPress dosyaları yüklendi. Kurulum sihirbazı için şu adresi ziyaret edin:"
    echo "👉 http://$SUBDOMAIN"
else
    echo "⏭ WordPress kurulumu atlandı."
fi

echo ""
echo "✅ Site kurulumu tamamlandı: http://$SUBDOMAIN"