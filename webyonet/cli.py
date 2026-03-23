"""CLI giriş noktası ve interaktif menü."""

import argparse
import sys

from webyonet import __version__
from webyonet.utils import check_root, command_exists


def show_menu() -> None:
    """Interaktif menüyü gösterir."""
    print("")
    print("🔧 Web Sitesi Yönetim Paneli")
    print("1) Yeni site oluştur")
    print("2) Geçici subdomain'i gerçek domain ile değiştir")
    print("3) Siteyi sil")
    print("4) Home dizin(leri)ni yedekle")
    print("5) Veritabanlarını yedekle")
    print("6) WordPress veritabanlarını temizle ve optimize et")
    print("7) Yapılandırmayı yeniden kur")
    print("8) Çıkış")


def run_menu() -> None:
    """Interaktif menü döngüsünü çalıştırır."""
    from webyonet.config import check_setup

    # Ortam kontrolleri
    if not command_exists("certbot"):
        print("❌ Certbot kurulu değil. Kurmak için:")
        print("   sudo apt install certbot")
        sys.exit(1)

    config = check_setup()

    while True:
        show_menu()
        choice = input("Seçiminiz [1-8]: ").strip()

        if choice == "1":
            from webyonet.site_manager import create_site
            create_site(config)

        elif choice == "2":
            from webyonet.site_manager import change_domain
            change_domain(config)

        elif choice == "3":
            from webyonet.site_manager import delete_site
            delete_site(config)

        elif choice == "4":
            from webyonet.backup import run_backup
            run_backup()

        elif choice == "5":
            from webyonet.db_backup import run_db_backup
            run_db_backup()

        elif choice == "6":
            from webyonet.wp_db_clean import run_wp_db_clean
            run_wp_db_clean()

        elif choice == "7":
            from webyonet.config import check_setup as setup
            # Mevcut config dosyasını yedekle ve yeniden oluştur
            import os
            from webyonet.config import CONFIG_FILE
            if os.path.exists(CONFIG_FILE):
                os.rename(CONFIG_FILE, CONFIG_FILE + ".bak")
                print(f"📋 Eski yapılandırma yedeklendi: {CONFIG_FILE}.bak")
            config = setup()

        elif choice == "8":
            print("👋 Görüşmek üzere.")
            break

        else:
            print("Geçersiz seçim!")


def main() -> None:
    """Ana CLI giriş noktası."""
    parser = argparse.ArgumentParser(
        prog="webyonet",
        description="Web Sitesi Yönetim Aracı",
    )
    parser.add_argument(
        "-v", "--version",
        action="version",
        version=f"webyonet {__version__}",
    )
    parser.add_argument(
        "-b", "--backup",
        action="store_true",
        help="Home dizin(leri)ni yedekle",
    )
    parser.add_argument(
        "-db", "--database-backup",
        action="store_true",
        help="Veritabanlarını yedekle",
    )
    parser.add_argument(
        "--wp-clean",
        action="store_true",
        help="WordPress veritabanlarını temizle ve optimize et",
    )
    parser.add_argument(
        "--setup",
        action="store_true",
        help="Yapılandırma sihirbazını başlat",
    )

    args = parser.parse_args()

    check_root()

    if args.backup:
        from webyonet.backup import run_backup
        run_backup()
    elif args.database_backup:
        from webyonet.db_backup import run_db_backup
        run_db_backup()
    elif args.wp_clean:
        from webyonet.wp_db_clean import run_wp_db_clean
        run_wp_db_clean()
    elif args.setup:
        from webyonet.config import check_setup
        import os
        from webyonet.config import CONFIG_FILE
        if os.path.exists(CONFIG_FILE):
            os.rename(CONFIG_FILE, CONFIG_FILE + ".bak")
            print(f"📋 Eski yapılandırma yedeklendi: {CONFIG_FILE}.bak")
        check_setup()
    else:
        run_menu()
