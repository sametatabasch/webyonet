#!/bin/bash
# wp-db-clean.sh
# WordPress veritabanı temizliği ve optimizasyonu
# Config dosyasında DB_NAMES değişkenine optimize edilecek veritabanı isimlerini ekleyin


# Eğer CONFIG yolu dışarıdan verilmediyse varsayılan konumu kullan
if [ -z "$CONFIG" ]; then
    CONFIG="/etc/webyonet/webyonet-config.sh"
fi

if [ -f "$CONFIG" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG"
else
    echo "❌ Konfigürasyon dosyası bulunamadı: $CONFIG"
    exit 1
fi

# Fonksiyon: SQL komutunu çalıştır (DB ismi ve SQL komutu alır)
run_sql() {
    mysql -u "root" "$1" -e "$2"
}
# DB_NAMES bir Bash array'i olarak tanımlanmalıdır: DB_NAMES=( "db1" "db2" )
for DB_NAME in "${DB_NAMES[@]}"
do
    echo "🔹 WordPress veritabanı temizliği başlatılıyor: $DB_NAME"

    # 1️⃣ wp_options içindeki geçici (transient) verileri temizle
    echo "💡 wp_options tablosundaki transient veriler siliniyor..."
    run_sql $DB_NAME "DELETE FROM wp_gb_options WHERE option_name LIKE '_transient_%';"
    run_sql $DB_NAME "OPTIMIZE TABLE wp_gb_options;"

    # 2️⃣ Action Scheduler tablolarını temizle ve optimize et
    echo "💡 Action Scheduler tabloları temizleniyor ve optimize ediliyor..."
    run_sql $DB_NAME "DELETE FROM wp_gb_actionscheduler_actions WHERE status = 'complete';"
    run_sql $DB_NAME "DELETE FROM wp_gb_actionscheduler_claims WHERE claim_id NOT IN (SELECT claim_id FROM wp_gb_actionscheduler_actions);"
    run_sql $DB_NAME  "OPTIMIZE TABLE wp_gb_actionscheduler_actions;"
    run_sql $DB_NAME  "OPTIMIZE TABLE wp_gb_actionscheduler_claims;"
    run_sql $DB_NAME  "OPTIMIZE TABLE wp_gb_actionscheduler_logs;"

    # 3️⃣ Wordfence tablolarını optimize et
    echo "💡 Wordfence tabloları optimize ediliyor..."
    run_sql $DB_NAME  "OPTIMIZE TABLE wp_gb_wffilemods, wp_gb_wfknownfilelist, wp_gb_wfhits, wp_gb_wflogins;"

    # 4️⃣ Post ve meta tablolarını optimize et
    echo "💡 wp_posts ve wp_postmeta tabloları optimize ediliyor..."
    run_sql $DB_NAME  "OPTIMIZE TABLE wp_gb_posts, wp_gb_postmeta;"

    # 5️⃣ Son tablo boyutlarını göster
    echo "🔹 Güncel tablo boyutları:"
    run_sql $DB_NAME  "SELECT table_name AS 'Tablo', ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Boyut_MB' FROM information_schema.TABLES WHERE table_schema = '$DB_NAME' ORDER BY (data_length + index_length) DESC;"

    echo "✅ WordPress veritabanı temizliği tamamlandı!"
done