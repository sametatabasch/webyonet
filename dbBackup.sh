#!/bin/bash

REMOTE="gdrive"  # veya "yadisk"
BACKUP_DIR="$HOME/.backup/db"
LOG_FILE="$BACKUP_DIR/backup-db-$(date +%Y-%m).log"
REMOTE_DIR="DBBackups"

# Kontroller
if ! command -v rclone &>/dev/null; then
    echo "❌ rclone yüklü değil. sudo apt install rclone"
    exit 1
fi

if ! rclone listremotes | grep -q "^${REMOTE}:"; then
    echo "❌ Remote '${REMOTE}' tanımlı değil."
    exit 1
fi

mkdir -p "$BACKUP_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log '📦 MySQL veritabanı yedeği başlatılıyor'

# Veritabanı listesi
databases=$(mysql --login-path=local -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

for db in $databases
do
    log "🧩 '$db' dump oluşturuluyor"
    dump_name="$db.sql.gz"
    mysqldump --login-path=local --force --opt --databases "$db" | gzip > "$BACKUP_DIR/$dump_name"
done

# Buluta gönder (aynı isimli dosya güncellenir)
rclone copy "$BACKUP_DIR/" "$REMOTE:$REMOTE_DIR/" --progress --log-level=INFO --log-file="$LOG_FILE"
if [[ $? -eq 0 ]]; then
    log "✅ Veritabanı yedekleri buluta yüklendi"
    rm -f "$BACKUP_DIR/"*.sql.gz
    log "🧹 Yerel yedekler silindi"
else
    log "❌ Yedekler yüklenemedi. rclone hatası"
fi

log '✅ Tüm işlemler tamamlandı!'
log '--------------------------'