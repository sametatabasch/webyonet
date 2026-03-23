"""YAML tabanlı yapılandırma yönetimi."""

import getpass
import os
import sys
from pathlib import Path

import yaml

from webyonet.utils import run_cmd, set_secure_permissions

CONFIG_DIR = "/etc/webyonet"
CONFIG_FILE = os.path.join(CONFIG_DIR, "webyonet.yaml")
RCLONE_CONFIG = os.path.join(CONFIG_DIR, "rclone.conf")
MYSQL_CONFIG = os.path.join(CONFIG_DIR, "mysql-backup.cnf")

# Kurulum dizini (deb paketinden veya yerel çalıştırmada)
if os.path.isdir("/usr/local/lib/webyonet"):
    APP_DIR = "/usr/local/lib/webyonet"
else:
    APP_DIR = str(Path(__file__).parent)

TEMPLATES_DIR = os.path.join(APP_DIR, "templates")

DEFAULT_CONFIG: dict = {
    "cloudflare_api_token": "",
    "cloudflare_zone_id": "",
    "cf_domain": "",
    "server_ip": "",
    "web_server": "",
    "db_names": [],
    "backup_remote": "",
    "backup_list": [],
    "db_backup_dir": "",
    "db_remote_dir": "",
}


def load_config() -> dict:
    """Yapılandırma dosyasını yükler.

    Returns:
        Yapılandırma sözlüğü.

    Raises:
        SystemExit: Yapılandırma dosyası bulunamazsa.
    """
    if not os.path.exists(CONFIG_FILE):
        print(f"❌ {CONFIG_FILE} yapılandırma dosyası bulunamadı!")
        print("   İlk kurulum için: sudo webyonet --setup")
        sys.exit(1)

    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f) or {}

    # Varsayılan değerleri doldur
    for key, default_value in DEFAULT_CONFIG.items():
        config.setdefault(key, default_value)

    return config


def save_config(config: dict) -> None:
    """Yapılandırmayı dosyaya kaydeder.

    Args:
        config: Kaydedilecek yapılandırma sözlüğü.
    """
    os.makedirs(CONFIG_DIR, exist_ok=True)

    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

    set_secure_permissions(CONFIG_FILE, 0o644)
    print(f"✅ {CONFIG_FILE} güncellendi.")


