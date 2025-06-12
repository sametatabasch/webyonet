#!/bin/bash

# Gerekli değişkenler önceden tanımlı olmalı: $SUBDOMAIN, $WEB_DIR, $DOMAIN, $SERVER_IP, $CLOUDFLARE_ZONE_ID, $CLOUDFLARE_API_TOKEN, $USERNAME

NGINX_CONF_TEMPLATE="/usr/local/bin/webyonet-bin/nginx_site.conf"
VHOST_FILE="/etc/nginx/sites-available/$SUBDOMAIN.conf"

if [ ! -f "$NGINX_CONF_TEMPLATE" ]; then
    echo "❌ nginx_site.conf şablonu bulunamadı: $NGINX_CONF_TEMPLATE"
    exit 1
fi

# Şablonu değişkenlerle doldur ve vhost dosyasına yaz
sed "s/SUBDOMAIN/$SUBDOMAIN/g; s/WEB_DIR/$(echo $WEB_DIR | sed 's_/_\\/_g')/g" "$NGINX_CONF_TEMPLATE" > "$VHOST_FILE"

# Siteyi etkinleştir
ln -sf "$VHOST_FILE" "/etc/nginx/sites-enabled/$SUBDOMAIN.conf"
nginx -t && systemctl reload nginx