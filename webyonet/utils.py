"""Ortak yardımcı fonksiyonlar."""

import os
import re
import shutil
import socket
import subprocess
import sys


def check_root() -> None:
    """Root yetkisi kontrolü. Root değilse programı sonlandırır."""
    if os.geteuid() != 0:
        print("❌ Bu programı çalıştırmak için root (sudo) yetkisine sahip olmalısınız.")
        sys.exit(1)


def run_cmd(
    cmd: list[str],
    check: bool = True,
    capture: bool = False,
    **kwargs,
) -> subprocess.CompletedProcess:
    """Güvenli subprocess çalıştırıcı (shell=False).

    Args:
        cmd: Komut ve argüman listesi.
        check: True ise hata durumunda CalledProcessError fırlatır.
        capture: True ise stdout/stderr yakalar.
        **kwargs: subprocess.run'a iletilecek ek argümanlar.

    Returns:
        CompletedProcess nesnesi.
    """
    if capture:
        kwargs.setdefault("stdout", subprocess.PIPE)
        kwargs.setdefault("stderr", subprocess.PIPE)
        kwargs.setdefault("text", True)
    return subprocess.run(cmd, check=check, **kwargs)


def command_exists(name: str) -> bool:
    """Verilen komutun sistemde kurulu olup olmadığını kontrol eder.

    Args:
        name: Komut adı.

    Returns:
        True ise komut mevcut.
    """
    return shutil.which(name) is not None


def resolve_dns(domain: str) -> list[str]:
    """Domain için A kayıtlarını (IPv4) çözümler.

    Args:
        domain: Çözümlenecek domain adı.

    Returns:
        IP adresleri listesi. Çözümlenemezse boş liste.
    """
    try:
        results = socket.getaddrinfo(domain, None, socket.AF_INET, socket.SOCK_STREAM)
        return list({r[4][0] for r in results})
    except socket.gaierror:
        return []


def validate_domain(domain: str) -> bool:
    """Domain adının geçerli olup olmadığını kontrol eder.

    Args:
        domain: Kontrol edilecek domain adı.

    Returns:
        True ise geçerli domain.
    """
    pattern = re.compile(
        r"^(?!-)[A-Za-z0-9-]{1,63}(?<!-)"
        r"(\.[A-Za-z0-9-]{1,63})*"
        r"\.[A-Za-z]{2,}$",
    )
    return bool(pattern.match(domain))


def validate_username(username: str) -> bool:
    """Linux kullanıcı adının geçerli olup olmadığını kontrol eder.

    Args:
        username: Kontrol edilecek kullanıcı adı.

    Returns:
        True ise geçerli kullanıcı adı.
    """
    pattern = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")
    return bool(pattern.match(username))


def user_exists(username: str) -> bool:
    """Linux kullanıcısının mevcut olup olmadığını kontrol eder.

    Args:
        username: Kontrol edilecek kullanıcı adı.

    Returns:
        True ise kullanıcı mevcut.
    """
    result = run_cmd(["id", username], check=False, capture=True)
    return result.returncode == 0


def set_secure_permissions(path: str, mode: int = 0o600) -> None:
    """Dosya izinlerini güvenli şekilde ayarlar.

    Args:
        path: Dosya yolu.
        mode: İzin modu (varsayılan 0o600).
    """
    os.chmod(path, mode)


def reload_service(service: str) -> bool:
    """Systemd servisini yeniden yükler.

    Args:
        service: Servis adı (ör: nginx, apache2).

    Returns:
        True ise başarılı.
    """
    result = run_cmd(["systemctl", "reload", service], check=False, capture=True)
    return result.returncode == 0


def ensure_dir(path: str, owner: str | None = None, mode: int = 0o755) -> None:
    """Dizin yoksa oluşturur, izinleri ayarlar.

    Args:
        path: Dizin yolu.
        owner: Sahiplik (ör: "user:group"). None ise değiştirmez.
        mode: Dizin izinleri.
    """
    os.makedirs(path, exist_ok=True)
    os.chmod(path, mode)
    if owner:
        run_cmd(["chown", owner, path], check=False)
