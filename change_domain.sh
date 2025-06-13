#!/bin/bash
# Geçici subdomain'i gerçek domain ile değiştirme scripti
export CONFIG="/etc/webyonet/webyonet-config.sh"
export APPDIR="/usr/local/bin/webyonet-bin"

if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG yapılandırma dosyası bulunamadı!"
    exit 1
fi

source "$CONFIG"

read -p "Kullanıcı adı: " USERNAME
read -p "Eski (geçici) domain adı: " OLD_DOMAIN
read -p "Yeni domain adı (gerçek domain): " NEW_DOMAIN

OLD_DIR="/home/$USERNAME/www/$OLD_DOMAIN"
NEW_DIR="/home/$USERNAME/www/$NEW_DOMAIN"

if [ ! -d "$OLD_DIR" ]; then
    echo "❌ $OLD_DOMAIN dizini bulunamadı."
    return
fi

shopt -s dotglob
mkdir -p "$NEW_DIR"
mv "$OLD_DIR"/* "$NEW_DIR"
rmdir "$OLD_DIR"
shopt -u dotglob

# Çıktıları /tmp/webyonet_env dosyasına yaz
echo "DOMAIN=\"$NEW_DOMAIN\"" > /tmp/webyonet_env
echo "USERNAME=\"$USERNAME\"" >> /tmp/webyonet_env
echo "SUBDOMAIN=\"$NEW_DOMAIN\"" >> /tmp/webyonet_env
echo "WEB_DIR=\"$NEW_DIR\"" >> /tmp/webyonet_env

if [ "$WEB_SERVER" = "nginx" ]; then
    # Nginx eski vhost dosyasını sil
    rm -f "/etc/nginx/sites-enabled/$OLD_DOMAIN"
    rm -f "/etc/nginx/sites-available/$OLD_DOMAIN"

    bash $APPDIR/set_nginx_conf.sh
elif [ "$WEB_SERVER" = "apache" ]; then
    # Apache eski vhost'u devre dışı bırak
    a2dissite "$OLD_DOMAIN" >/dev/null
    rm -f "/etc/apache2/sites-available/$OLD_DOMAIN.conf"

    bash $APPDIR/set_apache_conf.sh
else
    echo "❌ Desteklenmeyen web sunucusu: $WEB_SERVER"
    exit 1
fi

echo "🔁 Domain güncellendi: $OLD_DOMAIN → $NEW_DOMAIN"
echo "🌐 http://$NEW_DOMAIN adresinden erişebilirsiniz."

echo "🎯 HTTPS kurmak için:"
echo "  sudo certbot --apache -d $NEW_DOMAIN"