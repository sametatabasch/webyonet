#!/bin/bash

# rclone ve yadisk remote kontrolü
if ! command -v rclone &>/dev/null; then
    echo "❌ rclone yüklü değil. Kurmak için: sudo apt install rclone"
    exit 1
fi

if ! rclone listremotes | grep -q "^yadisk:"; then
    echo "❌ rclone config'de 'yadisk' adlı bir remote bulunamadı."
    echo "Kurmak için: rclone config"
    exit 1
fi

# save password for db user "backup" in "~/.mylogin.cnf":
# mysql_config_editor set --login-path=local --host=localhost --user=backup --password
# permisions for backup user: Select table data, Show databases, Lock tables, Show View

# Base folder with backups
BASE_BACKUP_DIR="$HOME/.backup"

# Current date for folder name
DATE=$(date +"%d.%m.%Y")

# Current month for log
DATE_MONTH=$(date +"%Y-%m")

# Folder name with backups
DIR_NAME="$DATE-databasesBackups"

# Full path
BACKUP_DIR="$BASE_BACKUP_DIR/$DIR_NAME"

# Log file path
LOG_FILE="$BASE_BACKUP_DIR/backup-db-$DATE_MONTH.log"

# Yandex.Disk remote adı (rclone config'de verdiğiniz isim)
YANDEX_REMOTE="yadisk"

function echoLogger()
{
    echo "$1"
    echo "["`date "+%Y-%m-%d %H:%M:%S"`"] $1" >> "$LOG_FILE"
}

echoLogger 'Starting mysql backup'

databases=`mysql -u backup -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)"`

for db in $databases
do
    echoLogger "Creating '$db' dump"
    dump_name="$db.sql.gz"
    mysqldump -u backup --force --opt --databases $db | gzip > "$BACKUP_DIR/$dump_name"
    rclone copy "$BACKUP_DIR/$dump_name" "$YANDEX_REMOTE:$DIR_NAME/" --progress --transfers=4
    if [[ $? -eq 0 ]]; then
        echoLogger "File '$dump_name' uploaded to Yandex.Disk (rclone)"
        rm -f "$BACKUP_DIR/$dump_name"
        echoLogger "$dump_name silindi."
    else
        echoLogger "File '$dump_name' not uploaded. Error with rclone."
    fi
done

echoLogger "Removing backup dir $BACKUP_DIR"

rm -rf $BACKUP_DIR

echoLogger 'All done!'
echoLogger '--------------------------'