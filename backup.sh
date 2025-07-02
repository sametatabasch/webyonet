#!/bin/bash

REMOTE="gdrive"  # Yandex Disk veya Google Drive gibi bir remote tanımlayın
# Örnek: REMOTE="yandex" veya REMOTE="gdrive"
LOCAL_DIR="/home"
REMOTE_DIR="HomeBackups"
LOG_FILE="$HOME/.backup/backup-$(date +"%d.%m.%Y").log"

# Kontroller
if ! command -v rclone &>/dev/null; then
    log "❌ rclone yüklü değil. sudo apt install rclone"
    exit 1
fi

if ! rclone listremotes | grep -q "^${REMOTE}:"; then
    log "❌ Remote '${REMOTE}' tanımlı değil."
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
log "🔄 Sync başlıyor: $LOCAL_DIR → $REMOTE:$REMOTE_DIR"

# 1️⃣ Hedefte olup kaynakta olmayanları sil
log "🧹 Hedefte fazladan kalan dosyalar siliniyor..."
rclone delete "$REMOTE:$REMOTE_DIR" --min-age 1m --compare-dest "$LOCAL_DIR" \
  --log-file "$LOG_FILE" --log-level INFO --progress

# 2️⃣ Kaynaktan yeni veya değişen dosyaları kopyala (fazla olanı silmeden)
log "📤 Yeni ve güncel dosyalar kopyalanıyor..."
rclone copy "$LOCAL_DIR" "$REMOTE:$REMOTE_DIR" \
  --transfers=16  --checkers=16  --fast-list  --multi-thread-streams=8  --log-level=INFO \
  --progress  --delete-during  --drive-chunk-size=64M  --log-file="$LOG_FILE" \
  --update --use-server-modtime --create-empty-src-dirs

if [[ $? -eq 0 ]]; then
    log "✅ Sync tamamlandı."
else
    log "❌ Sync sırasında hata oluştu."
fi