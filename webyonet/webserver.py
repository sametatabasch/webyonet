"""Nginx ve Apache web sunucu yapılandırma yönetimi."""

import os
import shutil

from webyonet.config import TEMPLATES_DIR
from webyonet.logger import setup_logger
from webyonet.utils import reload_service, run_cmd

logger = setup_logger(__name__)


# ──────────────────── Nginx ────────────────────


def setup_nginx(subdomain: str, web_dir: str) -> bool:
    """Nginx vhost yapılandırmasını oluşturur ve etkinleştirir.

    Args:
        subdomain: Site domain/subdomain adı.
        web_dir: Web kök dizini yolu.

    Returns:
        True ise başarılı.
    """
    template_path = os.path.join(TEMPLATES_DIR, "nginx_site.conf")
    if not os.path.exists(template_path):
        logger.error("❌ nginx_site.conf şablonu bulunamadı: %s", template_path)
        return False

    vhost_file = f"/etc/nginx/sites-available/{subdomain}.conf"

    with open(template_path, "r", encoding="utf-8") as f:
        content = f.read()

    content = content.replace("SUBDOMAIN", subdomain)
    content = content.replace("WEB_DIR", web_dir)

    with open(vhost_file, "w", encoding="utf-8") as f:
        f.write(content)

    # Symlink oluştur
    enabled_link = f"/etc/nginx/sites-enabled/{subdomain}.conf"
    if os.path.exists(enabled_link):
        os.remove(enabled_link)
    os.symlink(vhost_file, enabled_link)

    # Yapılandırma testi
    result = run_cmd(["nginx", "-t"], check=False, capture=True)
    if result.returncode != 0:
        logger.error("❌ Nginx yapılandırma hatası: %s", result.stderr)
        return False

    reload_service("nginx")
    logger.info("✅ Nginx yapılandırması başarıyla ayarlandı: %s", vhost_file)
    return True


def remove_nginx_site(domain: str) -> bool:
    """Nginx site yapılandırmasını kaldırır.

    Args:
        domain: Kaldırılacak site domain adı.

    Returns:
        True ise başarılı.
    """
    conf_file = f"/etc/nginx/sites-available/{domain}.conf"
    enabled_file = f"/etc/nginx/sites-enabled/{domain}.conf"

    removed = False
    if os.path.exists(conf_file):
        os.remove(conf_file)
        removed = True
    if os.path.exists(enabled_file):
        os.remove(enabled_file)
        removed = True

    if removed:
        logger.info("[✓] Nginx yapılandırması kaldırıldı.")
        reload_service("nginx")
    else:
        logger.warning("[!] Nginx yapılandırması bulunamadı.")

    return removed


# ──────────────────── Apache ────────────────────


def setup_apache(subdomain: str, web_dir: str, username: str) -> bool:
    """Apache vhost yapılandırmasını oluşturur ve etkinleştirir.

    Args:
        subdomain: Site domain/subdomain adı.
        web_dir: Web kök dizini yolu.
        username: Site sahibi kullanıcı adı.

    Returns:
        True ise başarılı.
    """
    template_path = os.path.join(TEMPLATES_DIR, "apache_site.conf")
    if not os.path.exists(template_path):
        logger.error("❌ apache_site.conf şablonu bulunamadı: %s", template_path)
        return False

    vhost_file = f"/etc/apache2/sites-available/{subdomain}.conf"

    with open(template_path, "r", encoding="utf-8") as f:
        content = f.read()

    content = content.replace("SUBDOMAIN", subdomain)
    content = content.replace("WEB_DIR", web_dir)
    content = content.replace("USERNAME", username)

    with open(vhost_file, "w", encoding="utf-8") as f:
        f.write(content)

    # .htaccess oluştur
    htaccess_path = os.path.join(web_dir, ".htaccess")
    if not os.path.exists(htaccess_path):
        open(htaccess_path, "a", encoding="utf-8").close()
        run_cmd(["chown", f"{username}:www-data", htaccess_path], check=False)

    # Siteyi etkinleştir
    run_cmd(["a2ensite", subdomain], check=False, capture=True)
    reload_service("apache2")
    logger.info("✅ Apache yapılandırması başarıyla ayarlandı: %s", vhost_file)
    return True


def remove_apache_site(domain: str) -> bool:
    """Apache site yapılandırmasını kaldırır.

    Args:
        domain: Kaldırılacak site domain adı.

    Returns:
        True ise başarılı.
    """
    conf_file = f"/etc/apache2/sites-available/{domain}.conf"

    if os.path.exists(conf_file):
        run_cmd(["a2dissite", f"{domain}.conf"], check=False, capture=True)
        os.remove(conf_file)
        enabled_file = f"/etc/apache2/sites-enabled/{domain}.conf"
        if os.path.exists(enabled_file):
            os.remove(enabled_file)
        reload_service("apache2")
        logger.info("[✓] Apache yapılandırması kaldırıldı.")
        return True
    else:
        logger.warning("[!] Apache yapılandırması bulunamadı.")
        return False


# ──────────────────── Ortak ────────────────────


def setup_webserver(web_server: str, subdomain: str, web_dir: str, username: str = "") -> bool:
    """Web sunucu türüne göre vhost yapılandırması kurar.

    Args:
        web_server: Web sunucu türü ("nginx" veya "apache").
        subdomain: Site domain/subdomain adı.
        web_dir: Web kök dizini yolu.
        username: Site sahibi kullanıcı adı (Apache için gerekli).

    Returns:
        True ise başarılı.
    """
    if web_server == "nginx":
        return setup_nginx(subdomain, web_dir)
    elif web_server == "apache":
        return setup_apache(subdomain, web_dir, username)
    else:
        logger.error("❌ Desteklenmeyen web sunucusu: %s", web_server)
        return False


def remove_webserver_site(web_server: str, domain: str) -> bool:
    """Web sunucu türüne göre site yapılandırmasını kaldırır.

    Args:
        web_server: Web sunucu türü ("nginx" veya "apache").
        domain: Kaldırılacak site domain adı.

    Returns:
        True ise başarılı.
    """
    if web_server == "nginx":
        return remove_nginx_site(domain)
    elif web_server == "apache":
        return remove_apache_site(domain)
    else:
        logger.error("❌ Desteklenmeyen web sunucusu: %s", web_server)
        return False
