#!/bin/bash
# Değişkenlerin sonraki scriptlerde kullanılabilmesi için export ediliyor
export DOMAIN
export USERNAME
export SUBDOMAIN
export WEB_DIR
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

# Üst dizinlerde WEb server'in erişebilmesi için +x izni
chmod +x /home/$USERNAME
chmod +x /home/$USERNAME/www