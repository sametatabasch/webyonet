#!/bin/bash
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