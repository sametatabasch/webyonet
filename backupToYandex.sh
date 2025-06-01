#!/bin/bash

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

# /home dizinindeki kullanıcı klasörlerini bul
arr=$(ls /home | grep -v back)

for a in $arr
do
    echoLogger "$a dizini sıkıştırılıyor."
    BACKUP_FILE_NAME="$a.tar.gz"
    tar -czf "$BACKUP_DIR/$BACKUP_FILE_NAME" "/home/$a"
    echoLogger "$a sıkıştırıldı"
    echoLogger "Uploading $BACKUP_FILE_NAME to Yandex.Disk"
    rclone copy "$BACKUP_DIR/$BACKUP_FILE_NAME" "$YANDEX_REMOTE:$DIR_NAME/" --progress
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