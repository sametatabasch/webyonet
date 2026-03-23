"""Loglama yardımcıları."""

import logging
import os
import sys
from datetime import datetime
from pathlib import Path


def setup_logger(
    name: str = "webyonet",
    log_file: str | None = None,
    level: int = logging.INFO,
) -> logging.Logger:
    """Logger oluşturur. Hem konsola hem dosyaya yazar.

    Args:
        name: Logger adı.
        log_file: Log dosyasının yolu. None ise sadece konsola yazar.
        level: Log seviyesi.

    Returns:
        Yapılandırılmış Logger nesnesi.
    """
    logger = logging.getLogger(name)
    logger.setLevel(level)

    # Tekrar handler eklenmesini önle
    if logger.handlers:
        return logger

    formatter = logging.Formatter(
        fmt="[%(asctime)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # Konsol handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # Dosya handler (isteğe bağlı)
    if log_file:
        log_dir = os.path.dirname(log_file)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setLevel(level)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

    return logger


def get_log_path(prefix: str = "webyonet") -> str:
    """Tarih bazlı log dosyası yolu döndürür.

    Args:
        prefix: Log dosyası ön eki.

    Returns:
        Log dosyasının tam yolu.
    """
    log_dir = Path.home() / ".backup"
    log_dir.mkdir(parents=True, exist_ok=True)
    date_str = datetime.now().strftime("%d-%m-%Y")
    return str(log_dir / f"{prefix}-{date_str}.log")
