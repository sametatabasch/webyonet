#!/bin/bash

# === AYARLAR ===
APP_NAME="webyonet"
VERSION="1.0"
ARCH="all"
MAINTAINER="Senin Adın <admin@gencbilisim.net>"

# === GEÇİCİ YAPIYI OLUŞTUR ===
echo "📦 Debian paketi hazırlanıyor..."

BUILD_DIR="$PWD/${APP_NAME}_build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/local/bin"
mkdir -p "$BUILD_DIR/etc/$APP_NAME"

# === KONTROL DOSYASI ===
cat <<EOF > "$BUILD_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $VERSION
Section: admin
Priority: optional
Architecture: $ARCH
Depends: bash, curl, apache2, certbot, jq, unzip
Maintainer: $MAINTAINER
Description: Apache tabanlı web siteleri yönetmek için terminal aracı
 Basit bir arayüz ile Apache VirtualHost oluşturur, WordPress kurar, geçici subdomain atar.
EOF

# === ANA ÇALIŞTIRICI (webyonet komutu) ===
cat <<'EOF' > "$BUILD_DIR/usr/local/bin/webyonet"
#!/bin/bash
# /usr/local/bin/webyonet

if [ -f /etc/webyonet/webyonet.sh ]; then
  bash /etc/webyonet/webyonet.sh
else
  echo "❌ /etc/webyonet/webyonet.sh bulunamadı."
  exit 1
fi
EOF

chmod +x "$BUILD_DIR/usr/local/bin/webyonet"

# === WEBYONET DOSYALARINI KOPYALA ===
REQUIRED_FILES=("sitekur.sh" "sitekaldir.sh" "sitekur-config.sh" "webyonet.sh")

for FILE in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$FILE" ]; then
    echo "❌ $FILE bulunamadı. Aynı klasörde olmalı."
    exit 1
  fi
  cp "$FILE" "$BUILD_DIR/etc/$APP_NAME/"
done

chmod +x "$BUILD_DIR/etc/$APP_NAME/"*.sh

# === DEB OLUŞTUR ===
dpkg-deb --build "$BUILD_DIR" > /dev/null

# === SONUÇ ===
mv "${BUILD_DIR}.deb" "./$APP_NAME-${VERSION}.deb"
rm -rf "$BUILD_DIR"

echo "✅ Paket hazır: $APP_NAME-${VERSION}.deb"
