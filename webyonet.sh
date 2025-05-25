#!/bin/bash

CONFIG="./sitekur-config.sh"

if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG yapılandırma dosyası bulunamadı!"
    exit 1
fi

source "$CONFIG"

if ! command -v certbot &> /dev/null; then
    echo "❌ Certbot kurulu değil. Kurmak için:"
    echo "   sudo apt install certbot"
    exit 1
fi

show_menu() {
    echo ""
    echo "🔧 Web Sitesi Yönetim Paneli"
    echo "1) Yeni site oluştur"
    echo "2) Geçici subdomain’i gerçek domain ile değiştir"
    echo "3) Siteyi sil"
    echo "4) Çıkış"
}

create_site() {
    bash ./sitekur.sh
}

change_domain() {
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
    DocumentRoot $NEW_DIR
    <Directory $NEW_DIR>
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
}

delete_site() {
    bash ./sitekaldir.sh
}

# Ana döngü
while true; do
    show_menu
    read -p "Seçiminiz [1-4]: " CHOICE
    case $CHOICE in
        1) create_site ;;
        2) change_domain ;;
        3) delete_site ;;
        4) echo "👋 Görüşmek üzere."; break ;;
        *) echo "Geçersiz seçim!" ;;
    esac
done