def check_setup() -> dict:
    """İlk kurulum kontrolü. Eksik yapılandırmaları interaktif olarak doldurur.

    Returns:
        Yapılandırma sözlüğü.
    """
    # Dizin kontrolü
    if not os.path.isdir(CONFIG_DIR):
        print(f"📂 Yapılandırma dizini oluşturuluyor: {CONFIG_DIR}")
        os.makedirs(CONFIG_DIR, mode=0o755, exist_ok=True)

    # Yapılandırma dosyası kontrolü
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f) or {}
        for key, default_value in DEFAULT_CONFIG.items():
            config.setdefault(key, default_value)
    else:
        config = dict(DEFAULT_CONFIG)

    # Eksik değişken kontrolü
    if not config.get("web_server") or not config.get("server_ip"):
        print("📝 Yapılandırma değişkenleri eksik. Lütfen aşağıdaki bilgileri girin:")

        if not config.get("web_server"):
            value = input(f"Web Sunucusu (nginx/apache) [{config.get('web_server', '')}]: ").strip()
            if value:
                config["web_server"] = value

        if not config.get("server_ip"):
            value = input(f"Sunucu IP Adresi [{config.get('server_ip', '')}]: ").strip()
            if value:
                config["server_ip"] = value

        if not config.get("cf_domain"):
            value = input(f"Cloudflare Domain (Opsiyonel) [{config.get('cf_domain', '')}]: ").strip()
            if value:
                config["cf_domain"] = value

        if not config.get("cloudflare_api_token"):
            value = input("Cloudflare API Token (Opsiyonel): ").strip()
            if value:
                config["cloudflare_api_token"] = value

        if not config.get("cloudflare_zone_id"):
            value = input("Cloudflare Zone ID (Opsiyonel): ").strip()
            if value:
                config["cloudflare_zone_id"] = value

        # DB names yapılandırması
        if not config.get("db_names"):
            print("\n📋 WordPress veritabanı temizleme için veritabanı isimleri")
            print("   Her satıra bir veritabanı adı girin. Bitirmek için boş bırakıp Enter'a basın.")
            db_names = []
            while True:
                name = input("  Veritabanı adı (boş = bitir): ").strip()
                if not name:
                    break
                db_names.append(name)
            if db_names:
                config["db_names"] = db_names

        # Backup remote yapılandırması
        if not config.get("backup_remote"):
            value = input("\n☁️  rclone remote adı (örn: gdrive): ").strip()
            if value:
                config["backup_remote"] = value

        # Backup list yapılandırması
        if not config.get("backup_list"):
            print("\n📂 Yedekleme hedeflerini yapılandırın.")
            print("   Her hedef için yerel dizin, uzak dizin ve yedek dizin bilgisi gereklidir.")
            print("   Bitirmek için yerel dizin alanını boş bırakıp Enter'a basın.")
            backup_list = []
            while True:
                print(f"\n  --- Hedef #{len(backup_list) + 1} ---")
                local_dir = input("  Yerel dizin (örn: /home) (boş = bitir): ").strip()
                if not local_dir:
                    break
                remote_dir = input("  Uzak dizin (örn: Backups/HomeBackups): ").strip()
                if not remote_dir:
                    break
                backup_dir = input(f"  Yedek dizin (örn: ~/.backup/HomeBackups): ").strip()
                if not backup_dir:
                    break

                exclude_input = input("  Hariç tutulacak desenler, virgülle ayırın (boş = yok): ").strip()
                exclude = [e.strip() for e in exclude_input.split(",") if e.strip()] if exclude_input else []

                only_subdirs_input = input("  Sadece alt dizinleri mi yedekle? (e/h) [h]: ").strip().lower()
                only_subdirs = only_subdirs_input == "e"

                backup_list.append({
                    "local_dir": local_dir,
                    "remote_dir": remote_dir,
                    "backup_dir": backup_dir,
                    "exclude": exclude,
                    "only_subdirs": only_subdirs,
                })
                print(f"  ✅ Hedef eklendi: {local_dir}")

            if backup_list:
                config["backup_list"] = backup_list

        # DB backup dizinleri
        if not config.get("db_backup_dir"):
            value = input("\n💾 Veritabanı yerel yedek dizini (örn: ~/.backup/db): ").strip()
            if value:
                config["db_backup_dir"] = value

        if not config.get("db_remote_dir"):
            value = input("💾 Veritabanı uzak dizin (örn: Backups/DBBackups): ").strip()
            if value:
                config["db_remote_dir"] = value

        save_config(config)

    # rclone.conf kontrolü
    if not os.path.exists(RCLONE_CONFIG):
        print("🚀 rclone yapılandırması bulunamadı. Kurulum başlatılıyor...")
        run_cmd(["rclone", "config", "--config", RCLONE_CONFIG], check=False)

    # mysql-backup.cnf kontrolü
    if not os.path.exists(MYSQL_CONFIG):
        print("🔑 MySQL yedekleme kullanıcısı bilgileri eksik.")
        db_user = input("MySQL yedekleme kullanıcı adı [backup]: ").strip() or "backup"
        db_pass = getpass.getpass("MySQL yedekleme şifresi: ")
        db_host = input("MySQL sunucu adresi [localhost]: ").strip() or "localhost"

        with open(MYSQL_CONFIG, "w", encoding="utf-8") as f:
            f.write(f"[client]\nuser={db_user}\npassword={db_pass}\nhost={db_host}\n")

        set_secure_permissions(MYSQL_CONFIG, 0o600)
        print(f"✅ {MYSQL_CONFIG} oluşturuldu (izinler 600 olarak ayarlandı).")

    return config
