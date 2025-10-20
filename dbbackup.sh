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

# create ~/.my.cnf:

# [client]
# user=backup
# password=GüçlüŞifreBuraya
# host=localhost


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

# Yedekten sonra wp-db-clean.sh varsa çalıştır
run_wp_db_clean() {
    # varsa /usr/local/bin/webyonet-bin/ kullan (paket kurulumunda burada olur)
    if [ -n "$APPDIR" ] && [ -x "$APPDIR/wp-db-clean.sh" ]; then
        WP_CLEAN_SH="$APPDIR/wp-db-clean.sh"
    elif [ -x "./wp-db-clean.sh" ]; then
        WP_CLEAN_SH="./wp-db-clean.sh"
    else
        log "⚠️ wp-db-clean.sh bulunamadı; atlanıyor"
        return 0
    fi

    log "🔁 Yedekten sonra wp-db-clean.sh çalıştırılıyor: $WP_CLEAN_SH"
    bash "$WP_CLEAN_SH"
}

run_wp_db_clean

log '✅ Tüm işlemler tamamlandı!'
log '--------------------------'