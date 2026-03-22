#!/bin/bash

export CONFIG="/etc/webyonet/webyonet-config.sh"
export APPDIR="/usr/local/bin/webyonet-bin"

if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG yapılandırma dosyası bulunamadı!"
    exit 1
fi

source "$CONFIG"

if [ -z "$WEB_SERVER" ]; then
    echo "❌ WEB_SERVER değişkeni config dosyasında tanımlı değil!"
    echo "Örnek: WEB_SERVER=\"apache\" veya WEB_SERVER=\"nginx\""
    exit 1
fi

if ! command -v certbot &> /dev/null; then
    echo "❌ Certbot kurulu değil. Kurmak için:"
    echo "   sudo apt install certbot"
    exit 1
fi

check_setup() {
    local config_dir="/etc/webyonet"
    local rclone_conf="$config_dir/rclone.conf"
    local mysql_conf="$config_dir/mysql-backup.cnf"
    
    # Dizin kontrolü
    if [ ! -d "$config_dir" ]; then
        echo "📂 Yapılandırma dizini oluşturuluyor: $config_dir"
        mkdir -p "$config_dir"
        chmod 755 "$config_dir"
    fi

    # webyonet-config.sh değişken kontrolü ve doldurma
    if [ -z "$WEB_SERVER" ] || [ -z "$SERVER_IP" ]; then
        echo "📝 Yapılandırma değişkenleri eksik. Lütfen aşağıdaki bilgileri girin:"
        
        [ -z "$WEB_SERVER" ] && read -p "Web Sunucusu (nginx/apache) [$WEB_SERVER]: " INPUT_WEB && WEB_SERVER=${INPUT_WEB:-$WEB_SERVER}
        [ -z "$SERVER_IP" ] && read -p "Sunucu IP Adresi [$SERVER_IP]: " INPUT_IP && SERVER_IP=${INPUT_IP:-$SERVER_IP}
        [ -z "$CF_DOMAIN" ] && read -p "Cloudflare Domain (Opsiyonel) [$CF_DOMAIN]: " INPUT_CF && CF_DOMAIN=${INPUT_CF:-$CF_DOMAIN}
        [ -z "$ClOUDFLARE_API_TOKEN" ] && read -p "Cloudflare API Token (Opsiyonel): " INPUT_CF_TOKEN && ClOUDFLARE_API_TOKEN=${INPUT_CF_TOKEN:-$ClOUDFLARE_API_TOKEN}
        [ -z "$CLOUDFLARE_ZONE_ID" ] && read -p "Cloudflare Zone ID (Opsiyonel): " INPUT_CF_ZONE && CLOUDFLARE_ZONE_ID=${INPUT_CF_ZONE:-$CLOUDFLARE_ZONE_ID}
        [ -z "$YANDEX_TOKEN" ] && read -p "Yandex Disk Token (Opsiyonel): " INPUT_YANDEX && YANDEX_TOKEN=${INPUT_YANDEX:-$YANDEX_TOKEN}

        # Dosyaya kaydet
        cat <<EOF > "$CONFIG"
#!/bin/bash
ClOUDFLARE_API_TOKEN="$ClOUDFLARE_API_TOKEN"
CLOUDFLARE_ZONE_ID="$CLOUDFLARE_ZONE_ID"
CF_DOMAIN="$CF_DOMAIN"
SERVER_IP="$SERVER_IP"
WEB_SERVER="$WEB_SERVER"
YANDEX_TOKEN="$YANDEX_TOKEN"
DB_NAMES=( "${DB_NAMES[@]}" )
EOF
        echo "✅ $CONFIG güncellendi."
        chmod 644 "$CONFIG"
    fi

    # rclone.conf kontrolü
    if [ ! -f "$rclone_conf" ]; then
        echo "🚀 rclone yapılandırması bulunamadı. Kurulum başlatılıyor..."
        rclone config --config "$rclone_conf"
    fi

    # mysql-backup.cnf kontrolü
    if [ ! -f "$mysql_conf" ]; then
        echo "🔑 MySQL yedekleme kullanıcısı bilgileri eksik."
        read -p "MySQL yedekleme kullanıcı adı [backup]: " DB_USER
        DB_USER=${DB_USER:-backup}
        read -s -p "MySQL yedekleme şifresi: " DB_PASS
        echo ""
        
        cat <<EOF > "$mysql_conf"
[client]
user=$DB_USER
password=$DB_PASS
host=localhost
EOF
        chmod 600 "$mysql_conf"
        echo "✅ $mysql_conf oluşturuldu (izinler 600 olarak ayarlandı)."
    fi
}

# Başlangıçta kurulumu kontrol et
check_setup

show_menu() {
    echo ""
    echo "🔧 Web Sitesi Yönetim Paneli"
    echo "1) Yeni site oluştur"
    echo "2) Geçici subdomain’i gerçek domain ile değiştir"
    echo "3) Siteyi sil"
    echo "4) Home dizin(leri)ni yedekle"
    echo "5) Veritabanlarını yedekle"
    echo "6) Wordpress veritabanlarını temizle ve optimize et"
    echo "7) Çıkış"
}

create_site() {
    bash $APPDIR/create_user_and_dirs.sh
    if [ "$WEB_SERVER" = "nginx" ]; then
        bash $APPDIR/set_nginx_conf.sh
    elif [ "$WEB_SERVER" = "apache" ]; then
        bash $APPDIR/set_apache_conf.sh
    else
        echo "❌ Desteklenmeyen web sunucusu: $WEB_SERVER"
        exit 1
    fi
    bash $APPDIR/last_steps.sh
}

change_domain() {
    if [ "$WEB_SERVER" = "nginx" ]; then
        bash $APPDIR/change_domain_nginx.sh
    else
        bash $APPDIR/change_domain.sh
    fi
}

delete_site() {
    bash $APPDIR/sitekaldir.sh
}

backup_home() {
    if [ -f $APPDIR/backup.py ]; then
        python3 $APPDIR/backup.py
    else
        echo "❌ $APPDIR/backup.py bulunamadı."
    fi
}

backup_db() {
    if [ -f $APPDIR/dbbackup.sh ]; then
        bash $APPDIR/dbbackup.sh
    else
        echo "❌ $APPDIR/dbbackup.sh bulunamadı."
    fi
}

clean_db() {
    if [ -f $APPDIR/wp-db-clean.sh ]; then
        bash $APPDIR/wp-db-clean.sh
    else
        echo "❌ $APPDIR/wp-db-clean.sh bulunamadı."
    fi
}

# Ana döngü
while true; do
    show_menu
    read -p "Seçiminiz [1-7]: " CHOICE
    case $CHOICE in
        1) create_site ;;
        2) change_domain ;;
        3) delete_site ;;
        4) backup_home ;;
        5) backup_db ;;
        6) clean_db ;;
        7) echo "👋 Görüşmek üzere."; break ;;
        *) echo "Geçersiz seçim!" ;;
    esac
done