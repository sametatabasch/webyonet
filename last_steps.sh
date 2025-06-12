#!/bin/bash

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

# Otomatik HTTPS sertifikası al ve etkinleştir
echo ""
echo "🔒 HTTPS sertifikası alınıyor ve etkinleştiriliyor..."
if certbot --nginx -d "$SUBDOMAIN" --non-interactive --agree-tos -m admin@$SUBDOMAIN --redirect; then
    echo "✅ HTTPS aktif edildi: https://$SUBDOMAIN"
else
    echo "❌ HTTPS sertifikası alınamadı. Manuel olarak deneyebilirsiniz:"
    echo "  sudo certbot --nginx -d $SUBDOMAIN"
fi

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
    echo "👉 https://$SUBDOMAIN"
else
    echo "⏭ WordPress kurulumu atlandı."
fi

echo ""
echo "✅ Site kurulumu tamamlandı: https://$SUBDOMAIN"