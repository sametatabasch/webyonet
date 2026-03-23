"""MySQL veritabanı yedekleme modülü."""

import os
import subprocess

from webyonet.config import MYSQL_CONFIG, RCLONE_CONFIG, load_config
from webyonet.logger import get_log_path, setup_logger


def _get_rclone_args() -> list[str]:
    """rclone config dosyası argümanlarını döndürür."""
    if os.path.exists(RCLONE_CONFIG):
        return ["--config", RCLONE_CONFIG]
    return []


def _get_mysql_args() -> list[str]:
    """MySQL config dosyası argümanlarını döndürür."""
    if os.path.exists(MYSQL_CONFIG):
        return [f"--defaults-extra-file={MYSQL_CONFIG}"]
    return []


def _check_dependencies(logger, remote: str) -> None:
    """Gerekli araçların kurulu olup olmadığını kontrol eder.

    Args:
        logger: Logger nesnesi.
        remote: rclone remote adı.

    Raises:
        SystemExit: Gerekli araçlar kurulu değilse.
    """
    import shutil

    for tool in ("rclone", "mysql", "mysqldump"):
        if not shutil.which(tool):
            logger.error("❌ %s yüklü değil.", tool)
            raise SystemExit(1)

    # rclone remote kontrolü
    cmd = ["rclone", "listremotes"] + _get_rclone_args()
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        remotes = [r.strip(":") for r in result.stdout.splitlines()]
        if remote not in remotes:
            logger.error("❌ Remote '%s' tanımlı değil.", remote)
            raise SystemExit(1)
    except subprocess.CalledProcessError as e:
        logger.error("❌ rclone listremotes başarısız: %s", e.stderr)
        raise SystemExit(1)


def _get_databases(logger) -> list[str]:
    """MySQL veritabanı listesini döndürür.

    Args:
        logger: Logger nesnesi.

    Returns:
        Veritabanı isimleri listesi.
    """
    excluded = {"Database", "information_schema", "performance_schema", "mysql", "sys"}
    cmd = ["mysql", *_get_mysql_args(), "-e", "SHOW DATABASES;"]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        databases = [
            line.strip()
            for line in result.stdout.splitlines()
            if line.strip() and line.strip() not in excluded
        ]
        return databases
    except subprocess.CalledProcessError as e:
        logger.error("❌ Veritabanı listesi alınamadı: %s", e.stderr)
        return []


def _dump_databases(logger, databases: list[str], backup_dir: str) -> None:
    """Veritabanlarını dump eder ve sıkıştırır.

    Args:
        logger: Logger nesnesi.
        databases: Yedeklenecek veritabanı listesi.
        backup_dir: Yerel yedek dizini.
    """
    os.makedirs(backup_dir, exist_ok=True)

    for db in databases:
        logger.info("🧩 '%s' dump oluşturuluyor", db)
        dump_name = f"{db}.sql.gz"
        dump_path = os.path.join(backup_dir, dump_name)

        dump_cmd = ["mysqldump", *_get_mysql_args(), "--force", "--opt", "--databases", db]
        gzip_cmd = ["gzip"]

        try:
            with open(dump_path, "wb") as outfile:
                dump_proc = subprocess.Popen(
                    dump_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                gzip_proc = subprocess.Popen(
                    gzip_cmd,
                    stdin=dump_proc.stdout,
                    stdout=outfile,
                    stderr=subprocess.PIPE,
                )
                dump_proc.stdout.close()
                gzip_proc.communicate()
                dump_proc.wait()

                if dump_proc.returncode != 0:
                    stderr = dump_proc.stderr.read().decode().strip()
                    logger.warning("⚠️ '%s' dump uyarısı: %s", db, stderr)
        except OSError as e:
            logger.error("❌ '%s' dump hatası: %s", db, e)


def _upload_to_cloud(logger, remote: str, backup_dir: str, remote_dir: str, log_file: str) -> bool:
    """Yedekleri bulut depolamaya yükler.

    Args:
        logger: Logger nesnesi.
        remote: rclone remote adı.
        backup_dir: Yerel yedek dizini.
        remote_dir: Uzak dizin yolu.
        log_file: Log dosyası yolu.

    Returns:
        True ise başarılı.
    """
    rclone_cmd = [
        "rclone", "copy", f"{backup_dir}/", f"{remote}:{remote_dir}/",
        *_get_rclone_args(),
        "--progress",
        "--log-level=INFO",
        f"--log-file={log_file}",
    ]
    result = subprocess.run(rclone_cmd, check=False)
    return result.returncode == 0


def _cleanup_local(logger, backup_dir: str) -> None:
    """Yerel yedek dosyalarını temizler.

    Args:
        logger: Logger nesnesi.
        backup_dir: Yerel yedek dizini.
    """
    if not os.path.isdir(backup_dir):
        return

    for fname in os.listdir(backup_dir):
        if fname.endswith(".sql.gz"):
            try:
                os.remove(os.path.join(backup_dir, fname))
            except OSError as e:
                logger.error("❌ Silinemedi: %s (%s)", fname, e)

    logger.info("🧹 Yerel yedekler silindi")


def run_db_backup() -> None:
    """Ana veritabanı yedekleme işlemini çalıştırır."""
    log_file = get_log_path("backup-db")
    logger = setup_logger("db_backup", log_file)

    config = load_config()
    remote = config.get("backup_remote", "gdrive")
    backup_dir = os.path.expanduser(config.get("db_backup_dir", "~/.backup/db"))
    remote_dir = config.get("db_remote_dir", "Backups/DBBackups")

    _check_dependencies(logger, remote)
    logger.info("📦 MySQL veritabanı yedeği başlatılıyor")

    databases = _get_databases(logger)
    if not databases:
        logger.warning("⚠️ Yedeklenecek veritabanı bulunamadı.")
        return

    _dump_databases(logger, databases, backup_dir)

    if _upload_to_cloud(logger, remote, backup_dir, remote_dir, log_file):
        logger.info("✅ Veritabanı yedekleri buluta yüklendi")
        _cleanup_local(logger, backup_dir)
    else:
        logger.error("❌ Yedekler yüklenemedi. rclone hatası")

    # WP DB temizleme
    try:
        from webyonet.wp_db_clean import run_wp_db_clean
        logger.info("🔁 Yedekten sonra WordPress DB temizleme çalıştırılıyor")
        run_wp_db_clean()
    except Exception as e:
        logger.warning("⚠️ wp-db-clean çalıştırılamadı: %s", e)

    logger.info("✅ Tüm işlemler tamamlandı!")
    logger.info("--------------------------")
