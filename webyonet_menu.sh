#!/bin/bash

CONFIG="/etc/webyonet/webyonet-config.sh"
APPDIR="/usr/local/bin/webyonet-bin"

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

show_menu() {
    echo ""
    echo "🔧 Web Sitesi Yönetim Paneli"
    echo "1) Yeni site oluştur"
    echo "2) Geçici subdomain’i gerçek domain ile değiştir"
    echo "3) Siteyi sil"
    echo "4) Çıkış"
}

create_site() {
    if [ "$WEB_SERVER" = "nginx" ]; then
        bash $APPDIR/sitekur_nginx.sh
    else
        bash $APPDIR/sitekur.sh
    fi
}

change_domain() {
    if [ "$WEB_SERVER" = "nginx" ]; then
        bash $APPDIR/change_domain_nginx.sh
    else
        bash $APPDIR/change_domain.sh
    fi
}

delete_site() {
    if [ "$WEB_SERVER" = "nginx" ]; then
        bash $APPDIR/sitekaldir_nginx.sh
    else
        bash $APPDIR/sitekaldir.sh
    fi
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