"""Dizin yedekleme modülü - rclone ile bulut depolamaya yükleme."""

import os
import shutil
import subprocess

from webyonet.config import RCLONE_CONFIG, load_config
from webyonet.logger import get_log_path, setup_logger


def _get_rclone_args() -> list[str]:
    """rclone config dosyası argümanlarını döndürür."""
    if os.path.exists(RCLONE_CONFIG):
        return ["--config", RCLONE_CONFIG]
    return []


def _check_rclone(logger, remote: str) -> None:
    """rclone kurulumu ve remote kontrolü.

    Args:
        logger: Logger nesnesi.
        remote: Kontrol edilecek remote adı.

    Raises:
        SystemExit: rclone kurulu değilse veya remote tanımlı değilse.
    """
    if not shutil.which("rclone"):
        logger.error("❌ rclone yüklü değil. sudo apt install rclone")
        raise SystemExit(1)

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


def _archive_dirs(logger, backup_list: list[dict]) -> None:
    """Yedekleme listesindeki dizinleri arşivler.

    Args:
        logger: Logger nesnesi.
        backup_list: Yedekleme hedefleri listesi.
    """
    for backup in backup_list:
        local_dir = os.path.expanduser(backup["local_dir"])
        backup_dir = os.path.expanduser(backup["backup_dir"])
        os.makedirs(backup_dir, exist_ok=True)

        # Exclude argümanları
        exclude_args = []
        for pattern in backup.get("exclude", []):
            exclude_args.extend(["--exclude", pattern])

        if not os.path.isdir(local_dir):
            logger.warning("⚠️ Dizin bulunamadı, atlanıyor: %s", local_dir)
            continue

        if backup.get("only_subdirs", False):
            # Sadece alt dizinleri arşivle
            for subdir in sorted(os.listdir(local_dir)):
                subdir_path = os.path.join(local_dir, subdir)
                if not os.path.isdir(subdir_path):
                    continue

                archive_name = f"{subdir}.tar.gz"
                archive_path = os.path.join(backup_dir, archive_name)
                logger.info("Arşivleniyor: %s → %s", subdir_path, archive_name)

                tar_cmd = [
                    "tar", *exclude_args,
                    "-czf", archive_path,
                    "-C", local_dir, subdir,
                ]
                result = subprocess.run(tar_cmd, capture_output=True, text=True, check=False)
                if result.returncode == 0:
                    logger.info("Sıkıştırıldı: %s", archive_name)
                else:
                    logger.error("❌ Hata: %s (%s)", archive_name, result.stderr.strip())
        else:
            # Tüm dizini tek arşivle sıkıştır
            archive_name = f"{os.path.basename(local_dir)}.tar.gz"
            archive_path = os.path.join(backup_dir, archive_name)
            logger.info("Arşivleniyor: %s → %s", local_dir, archive_name)

            tar_cmd = [
                "tar", *exclude_args,
                "-czf", archive_path,
                "-C", os.path.dirname(local_dir),
                os.path.basename(local_dir),
            ]
            result = subprocess.run(tar_cmd, capture_output=True, text=True, check=False)
            if result.returncode == 0:
                logger.info("Sıkıştırıldı: %s", archive_name)
            else:
                logger.error("❌ Hata: %s (%s)", archive_name, result.stderr.strip())


def _upload_archives(logger, remote: str, backup_list: list[dict], log_file: str) -> None:
    """Arşivleri bulut depolamaya yükler.

    Args:
        logger: Logger nesnesi.
        remote: rclone remote adı.
        backup_list: Yedekleme hedefleri listesi.
        log_file: Log dosyası yolu.
    """
    for backup in backup_list:
        backup_dir = os.path.expanduser(backup["backup_dir"])
        if not os.path.isdir(backup_dir):
            continue

        logger.info("%s içindeki arşivler buluta yükleniyor...", backup_dir)
        rclone_cmd = [
            "rclone", "copy", backup_dir, f"{remote}:{backup['remote_dir']}",
            *_get_rclone_args(),
            "--drive-chunk-size=128M",
            "--multi-thread-streams=8",
            "--transfers=8",
            "--checkers=8",
            "--log-level=INFO",
            "--progress",
            f"--log-file={log_file}",
        ]
        subprocess.run(rclone_cmd, check=False)


def _cleanup(logger, backup_list: list[dict]) -> None:
    """Yükleme sonrası yerel arşivleri temizler.

    Args:
        logger: Logger nesnesi.
        backup_list: Yedekleme hedefleri listesi.
    """
    for backup in backup_list:
        backup_dir = os.path.expanduser(backup["backup_dir"])
        if not os.path.isdir(backup_dir):
            continue

        for fname in os.listdir(backup_dir):
            if fname.endswith(".tar.gz"):
                fpath = os.path.join(backup_dir, fname)
                try:
                    os.remove(fpath)
                except OSError as e:
                    logger.error("❌ Silinemedi: %s (%s)", fname, e)

        logger.info("🧹 %s içindeki yerel arşivler silindi.", backup_dir)


def run_backup() -> None:
    """Ana yedekleme işlemini çalıştırır."""
    log_file = get_log_path("home-archive")
    logger = setup_logger("backup", log_file)

    config = load_config()
    remote = config.get("backup_remote", "gdrive")
    backup_list = config.get("backup_list", [])

    if not backup_list:
        logger.warning("⚠️ Yedeklenecek dizin yapılandırmada tanımlı değil (backup_list).")
        return

    _check_rclone(logger, remote)
    _archive_dirs(logger, backup_list)
    _upload_archives(logger, remote, backup_list, log_file)
    logger.info("✅ Tüm arşivler buluta yüklendi.")
    _cleanup(logger, backup_list)
