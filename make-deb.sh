#!/bin/bash

# === AYARLAR ===
APP_NAME="webyonet"
VERSION="1.2.2"
ARCH="all"
MAINTAINER="Samet ATABAŞ <admin@gencbilisim.net>"

# === GEÇİCİ YAPIYI OLUŞTUR ===
echo "📦 Debian paketi hazırlanıyor..."

BUILD_DIR="$PWD/${APP_NAME}_build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/local/bin/$APP_NAME-bin"
mkdir -p "$BUILD_DIR/etc/$APP_NAME"

# === KONTROL DOSYASI ===
cat <<EOF > "$BUILD_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $VERSION
Section: admin
Priority: optional
Architecture: $ARCH
Depends: bash, curl, apache2, jq, unzip, pv, rclone
Maintainer: $MAINTAINER
Description: Apache tabanlı web siteleri yönetmek için terminal aracı
 Basit bir arayüz ile Apache VirtualHost oluşturur, WordPress kurar, geçici subdomain atar.
EOF

# === ANA ÇALIŞTIRICI (webyonet komutu) ===
cp ./webyonet "$BUILD_DIR/usr/local/bin/webyonet"
if [ ! -f "$BUILD_DIR/usr/local/bin/webyonet" ]; then
  echo "❌ webyonet dosyası bulunamadı."
  exit 1
fi

chmod +x "$BUILD_DIR/usr/local/bin/webyonet"

# === WEBYONET DOSYALARINI KOPYALA ===
REQUIRED_FILES=("sitekur.sh" "sitekaldir.sh" "sitekur-config.sh" "webyonet_menu.sh" "change_domain.sh" "backupToYandex.sh")

for FILE in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$FILE" ]; then
    echo "❌ $FILE bulunamadı. Aynı klasörde olmalı."
    exit 1
  fi
  cp "$FILE" "$BUILD_DIR/usr/local/bin/$APP_NAME-bin/"
done

chmod +x "$BUILD_DIR/usr/local/bin/$APP_NAME-bin/"*.sh

# === config dosyasını /etc/webyonet/webyonet-config.sh adresine kaydet ===
if [ ! -f "webyonet-config.sh" ]; then
  echo "❌ webyonet-config.sh bulunamadı."
  exit 1
fi
cp "webyonet-config.sh" "$BUILD_DIR/etc/$APP_NAME/webyonet-config.sh"

# === DEB OLUŞTUR ===
dpkg-deb --build "$BUILD_DIR" > /dev/null

# === SONUÇ ===
mv "${BUILD_DIR}.deb" "./$APP_NAME-${VERSION}.deb"
rm -rf "$BUILD_DIR"

echo "✅ Paket hazır: $APP_NAME-${VERSION}.deb"
