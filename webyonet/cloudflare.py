"""Cloudflare DNS API işlemleri."""

import requests

from webyonet.logger import setup_logger

logger = setup_logger(__name__)

API_BASE = "https://api.cloudflare.com/client/v4"


def _headers(api_token: str) -> dict:
    """Cloudflare API istek başlıklarını döndürür.

    Args:
        api_token: Cloudflare API token.

    Returns:
        HTTP başlık sözlüğü.
    """
    return {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json",
    }


def create_dns_record(
    zone_id: str,
    api_token: str,
    name: str,
    content: str,
    record_type: str = "A",
    ttl: int = 120,
    proxied: bool = False,
) -> bool:
    """Cloudflare'da DNS kaydı oluşturur.

    Args:
        zone_id: Cloudflare Zone ID.
        api_token: Cloudflare API token.
        name: DNS kayıt adı (ör: subdomain.example.com).
        content: DNS kayıt içeriği (ör: IP adresi).
        record_type: Kayıt türü (varsayılan A).
        ttl: TTL değeri saniye cinsinden.
        proxied: Cloudflare proxy aktif mi.

    Returns:
        True ise başarılı.
    """
    url = f"{API_BASE}/zones/{zone_id}/dns_records"
    payload = {
        "type": record_type,
        "name": name,
        "content": content,
        "ttl": ttl,
        "proxied": proxied,
    }

    try:
        resp = requests.post(url, json=payload, headers=_headers(api_token), timeout=30)
        data = resp.json()
        if data.get("success"):
            logger.info("✅ Cloudflare DNS kaydı oluşturuldu: %s → %s", name, content)
            return True
        else:
            errors = data.get("errors", [])
            logger.error("❌ Cloudflare DNS kaydı oluşturulamadı: %s", errors)
            return False
    except requests.RequestException as e:
        logger.error("❌ Cloudflare API isteği başarısız: %s", e)
        return False


def delete_dns_record(zone_id: str, api_token: str, name: str) -> bool:
    """Cloudflare'dan DNS kaydını siler.

    Args:
        zone_id: Cloudflare Zone ID.
        api_token: Cloudflare API token.
        name: Silinecek DNS kayıt adı.

    Returns:
        True ise başarılı.
    """
    # Önce kayıt ID'sini bul
    url = f"{API_BASE}/zones/{zone_id}/dns_records"
    params = {"name": name}

    try:
        resp = requests.get(url, params=params, headers=_headers(api_token), timeout=30)
        data = resp.json()

        if not data.get("success") or not data.get("result"):
            logger.warning("⚠️ Cloudflare DNS kaydı bulunamadı: %s", name)
            return False

        record_id = data["result"][0]["id"]

        # Kaydı sil
        delete_url = f"{API_BASE}/zones/{zone_id}/dns_records/{record_id}"
        del_resp = requests.delete(delete_url, headers=_headers(api_token), timeout=30)
        del_data = del_resp.json()

        if del_data.get("success"):
            logger.info("✅ Cloudflare DNS kaydı silindi: %s", name)
            return True
        else:
            logger.error("❌ Cloudflare DNS kaydı silinemedi: %s", del_data.get("errors", []))
            return False

    except requests.RequestException as e:
        logger.error("❌ Cloudflare API isteği başarısız: %s", e)
        return False
