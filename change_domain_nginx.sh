#!/bin/bash

# Geçici subdomain'i gerçek domain ile değiştirme scripti (Nginx için)

read -p "Kullanıcı adı: " USERNAME
read -p "Eski (geçici) domain adı: " OLD_DOMAIN
read -p "Yeni domain adı (gerçek domain): " NEW_DOMAIN

OLD_DIR="/home/$USERNAME/www/$OLD_DOMAIN"
NEW_DIR="/home/$USERNAME/www/$NEW_DOMAIN"

if [ ! -d "$OLD_DIR" ]; then
    echo "❌ $OLD_DOMAIN dizini bulunamadı."
    exit 1
fi

# Nginx eski vhost dosyasını sil
rm -f "/etc/nginx/sites-enabled/$OLD_DOMAIN"
rm -f "/etc/nginx/sites-available/$OLD_DOMAIN"

# Yeni dizini oluştur ve dosyaları taşı
mkdir -p "$NEW_DIR"
mv "$OLD_DIR"/* "$NEW_DIR"
rmdir "$OLD_DIR"

# Nginx yeni vhost yapılandırması oluştur
VHOST_FILE="/etc/nginx/sites-available/$NEW_DOMAIN"
cat <<EOF > "$VHOST_FILE"
server {
    listen 80;
    server_name $NEW_DOMAIN;
    root $NEW_DIR/public_html;

    index index.php index.html index.htm;

    client_max_body_size 10M;

    access_log /var/log/nginx/${NEW_DOMAIN}-access.log;
    error_log /var/log/nginx/${NEW_DOMAIN}-error.log;

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

ln -s "$VHOST_FILE" /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "🔁 Domain güncellendi: $OLD_DOMAIN → $NEW_DOMAIN"
echo "🌐 http://$NEW_DOMAIN adresinden erişebilirsiniz."

echo "🎯 HTTPS kurmak için:"
echo "  sudo certbot --nginx -d $NEW_DOMAIN"