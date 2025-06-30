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

# Base folder with backups
BASE_BACKUP_DIR="$HOME/.backup"

# Current date for folder name
DATE=$(date +"%d.%m.%Y")

# Current month for log
DATE_MONTH=$(date +"%Y-%m")

# Folder name with backups (hem yerel hem Yandex.Disk'te)
DIR_NAME="$DATE-HomeBackups"

# Full path
BACKUP_DIR="$BASE_BACKUP_DIR/$DIR_NAME"

# Log file path
LOG_FILE="$BASE_BACKUP_DIR/backup-$DATE_MONTH.log"

# Yandex.Disk remote adı (rclone config'de verdiğiniz isim)
YANDEX_REMOTE="yadisk"

function echoLogger()
{
    echo "$1"
    echo "["`date "+%Y-%m-%d %H:%M:%S"`"] $1" >> "$LOG_FILE"
}

mkdir -p "$BACKUP_DIR"
if [[ ! -d "$BACKUP_DIR" ]]
then
    echo 'Can not create backup folder'
    exit 1
fi

echoLogger 'Starting backup'

# /home dizinindeki sadece klasörleri bul
arr=$(find /home -mindepth 1 -maxdepth 1 -type d  ! -name '*.backup' ! -name '*.bck*')

for a in $arr
do
    user=$(basename "$a")
    echoLogger "$user dizini sıkıştırılıyor."
    BACKUP_FILE_NAME="$user.tar.gz"
    tar -czf "$BACKUP_DIR/$BACKUP_FILE_NAME" "$a"
    echoLogger "$user sıkıştırıldı"
    echoLogger "Uploading $BACKUP_FILE_NAME to Yandex.Disk"
    rclone copy "$BACKUP_DIR/$BACKUP_FILE_NAME" "$YANDEX_REMOTE:$DIR_NAME/" --progress --transfers=4
    if [[ $? -eq 0 ]]; then
        echoLogger "File '$BACKUP_FILE_NAME' uploaded to Yandex.Disk (rclone)"
        rm -f "$BACKUP_DIR/$BACKUP_FILE_NAME"
        echoLogger "$BACKUP_FILE_NAME silindi."
    else
        echoLogger "File '$BACKUP_FILE_NAME' not uploaded. Error with rclone."
    fi
done

echoLogger "Removing backup dir $BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echoLogger 'All done!'
echoLogger '--------------------------'