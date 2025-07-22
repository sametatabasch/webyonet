#!/bin/bash

REMOTE="gdrive"  # veya "yadisk"
BACKUP_DIR="$HOME/.backup/db"
LOG_FILE="$HOME/.backup/backup-db-$(date +"%d.%m.%Y").log" 
REMOTE_DIR="Backups/DBBackups"

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

# save password for db user "backup" in "~/.mylogin.cnf":
# mysql_config_editor set --login-path=local --host=localhost --user=backup --password
# permisions for backup user: Select table data, Show databases, Lock tables, Show View


# Veritabanı listesi
databases=$(mysql -u backup -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

for db in $databases
do
    log "🧩 '$db' dump oluşturuluyor"
    dump_name="$db.sql.gz"
    mysqldump -u backup --force --opt --databases "$db" | gzip > "$BACKUP_DIR/$dump_name"
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