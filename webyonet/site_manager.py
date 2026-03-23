"""Site oluşturma, silme ve domain değiştirme işlemleri."""

import os
import shutil
from pathlib import Path

from webyonet.cloudflare import create_dns_record, delete_dns_record
from webyonet.logger import setup_logger
from webyonet.utils import (
    command_exists,
    ensure_dir,
    resolve_dns,
    run_cmd,
    user_exists,
    validate_domain,
    validate_username,
)
from webyonet.webserver import remove_webserver_site, setup_webserver

logger = setup_logger(__name__)


def create_site(config: dict) -> None:
    """Yeni site oluşturur: kullanıcı, dizin, DNS, web sunucu, SSL, WordPress.

    Args:
        config: Yapılandırma sözlüğü.
    """
    web_server = config.get("web_server", "")
    server_ip = config.get("server_ip", "")
    cf_domain = config.get("cf_domain", "")
    cf_token = config.get("cloudflare_api_token", "")
    cf_zone = config.get("cloudflare_zone_id", "")

    # ── Kullanıcı girdisi ──
    domain = input("Site için domain adı girin (örn: gencbilisim.net): ").strip()
    if not validate_domain(domain):
        print(f"❌ Geçersiz domain adı: {domain}")
        return

    username = input("Yeni sistem kullanıcı adı girin: ").strip()
    if not validate_username(username):
        print(f"❌ Geçersiz kullanıcı adı: {username}")
        print("   Kullanıcı adı küçük harf, rakam, tire ve alt çizgi içerebilir.")
        return

    # ── DNS kontrolü ──
    dns_ips = resolve_dns(domain)
    if not dns_ips:
        print(f"❌ {domain} için DNS kaydı bulunamadı.")
        if cf_domain:
            subdomain = f"{domain.split('.')[0]}.{cf_domain}"
            print(f"   Geçici alt domain oluşturulacak: {subdomain}")
        else:
            print("   Cloudflare domain ayarlanmamış. İşlem iptal.")
            return
    else:
        print(f"✅ {domain} için DNS kaydı bulundu.")
        subdomain = domain

    # ── IP eşleşme kontrolü ──
    if server_ip and dns_ips:
        if server_ip not in dns_ips:
            print(f"❌ DNS'deki A kaydı ({', '.join(dns_ips)}) sunucu IP'si ({server_ip}) ile eşleşmiyor.")
            print("   İşlem iptal edildi.")
            return
        else:
            print("✅ DNS A kaydı sunucu IP'si ile eşleşiyor. Devam ediliyor.")
    elif not server_ip:
        print("⚠️ SERVER_IP config'de tanımlı değil; DNS-IP kontrolü atlanıyor.")

    # ── Kullanıcı oluşturma ──
    if user_exists(username):
        print(f"ℹ️ {username} adlı kullanıcı zaten mevcut, oluşturma adımı atlanıyor.")
    else:
        run_cmd(["useradd", "-m", "-s", "/bin/bash", username])
        ssh_dir = f"/home/{username}/.ssh"
        ensure_dir(ssh_dir, owner=f"{username}:{username}", mode=0o700)

        run_cmd([
            "ssh-keygen", "-q", "-t", "rsa", "-b", "2048",
            "-N", "", "-f", f"{ssh_dir}/id_rsa",
        ], check=False)

        # authorized_keys
        pub_key_path = f"{ssh_dir}/id_rsa.pub"
        auth_keys_path = f"{ssh_dir}/authorized_keys"
        if os.path.exists(pub_key_path):
            shutil.copy2(pub_key_path, auth_keys_path)
            os.chmod(auth_keys_path, 0o600)

        run_cmd(["chown", "-R", f"{username}:{username}", ssh_dir], check=False)

    # ── Web dizini oluşturma ──
    web_dir = f"/home/{username}/www/{subdomain}/public_html"
    ensure_dir(web_dir, owner=f"{username}:www-data", mode=0o775)

    # Üst dizinlerde web sunucunun erişebilmesi için +x
    os.chmod(f"/home/{username}", 0o711)
    os.chmod(f"/home/{username}/www", 0o711)

    # ── Web sunucu yapılandırması ──
    setup_webserver(web_server, subdomain, web_dir, username)

    # ── Cloudflare DNS kaydı (geçici subdomain ise) ──
    if subdomain != domain and cf_token and cf_zone and server_ip:
        print(f"☁ Cloudflare'da geçici DNS kaydı oluşturuluyor: {subdomain} → {server_ip}")
        create_dns_record(cf_zone, cf_token, subdomain, server_ip)

    # ── HTTPS sertifikası ──
    if command_exists("certbot"):
        print("\n🔒 HTTPS sertifikası alınıyor ve etkinleştiriliyor...")
        certbot_plugin = "--nginx" if web_server == "nginx" else "--apache"
        result = run_cmd(
            [
                "certbot", certbot_plugin,
                "-d", subdomain,
                "--non-interactive", "--agree-tos",
                "-m", f"admin@{subdomain}",
                "--redirect",
            ],
            check=False,
            capture=True,
        )
        if result.returncode == 0:
            print(f"✅ HTTPS aktif edildi: https://{subdomain}")
        else:
            print("❌ HTTPS sertifikası alınamadı. Manuel olarak deneyebilirsiniz:")
            print(f"  sudo certbot {certbot_plugin} -d {subdomain}")
    else:
        print("⚠️ Certbot kurulu değil. HTTPS sertifikası alınamadı.")

    # ── SSH key göster ──
    ssh_key_file = f"/home/{username}/.ssh/id_rsa"
    if os.path.exists(ssh_key_file):
        print("\n🔑 SSH bağlantısı için private key:")
        with open(ssh_key_file, "r", encoding="utf-8") as f:
            print(f.read())

    # ── WordPress kurulumu ──
    install_wp = input("📦 WordPress kurulumu yapılsın mı? (e/h): ").strip().lower()
    if install_wp == "e":
        _install_wordpress(web_dir, username, subdomain)

    print(f"\n✅ Site kurulumu tamamlandı: https://{subdomain}")


