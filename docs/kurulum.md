# Kurulum Kılavuzu

## Gereksinimler

- **İşletim Sistemi**: Debian/Ubuntu tabanlı Linux dağıtımı
- **Python**: 3.10 veya üstü
- **Root Erişimi**: `sudo` yetkisi gereklidir

## Python Bağımlılıkları

| Paket | Açıklama |
|---|---|
| `python3-yaml` | YAML yapılandırma dosyası okuma/yazma |
| `python3-requests` | Cloudflare API iletişimi |

## Sistem Bağımlılıkları

| Paket | Açıklama |
|---|---|
| `rclone` | Bulut depolama (Google Drive, Yandex Disk vb.) |
| `certbot` | Let's Encrypt SSL sertifikası |
| `curl` | HTTP istekleri |
| `jq` | JSON işleme |
| `unzip` | ZIP arşiv açma |
| `pv` | İlerleme çubuğu |

## Kurulum Adımları

### 1. Deb Paketi ile Kurulum (Önerilen)

```bash
# Paketi oluştur
bash make-deb.sh

# Paketi kur
sudo dpkg -i webyonet-2.0.3.deb

# Eksik bağımlılıkları otomatik kur
sudo apt install -f
```

### 2. Manuel Kurulum

```bash
# Bağımlılıkları kur
sudo apt install python3 python3-yaml python3-requests rclone certbot curl jq unzip pv

# Python dosyalarını kopyala
sudo mkdir -p /usr/local/lib/webyonet/templates
sudo cp webyonet/*.py /usr/local/lib/webyonet/
sudo cp webyonet/templates/*.conf /usr/local/lib/webyonet/templates/

# CLI wrapper'ı kopyala
sudo cp bin/webyonet /usr/local/bin/webyonet
sudo chmod +x /usr/local/bin/webyonet
```

### 3. MySQL Yedekleme Kullanıcısı

```bash
sudo mysql -u root -p
```

```sql
CREATE USER 'backup'@'localhost' IDENTIFIED BY 'GUVENLI_PAROLA';
GRANT SELECT, SHOW DATABASES, LOCK TABLES, SHOW VIEW ON *.* TO 'backup'@'localhost';
FLUSH PRIVILEGES;
```

### 4. İlk Yapılandırma

```bash
sudo webyonet --setup
```

Bu komut eksik yapılandırmaları interaktif olarak doldurmanızı isteyecektir.
