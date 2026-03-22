#!/usr/bin/python3
import os
import subprocess
import datetime
import shutil

REMOTE = "gdrive"
backup_list = [
    {
        "local_dir": "/home",
        "remote_dir": "Backups/HomeBackups",
        "backup_dir": "~/.backup/HomeBackups",
        "exclude": ["**/cache", "**/cache/*"],
        "only_subdirs": True
    },
    {
        "local_dir": "/etc",
        "remote_dir": "Backups/etcBackups",
        "backup_dir": "~/.backup/etcBackups",
        "only_subdirs": False
    },
    {
        "local_dir": "/srv",
        "remote_dir": "Backups/srvBackups",
        "backup_dir": "~/.backup/srvBackups",
        "only_subdirs": False
    },
    {
        "local_dir": "/opt/monitoring",
        "remote_dir": "Backups/monitoringBackups",
        "backup_dir": "~/.backup/monitoringBackups",
        "only_subdirs": False
    }
]

LOG_DIR = os.path.expanduser("~/.backup")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, f"home-archive-{datetime.datetime.now():%d-%m-%Y}.log")
RCLONE_CONFIG = "/etc/webyonet/rclone.conf"

def log(msg):
    line = f"[{datetime.datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")

def get_rclone_args():
    if os.path.exists(RCLONE_CONFIG):
        return ["--config", RCLONE_CONFIG]
    return []

def check_rclone():
    if shutil.which("rclone") is None:
        print("❌ rclone yüklü değil. sudo apt install rclone")
        exit(1)
    
    cmd = ["rclone", "listremotes"] + get_rclone_args()
    remotes = subprocess.check_output(cmd).decode()
    if not any(remote.strip(":") == REMOTE for remote in remotes.splitlines()):
        print(f"❌ Remote '{REMOTE}' tanımlı değil.")
        exit(1)

def archive_dirs():
    for backup in backup_list:
        local_dir = os.path.expanduser(backup["local_dir"])
        remote_dir = backup["remote_dir"]
        backup_dir = os.path.expanduser(backup["backup_dir"])
        os.makedirs(backup_dir, exist_ok=True)
        exclude_args = []
        if "exclude" in backup:
            for pattern in backup["exclude"]:
                exclude_args.extend(["--exclude", pattern])
        if backup["only_subdirs"]:
            # Sadece alt dizinleri arşivle
            for subdir in os.listdir(local_dir):
                subdir_path = os.path.join(local_dir, subdir)
                if os.path.isdir(subdir_path):
                    archive_name = f"{subdir}.tar.gz"
                    archive_path = os.path.join(backup_dir, archive_name)
                    log(f"Arşivleniyor: {subdir_path} → {archive_name}")
                    tar_cmd = [
                        "tar",
                        *exclude_args,
                        "-czf", archive_path,
                        "-C", local_dir,
                        subdir
                    ]
                    result = subprocess.run(tar_cmd, stderr=subprocess.PIPE)
                    if result.returncode == 0:
                        log(f"Sıkıştırıldı: {archive_name}")
                    else:
                        log(f"❌ Hata: {archive_name} ({result.stderr.decode().strip()})")
        else:
            # Tüm dizini tek arşivle sıkıştır
            archive_name = f"{os.path.basename(local_dir)}.tar.gz"
            archive_path = os.path.join(backup_dir, archive_name)
            log(f"Arşivleniyor: {local_dir} → {archive_name}")
            tar_cmd = [
                "tar",
                *exclude_args,
                "-czf", archive_path,
                "-C", os.path.dirname(local_dir),
                os.path.basename(local_dir)
            ]
            result = subprocess.run(tar_cmd, stderr=subprocess.PIPE)
            if result.returncode == 0:
                log(f"Sıkıştırıldı: {archive_name}")
            else:
                log(f"❌ Hata: {archive_name} ({result.stderr.decode().strip()})")

def upload_archives():
    for backup in backup_list:
        log(f"{backup['backup_dir']} içindeki arşivler Google Drive'a yükleniyor...")
        rclone_cmd = [
            "rclone", "copy", os.path.expanduser(backup["backup_dir"]), f"{REMOTE}:{backup['remote_dir']}"
        ] + get_rclone_args() + [
            "--drive-chunk-size=128M", "--multi-thread-streams=8",
            "--transfers=8", "--checkers=8", "--log-level=INFO",
            "--progress", f"--log-file={LOG_FILE}"
        ]
        subprocess.run(rclone_cmd)

def cleanup():
    for backup in backup_list:
        backup_dir = os.path.expanduser(backup["backup_dir"])
        for fname in os.listdir(backup_dir):
            if fname.endswith(".tar.gz"):
                try:
                    os.remove(os.path.join(backup_dir, fname))
                except Exception as e:
                    log(f"❌ Silinemedi: {fname} ({e})")
        log(f"🧹 {backup_dir} içindeki yerel arşivler silindi.")

if __name__ == "__main__":
    check_rclone()
    archive_dirs()
    upload_archives()
    log("✅ Tüm arşivler Google Drive'a yüklendi.")
    cleanup()