def _install_wordpress(web_dir: str, username: str, subdomain: str) -> None:
    """WordPress dosyalarını indirir ve kurar.

    Args:
        web_dir: Web kök dizini.
        username: Site sahibi kullanıcı adı.
        subdomain: Site domain adı.
    """
    if not command_exists("wget") or not command_exists("unzip"):
        print("❌ wget veya unzip kurulu değil.")
        return

    print("📥 WordPress indiriliyor...")
    wp_zip = "/tmp/wordpress.zip"
    wp_tmp = "/tmp/wordpress"

    run_cmd(["wget", "-q", "https://tr.wordpress.org/latest-tr_TR.zip", "-O", wp_zip], check=False)

    if not os.path.exists(wp_zip):
        print("❌ WordPress indirilemedi.")
        return

    run_cmd(["unzip", "-qo", wp_zip, "-d", "/tmp"], check=False)

    if os.path.isdir(wp_tmp):
        for item in os.listdir(wp_tmp):
            src = os.path.join(wp_tmp, item)
            dst = os.path.join(web_dir, item)
            if os.path.isdir(src):
                shutil.copytree(src, dst, dirs_exist_ok=True)
            else:
                shutil.copy2(src, dst)

        run_cmd(["chown", "-R", f"{username}:www-data", web_dir], check=False)
        os.chmod(web_dir, 0o775)
        print("✅ WordPress dosyaları yüklendi. Kurulum sihirbazı için:")
        print(f"👉 https://{subdomain}")

        # Temizlik
        shutil.rmtree(wp_tmp, ignore_errors=True)
        os.remove(wp_zip)
    else:
        print("❌ WordPress arşivi açılamadı.")


