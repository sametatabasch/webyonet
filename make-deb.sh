#!/bin/bash

# === AYARLAR ===
APP_NAME="webyonet"
VERSION="2.0.2"
ARCH="all"
MAINTAINER="Samet ATABAŞ <admin@gencbilisim.net>"

# === GEÇİCİ YAPIYI OLUŞTUR ===
echo "📦 Debian paketi hazırlanıyor..."

BUILD_DIR="$PWD/${APP_NAME}_build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/local/bin"
mkdir -p "$BUILD_DIR/usr/local/lib/$APP_NAME/templates"
mkdir -p "$BUILD_DIR/etc/$APP_NAME"

# === KONTROL DOSYASI ===
cat <<EOF > "$BUILD_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $VERSION
Section: admin
Priority: optional
Architecture: $ARCH
Depends: python3 (>= 3.10), python3-yaml, python3-requests, rclone, curl, jq, unzip, pv
Maintainer: $MAINTAINER
Description: Python tabanlı web siteleri yönetmek için terminal aracı
 Basit bir arayüz ile Nginx/Apache VirtualHost oluşturur, WordPress kurar,
 otomatik SSL sertifikası alır, Cloudflare DNS yönetimi yapar ve bulut
 yedekleme işlemlerini gerçekleştirir.
EOF

# === ÖRNEK CONFIG'İ /etc/webyonet/ İÇİNE KOPYALA ===
if [ -f "config/webyonet.yaml.example" ]; then
    cp "config/webyonet.yaml.example" "$BUILD_DIR/etc/$APP_NAME/webyonet.yaml"
else
    echo "❌ config/webyonet.yaml.example bulunamadı."
    exit 1
fi

# === CONFFILES DOSYASI ===
echo "/etc/$APP_NAME/webyonet.yaml" > "$BUILD_DIR/DEBIAN/conffiles"

# === postinst (kurulum sonrası) ===
cat <<'EOF' > "$BUILD_DIR/DEBIAN/postinst"
#!/bin/bash
set -e
# Yapılandırma dizininin varlığını garanti et
mkdir -p /etc/webyonet
# Eğer config yoksa örnek dosyayı kopyala
if [ ! -f /etc/webyonet/webyonet.yaml ]; then
    if [ -f /usr/local/lib/webyonet/config/webyonet.yaml.example ]; then
        cp /usr/local/lib/webyonet/config/webyonet.yaml.example /etc/webyonet/webyonet.yaml
        chmod 644 /etc/webyonet/webyonet.yaml
        echo "📝 Örnek yapılandırma /etc/webyonet/webyonet.yaml olarak kopyalandı."
        echo "   Lütfen düzenleyin: sudo nano /etc/webyonet/webyonet.yaml"
    fi
fi
echo "✅ webyonet kurulumu tamamlandı."
echo "   Kullanım: sudo webyonet"
echo "   Kurulum sihirbazı: sudo webyonet --setup"
EOF
chmod 755 "$BUILD_DIR/DEBIAN/postinst"

# === BIN WRAPPER (CLI giriş noktası) ===
cp ./bin/webyonet "$BUILD_DIR/usr/local/bin/webyonet"
if [ ! -f "$BUILD_DIR/usr/local/bin/webyonet" ]; then
    echo "❌ bin/webyonet dosyası bulunamadı."
    exit 1
fi
chmod +x "$BUILD_DIR/usr/local/bin/webyonet"

# === PYTHON PAKET DOSYALARINI KOPYALA ===
PYTHON_FILES=(
    "__init__.py"
    "__main__.py"
    "cli.py"
    "config.py"
    "logger.py"
    "utils.py"
    "cloudflare.py"
    "webserver.py"
    "site_manager.py"
    "backup.py"
    "db_backup.py"
    "wp_db_clean.py"
)

for FILE in "${PYTHON_FILES[@]}"; do
    SRC="webyonet/$FILE"
    if [ ! -f "$SRC" ]; then
        echo "❌ $SRC bulunamadı."
        exit 1
    fi
    cp "$SRC" "$BUILD_DIR/usr/local/lib/$APP_NAME/"
done

# === ŞABLON DOSYALARINI KOPYALA ===
TEMPLATE_FILES=("nginx_site.conf" "apache_site.conf")

for FILE in "${TEMPLATE_FILES[@]}"; do
    SRC="webyonet/templates/$FILE"
    if [ ! -f "$SRC" ]; then
        echo "❌ $SRC bulunamadı."
        exit 1
    fi
    cp "$SRC" "$BUILD_DIR/usr/local/lib/$APP_NAME/templates/"
done

# === ÖRNEK CONFIG DOSYASINI KOPYALA ===
mkdir -p "$BUILD_DIR/usr/local/lib/$APP_NAME/config"
if [ -f "config/webyonet.yaml.example" ]; then
    cp "config/webyonet.yaml.example" "$BUILD_DIR/usr/local/lib/$APP_NAME/config/"
fi

# === DEB OLUŞTUR ===
dpkg-deb --build "$BUILD_DIR" > /dev/null

# === SONUÇ ===
mv "${BUILD_DIR}.deb" "./$APP_NAME-${VERSION}.deb"
rm -rf "$BUILD_DIR"

echo "✅ Paket hazır: $APP_NAME-${VERSION}.deb"
echo "   Kurulum: sudo dpkg -i $APP_NAME-${VERSION}.deb"
echo "   Bağımlılıklar: sudo apt install -f"