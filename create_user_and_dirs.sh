#!/bin/bash
if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG yapılandırma dosyası bulunamadı!"
    exit 1
fi

source "$CONFIG"
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

# Kullanıcı zaten var mı kontrol et
if id "$USERNAME" &>/dev/null; then
    echo "ℹ️ $USERNAME adlı kullanıcı zaten mevcut, oluşturma adımı atlanıyor."
else
    # Kullanıcı oluştur (parolasız, sadece SSH key ile)
    useradd -m -s /bin/bash "$USERNAME"
    mkdir -p /home/$USERNAME/.ssh
    chmod 700 /home/$USERNAME/.ssh
    ssh-keygen -q -t rsa -b 2048 -N "" -f /home/$USERNAME/.ssh/id_rsa <<<y 2>/dev/null
    cat /home/$USERNAME/.ssh/id_rsa.pub > /home/$USERNAME/.ssh/authorized_keys
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
fi

# Web dizinini oluştur
WEB_DIR="/home/$USERNAME/www/$SUBDOMAIN/public_html"
mkdir -p "$WEB_DIR"
chown -R $USERNAME:www-data "$WEB_DIR"
chmod -R 775 "$WEB_DIR"

# Üst dizinlerde WEb server'in erişebilmesi için +x izni
chmod +x /home/$USERNAME
chmod +x /home/$USERNAME/www

# Çıktıları /tmp/webyonet_env dosyasına yaz
echo "DOMAIN=\"$DOMAIN\"" > /tmp/webyonet_env
echo "USERNAME=\"$USERNAME\"" >> /tmp/webyonet_env
echo "SUBDOMAIN=\"$SUBDOMAIN\"" >> /tmp/webyonet_env
echo "WEB_DIR=\"$WEB_DIR\"" >> /tmp/webyonet_env