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

# Üst dizinlerde Apache'nin erişebilmesi için +x izni
chmod +x /home/$USERNAME
chmod +x /home/$USERNAME/www

# Boş .htaccess oluştur
touch "$WEB_DIR/.htaccess"
chown $USERNAME:www-data "$WEB_DIR/.htaccess"

# Apache yapılandırması (HTTP için)
VHOST_FILE="/etc/apache2/sites-available/$SUBDOMAIN.conf"
cat <<EOF > "$VHOST_FILE"
<VirtualHost *:80>
    ServerName $SUBDOMAIN
    DocumentRoot $WEB_DIR
    <Directory $WEB_DIR>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$SUBDOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$SUBDOMAIN-access.log combined
</VirtualHost>
EOF

# Siteyi etkinleştir
a2ensite "$SUBDOMAIN" > /dev/null
systemctl reload apache2

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
echo "  sudo certbot --apache -d $SUBDOMAIN"

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

