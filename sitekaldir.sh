#!/bin/bash

read -p "Kullanıcı adı: " username
read -p "Silinecek domain (örn: gencbilisim.net): " domain

basedir="/home/$username/www"
sitedir="$basedir/$domain"
apache_conf="/etc/apache2/sites-available/$domain.conf"


# Domain alt alan adı mıydı?
cloudflare_name="$domain"

# Apache site kaldır
if [ -f "$apache_conf" ]; then
    echo "[✓] Apache yapılandırması kaldırılıyor..."
    a2dissite "$domain.conf" >/dev/null 2>&1
    rm -f "$apache_conf"
    rm -f "/etc/apache2/sites-enabled/$domain.conf"
    systemctl reload apache2
else
    echo "[!] Apache yapılandırması bulunamadı."
fi

# Let's Encrypt sertifikasını kaldır
if certbot certificates | grep -q "Certificate Name: $domain"; then
    echo "[✓] SSL sertifikası siliniyor..."
    certbot revoke --cert-name "$domain" --non-interactive --quiet --delete-after-revoke
    certbot delete --cert-name "$domain" --non-interactive --quiet
else
    echo "[!] SSL sertifikası bulunamadı."
fi

# Web dizinini kaldır
if [ -d "$sitedir" ]; then
    echo "[✓] Web dizini siliniyor: $sitedir"
    rm -rf "$sitedir"
else
    echo "[!] Web dizini bulunamadı: $sitedir"
fi

# Cloudflare DNS kaydını sil
echo "[✓] Cloudflare DNS kaydı siliniyor..."
record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=$cloudflare_name" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

if [ "$record_id" != "null" ]; then
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$record_id" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" >/dev/null
    echo "[✓] Cloudflare DNS kaydı silindi: $cloudflare_name"
else
    echo "[!] Cloudflare DNS kaydı bulunamadı: $cloudflare_name"
fi

# Kullanıcının başka sitesi var mı?
if [ -d "$basedir" ]; then
    site_count=$(find "$basedir" -mindepth 1 -maxdepth 1 -type d | wc -l)
else
    site_count=0
fi

# Kullanıcıyı sil (hiç site kalmadıysa)
if [ "$site_count" -eq 0 ]; then
    echo "[✓] Kullanıcının başka sitesi kalmadı. Kullanıcı siliniyor..."
    deluser --remove-home "$username"
else
    echo "[i] Kullanıcının başka sitesi var. Kullanıcı silinmedi."
fi
