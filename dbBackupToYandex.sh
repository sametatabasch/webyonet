#!/bin/bash

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

function logger()
{
    echo "["`date "+%Y-%m-%d %H:%M:%S"`"] $1" >> "$LOG_FILE"
}

function echoLogger()
{
    echo "$1"
    echo "["`date "+%Y-%m-%d %H:%M:%S"`"] $1" >> "$LOG_FILE"
}

function parseJson()
{
    local output
    regex="(\"$1\":[\"]?)([^\",\}]+)([\"]?)"
    [[ $2 =~ $regex ]] && output=${BASH_REMATCH[2]}
    echo $output
}

function checkError()
{
    echo $(parseJson 'error' "$1")
}

# 'OK' - folder created or already exists on YD
function createDir()
{
    local json_out
    local json_error
    json_out=`curl -s -X PUT -H "Authorization: OAuth $TOKEN" https://cloud-api.yandex.net/v1/disk/resources?path=/$DIR_NAME`
    json_error=$(checkError "$json_out")
    if [[ $json_error != '' ]]; then
        if [[ $json_error == 'DiskPathPointsToExistentDirectoryError' ]]; then
            echo 'OK'
        else
            logger "Directory '$DIR_NAME' not created. Error: $json_error"
            echo ''
        fi
    else
        echo 'OK'
    fi
}
# $1 - file name in folder $DIR_NAME on YD
function getUploadUrl()
{
    local json_out
    local json_error
    local output
    json_out=`curl -s --header "Authorization: OAuth $TOKEN" https://cloud-api.yandex.net/v1/disk/resources/upload?path=/$DIR_NAME/$1`
    json_error=$(checkError "$json_out")
    if [[ $json_error != '' ]]; then
        logger "URL for '$1' not created. Error: $json_error"
        echo ''
    else
        output=$(parseJson 'href' "$json_out")
        echo $output
    fi
}

# $1 - path to folder with file
# $2 - local file name for upload
function uploadFile()
{
    local json_out
    local json_error
    local upload_url
    upload_url=$(getUploadUrl "$2")
    if [[ $upload_url != '' ]]
    then
        json_out=`curl -s -F "file=@$1/$2" --header "Authorization: OAuth $TOKEN" $upload_url`
        json_error=$(checkError "$json_out")
        if [[ $json_error != '' ]]
        then
            echoLogger "File '$2' not uploaded. Error: $json_error"
        else
            echoLogger "File '$2' uploaded to Yandex.Disk"
        fi
    else
        echoLogger "Can not get upload URL. File '$2' not uploaded."
    fi
}

mkdir -p "$BACKUP_DIR"
if [[ ! -d "$BACKUP_DIR" ]]
then
    echo 'Can not create backup folder'
    exit 1
fi

echoLogger 'Starting mysql backup'

dirOK=$(createDir)
if [[ $dirOK != 'OK' ]]
then
    echoLogger 'Error occured while creating folder on Yandex.Disk'
    echoLogger 'Continue without uploading'
fi

databases=`mysql -u backup -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)"`

for db in $databases
do
    echoLogger "Creating '$db' dump"
    dump_name="$db.sql.gz"
    mysqldump -u backup --force --opt --databases $db | gzip > "$BACKUP_DIR/$dump_name"
    if [[ $dirOK == 'OK' ]]; then
        echoLogger "Uploading '$dump_name' to Yandex.Disk"
        uploadFile "$BACKUP_DIR" "$dump_name"
    fi
done

echoLogger "Removing backup dir $BACKUP_DIR"

rm -rf $BACKUP_DIR

echoLogger 'All done!'
