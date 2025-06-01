#!/bin/bash
# Geçici subdomain'i gerçek domain ile değiştirme scripti
# Bu script, Apache üzerinde geçici bir subdomain'i gerçek bir domain ile değiştirir.
# Gereksinimler:
# - Apache web sunucusu
# - Certbot (HTTPS için)
read -p "Kullanıcı adı: " USERNAME
    read -p "Eski (geçici) domain adı: " OLD_DOMAIN
    read -p "Yeni domain adı (gerçek domain): " NEW_DOMAIN

    OLD_DIR="/home/$USERNAME/www/$OLD_DOMAIN"
    NEW_DIR="/home/$USERNAME/www/$NEW_DOMAIN"

    if [ ! -d "$OLD_DIR" ]; then
        echo "❌ $OLD_DOMAIN dizini bulunamadı."
        return
    fi

    # Apache eski vhost'u devre dışı bırak
    a2dissite "$OLD_DOMAIN" >/dev/null
    rm -f "/etc/apache2/sites-available/$OLD_DOMAIN.conf"

    # Apache yeni vhost yapılandırması oluştur
    mkdir -p "$NEW_DIR"
    mv "$OLD_DIR"/* "$NEW_DIR"
    rmdir "$OLD_DIR"

    VHOST_FILE="/etc/apache2/sites-available/$NEW_DOMAIN.conf"
    cat <<EOF > "$VHOST_FILE"
<VirtualHost *:80>
    ServerName $NEW_DOMAIN
    DocumentRoot $NEW_DIR/public_html
    <Directory $NEW_DIR/public_html>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$NEW_DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$NEW_DOMAIN-access.log combined
</VirtualHost>
EOF

    a2ensite "$NEW_DOMAIN" >/dev/null
    systemctl reload apache2

    echo "🔁 Domain güncellendi: $OLD_DOMAIN → $NEW_DOMAIN"
    echo "🌐 http://$NEW_DOMAIN adresinden erişebilirsiniz."

    echo "🎯 HTTPS kurmak için:"
    echo "  sudo certbot --apache -d $NEW_DOMAIN"