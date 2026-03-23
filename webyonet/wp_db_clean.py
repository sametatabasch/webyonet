"""WordPress veritabanı temizleme ve optimizasyon modülü."""

import subprocess
import sys

from webyonet.config import MYSQL_CONFIG, load_config
from webyonet.logger import setup_logger

logger = setup_logger(__name__)


def _run_sql(db_name: str, sql: str) -> bool:
    """MySQL SQL komutunu çalıştırır.

    Args:
        db_name: Veritabanı adı.
        sql: Çalıştırılacak SQL komutu.

    Returns:
        True ise başarılı.
    """
    mysql_args = []
    if MYSQL_CONFIG:
        import os
        if os.path.exists(MYSQL_CONFIG):
            mysql_args = [f"--defaults-extra-file={MYSQL_CONFIG}"]

    cmd = ["mysql", *mysql_args, db_name, "-e", sql]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            # Tablo bulunamadı gibi hatalar fatal değil
            if "doesn't exist" not in result.stderr:
                logger.warning("⚠️ SQL uyarısı [%s]: %s", db_name, result.stderr.strip())
            return False
        if result.stdout.strip():
            print(result.stdout)
        return True
    except OSError as e:
        logger.error("❌ MySQL çalıştırılamadı: %s", e)
        return False


def clean_database(db_name: str) -> None:
    """Tek bir WordPress veritabanını temizler ve optimize eder.

    Args:
        db_name: Temizlenecek veritabanı adı.
    """
    logger.info("🔹 WordPress veritabanı temizliği başlatılıyor: %s", db_name)

    # 1️⃣ wp_options transient verileri temizle
    logger.info("💡 wp_options tablosundaki transient veriler siliniyor...")
    _run_sql(db_name, "DELETE FROM wp_gb_options WHERE option_name LIKE '_transient_%';")
    _run_sql(db_name, "OPTIMIZE TABLE wp_gb_options;")

    # 2️⃣ Action Scheduler tabloları
    logger.info("💡 Action Scheduler tabloları temizleniyor ve optimize ediliyor...")
    _run_sql(db_name, "DELETE FROM wp_gb_actionscheduler_actions WHERE status = 'complete';")
    _run_sql(
        db_name,
        "DELETE FROM wp_gb_actionscheduler_claims WHERE claim_id NOT IN "
        "(SELECT claim_id FROM wp_gb_actionscheduler_actions);",
    )
    _run_sql(db_name, "OPTIMIZE TABLE wp_gb_actionscheduler_actions;")
    _run_sql(db_name, "OPTIMIZE TABLE wp_gb_actionscheduler_claims;")
    _run_sql(db_name, "OPTIMIZE TABLE wp_gb_actionscheduler_logs;")

    # 3️⃣ Wordfence tabloları
    logger.info("💡 Wordfence tabloları optimize ediliyor...")
    _run_sql(db_name, "OPTIMIZE TABLE wp_gb_wffilemods, wp_gb_wfknownfilelist, wp_gb_wfhits, wp_gb_wflogins;")

    # 4️⃣ Post ve meta tabloları
    logger.info("💡 wp_posts ve wp_postmeta tabloları optimize ediliyor...")
    _run_sql(db_name, "OPTIMIZE TABLE wp_gb_posts, wp_gb_postmeta;")

    # 5️⃣ Tablo boyutları
    logger.info("🔹 Güncel tablo boyutları:")
    _run_sql(
        db_name,
        f"SELECT table_name AS 'Tablo', "
        f"ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Boyut_MB' "
        f"FROM information_schema.TABLES "
        f"WHERE table_schema = '{db_name}' "
        f"ORDER BY (data_length + index_length) DESC;",
    )

    logger.info("✅ WordPress veritabanı temizliği tamamlandı!")


def run_wp_db_clean() -> None:
    """Yapılandırmadaki tüm WordPress veritabanlarını temizler."""
    config = load_config()
    db_names = config.get("db_names", [])

    if not db_names:
        logger.warning("⚠️ Temizlenecek veritabanı yapılandırmada tanımlı değil (db_names).")
        return

    for db_name in db_names:
        clean_database(db_name)
