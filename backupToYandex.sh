YANDEX_REMOTE="yadisk"
LOCAL_DIR="/home"
REMOTE_DIR="HomeBackups"
LOG_FILE="$HOME/.backup/backup-$(date +%Y-%m).log"

# Kontroller
if ! command -v rclone &>/dev/null; then
    log "❌ rclone yüklü değil. sudo apt install rclone"
    exit 1
fi

if ! rclone listremotes | grep -q "^${YANDEX_REMOTE}:"; then
    log "❌ Remote '${YANDEX_REMOTE}' tanımlı değil."
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
log "🔄 Sync başlıyor: $LOCAL_DIR → $YANDEX_REMOTE:$REMOTE_DIR"

# 1️⃣ Hedefte olup kaynakta olmayanları sil
log "🧹 Hedefte fazladan kalan dosyalar siliniyor..."
rclone delete "$YANDEX_REMOTE:$REMOTE_DIR" --min-age 1m --compare-dest "$LOCAL_DIR" \
  --log-file "$LOG_FILE" --log-level INFO

# 2️⃣ Kaynaktan yeni veya değişen dosyaları kopyala (fazla olanı silmeden)
log "📤 Yeni ve güncel dosyalar kopyalanıyor..."
rclone copy "$LOCAL_DIR" "$YANDEX_REMOTE:$REMOTE_DIR" \
    --log-level INFO --fast-list --transfers 8 --log-file "$LOG_FILE"

if [[ $? -eq 0 ]]; then
    log "✅ Sync tamamlandı."
else
    log "❌ Sync sırasında hata oluştu."
fi