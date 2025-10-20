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

# A kaydını al ve sunucu IP'si ile karşılaştır (sadece IPv4)
if [ -n "$SERVER_IP" ]; then
    # host veya dig ile A kayıtlarını al
    if command -v dig &>/dev/null; then
        DNS_IPS=$(dig +short A "$DOMAIN" | tr '\n' ' ')
    else
        DNS_IPS=$(host -t A "$DOMAIN" 2>/dev/null | awk '/has address/ {print $4}' | tr '\n' ' ')
    fi

    if [ -z "$DNS_IPS" ]; then
        echo "❌ $DOMAIN için A kaydı bulunamadı; işlem iptal ediliyor."
        exit 1
    fi

    # DNS_IPS içinde SERVER_IP var mı kontrol et
    match=0
    for ip in $DNS_IPS; do
        if [ "$ip" = "$SERVER_IP" ]; then
            match=1
            break
        fi
    done

    if [ $match -ne 1 ]; then
        echo "❌ DNS'deki A kaydı ($DNS_IPS) sunucu IP'si ($SERVER_IP) ile eşleşmiyor. İşlem iptal edildi."
        exit 1
    else
        echo "✅ DNS A kaydı sunucu IP'si ile eşleşiyor. Devam ediliyor."
    fi
else
    echo "⚠️ SERVER_IP config'de tanımlı değil; DNS-IP kontrolü atlanıyor."
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