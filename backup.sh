#!/bin/bash

REMOTE="gdrive"
REMOTE_DIR="HomeBackups"
BACKUP_DIR="$HOME/.backup/HomeBackups"
LOCAL_DIR="/home"
LOG_DIR="$HOME/.backup"
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"
LOG_FILE="$LOG_DIR/home-archive-$(date +"%d-%m-%Y").log"

# Kontroller
if ! command -v rclone &>/dev/null; then
    echo "❌ rclone yüklü değil. sudo apt install rclone"
    exit 1
fi

if ! rclone listremotes | grep -q "^${REMOTE}:"; then
    echo "❌ Remote '${REMOTE}' tanımlı değil."
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cd "$LOCAL_DIR"

for userdir in *; do
  if [ -d "$userdir" ]; then
    archive_name="${userdir}.tar.gz"
    log "Arşivleniyor: $userdir → $archive_name"
    tar --exclude="$userdir/**/cache" --exclude="$userdir/**/cache/*" -czf "$BACKUP_DIR/$archive_name" "$userdir" 2>>"$LOG_FILE"
    log "Sıkıştırıldı: $archive_name"
  fi
done

log "Tüm arşivler oluşturuldu, Google Drive'a yükleniyor..."

rclone copy "$BACKUP_DIR" "$REMOTE:$REMOTE_DIR" \
  --drive-chunk-size=128M --multi-thread-streams=8 \
  --transfers=8 --checkers=8 --log-level=INFO --progress --log-file="$LOG_FILE"

log "✅ Tüm arşivler Google Drive'a yüklendi."
rm -f "$BACKUP_DIR"/*.tar.gz
log "🧹 Yerel arşivler silindi."