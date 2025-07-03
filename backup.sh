#!/bin/bash

REMOTE="gdrive"
REMOTE_DIR="HomeBackups"
LOCAL_DIR="/home"
LOG_DIR="$HOME/.backup"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/home-archive-$(date +"%d-%m-%Y").log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cd "$LOCAL_DIR"

for userdir in *; do
  if [ -d "$userdir" ]; then
    archive_name="${userdir}-$(date +%Y%m%d).tar.gz"
    log "Arşivleniyor: $userdir → $archive_name"
    tar --exclude="$userdir/**/cache" --exclude="$userdir/**/cache/*" -czf "/tmp/$archive_name" "$userdir" ."$userdir" 2>>"$LOG_FILE"
    log "Yükleniyor: $archive_name"
    rclone copyto "/tmp/$archive_name" "$REMOTE:$REMOTE_DIR/$archive_name" \
      --drive-chunk-size=128M --multi-thread-streams=8 \
      --log-level=INFO --progress --log-file="$LOG_FILE" &
    rm -f "/tmp/$archive_name"
    log "Geçici arşiv dosyası silindi: /tmp/$archive_name"
    if [ $? -eq 0 ]; then
      log "✅ $userdir arşivleme ve yükleme başarılı."
    else
      log "❌ $userdir arşivleme veya yükleme başarısız."
    fi
  fi
done

log "✅ Tüm kullanıcı klasörleri arşivlenip yüklendi."