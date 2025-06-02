#!/bin/bash

CONFIG="/etc/webyonet/webyonet-config.sh"
APPDIR="/usr/local/bin/webyonet"

if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG yapılandırma dosyası bulunamadı!"
    exit 1
fi

source "$CONFIG"

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
    bash $APPDIR/sitekur.sh
}

change_domain() {
    bash $APPDIR/change_domain.sh
}

delete_site() {
    bash $APPDIR/sitekaldir.sh
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