def delete_site(config: dict) -> None:
    """Siteyi tamamen siler: vhost, SSL, DNS, dizin, kullanıcı.

    Args:
        config: Yapılandırma sözlüğü.
    """
    web_server = config.get("web_server", "")
    cf_token = config.get("cloudflare_api_token", "")
    cf_zone = config.get("cloudflare_zone_id", "")

    username = input("Kullanıcı adı: ").strip()
    if not validate_username(username):
        print(f"❌ Geçersiz kullanıcı adı: {username}")
        return

    domain = input("Silinecek domain (örn: gencbilisim.net): ").strip()
    if not validate_domain(domain):
        print(f"❌ Geçersiz domain: {domain}")
        return

    basedir = f"/home/{username}/www"
    sitedir = os.path.join(basedir, domain)

    # ── Web sunucu yapılandırmasını kaldır ──
    remove_webserver_site(web_server, domain)

    # ── SSL sertifikasını kaldır ──
    if command_exists("certbot"):
        result = run_cmd(["certbot", "certificates"], check=False, capture=True)
        if domain in (result.stdout or ""):
            print("[✓] SSL sertifikası siliniyor...")
            run_cmd(
                ["certbot", "revoke", "--cert-name", domain, "--non-interactive", "--quiet", "--delete-after-revoke"],
                check=False,
            )
            run_cmd(
                ["certbot", "delete", "--cert-name", domain, "--non-interactive", "--quiet"],
                check=False,
            )
        else:
            print("[!] SSL sertifikası bulunamadı.")

    # ── Web dizinini sil ──
    if os.path.isdir(sitedir):
        print(f"[✓] Web dizini siliniyor: {sitedir}")
        shutil.rmtree(sitedir)
    else:
        print(f"[!] Web dizini bulunamadı: {sitedir}")

    # ── Cloudflare DNS kaydını sil ──
    if cf_token and cf_zone:
        print("[✓] Cloudflare DNS kaydı siliniyor...")
        delete_dns_record(cf_zone, cf_token, domain)

    # ── Kullanıcıyı sil (başka sitesi yoksa) ──
    if os.path.isdir(basedir):
        site_count = len([d for d in os.listdir(basedir) if os.path.isdir(os.path.join(basedir, d))])
    else:
        site_count = 0

    if site_count == 0:
        print("[✓] Kullanıcının başka sitesi kalmadı. Kullanıcı siliniyor...")
        run_cmd(["deluser", "--remove-home", username], check=False)
    else:
        print("[i] Kullanıcının başka sitesi var. Kullanıcı silinmedi.")


def change_domain(config: dict) -> None:
    """Geçici subdomain'i gerçek domain ile değiştirir.

    Args:
        config: Yapılandırma sözlüğü.
    """
    web_server = config.get("web_server", "")

    username = input("Kullanıcı adı: ").strip()
    if not validate_username(username):
        print(f"❌ Geçersiz kullanıcı adı: {username}")
        return

    old_domain = input("Eski (geçici) domain adı: ").strip()
    if not validate_domain(old_domain):
        print(f"❌ Geçersiz domain: {old_domain}")
        return

    new_domain = input("Yeni domain adı (gerçek domain): ").strip()
    if not validate_domain(new_domain):
        print(f"❌ Geçersiz domain: {new_domain}")
        return

    old_dir = f"/home/{username}/www/{old_domain}"
    new_dir = f"/home/{username}/www/{new_domain}"

    if not os.path.isdir(old_dir):
        print(f"❌ {old_domain} dizini bulunamadı.")
        return

    # Dizin taşıma
    os.makedirs(new_dir, exist_ok=True)
    for item in os.listdir(old_dir):
        src = os.path.join(old_dir, item)
        dst = os.path.join(new_dir, item)
        shutil.move(src, dst)

    # Boş eski dizini sil
    try:
        os.rmdir(old_dir)
    except OSError:
        shutil.rmtree(old_dir, ignore_errors=True)

    # Eski web sunucu yapılandırmasını kaldır
    remove_webserver_site(web_server, old_domain)

    # Yeni web sunucu yapılandırmasını kur
    web_dir = f"{new_dir}/public_html"
    if not os.path.isdir(web_dir):
        web_dir = new_dir
    setup_webserver(web_server, new_domain, web_dir, username)

    print(f"🔁 Domain güncellendi: {old_domain} → {new_domain}")
    print(f"🌐 http://{new_domain} adresinden erişebilirsiniz.")
    print("🎯 HTTPS kurmak için:")
    certbot_plugin = "--nginx" if web_server == "nginx" else "--apache"
    print(f"  sudo certbot {certbot_plugin} -d {new_domain}")
