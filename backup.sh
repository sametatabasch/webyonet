#!/bin/bash

REMOTE="gdrive"
REMOTE_DIR="HomeBackups"
LOCAL_DIR="/home"

LOG_DIR="$HOME/.backup"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/home-backup-$(date +%Y-%m).log"

TMPDIR=$(mktemp -d)
DRIVE_LIST="$TMPDIR/drive_files.json"
LOCAL_LIST="$TMPDIR/local_files.txt"
DRIVE_PATHS="$TMPDIR/drive_paths.txt"
UPLOAD_LIST="$TMPDIR/upload.txt"
DELETE_LIST="$TMPDIR/delete.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
echo "Geçici dizin: $TMPDIR"

# 1. Google Drive'daki dosyaları lsjson ile al
log "🔍 Google Drive'daki dosyalar listeleniyor..."
rclone lsjson -R "$REMOTE:$REMOTE_DIR" > "$DRIVE_LIST"

# 2. Yerel dosyaları listele ve boyutlarıyla birlikte yaz
log "📂 Yerel dosyalar listeleniyor..."
find "$LOCAL_DIR" -type f -printf "%P|%s\n" | sort > "$LOCAL_LIST"

# 3. Drive'daki dosyaların yol ve boyutlarını çıkart
log "📄 Drive dosyaları işleniyor..."
jq -r '.[] | select(.IsDir==false) | "\(.Path)|\(.Size)"' "$DRIVE_LIST" | sort > "$DRIVE_PATHS"

# 4. Sadece Drive'da olup yerelde olmayan dosyaları bul
log "🔍 Yerelde olmayan Drive dosyaları bulunuyor..."
comm -23 "$DRIVE_PATHS" "$LOCAL_LIST" > "$DELETE_LIST"

# 5. Bu dosyaları Drive'dan sil
log "🗑️ Drive'dan silinecek dosyalar hazırlanıyor..."
while IFS='|' read -r filepath _; do
    log "❌ Siliniyor: $filepath"
    rclone delete "$REMOTE:$REMOTE_DIR/$filepath" --progress
done < "$DELETE_LIST"

# 6. Sadece localde olup drive'da olmayan veya boyutu farklı olan dosyaları bul
log "🔍 Yerelde olup Drive'da olmayan veya boyutu farklı olan dosyalar bulunuyor..."
comm -23 "$LOCAL_LIST" "$DRIVE_PATHS" > "$UPLOAD_LIST"

# 7. Yüklenmesi gereken dosya sayısı
COUNT=$(wc -l < "$UPLOAD_LIST")
log "📦 Yüklenecek dosya sayısı: $COUNT"

# 8. Sadece gerekli dosyaları yükle
xargs -P 32 -I{} bash -c '
  relative_path=$(echo "$1" | cut -d"|" -f1)
  src="$2/$relative_path"
  dst="$3:$4/$relative_path"
  rclone copyto "$src" "$dst" --log-level=NOTICE --progress >> "$5"
' _ {} "$LOCAL_DIR" "$REMOTE" "$REMOTE_DIR" "$LOG_FILE"

log "✅ İşlem tamamlandı: $COUNT dosya yüklendi"

rm -rf "$TMPDIR"