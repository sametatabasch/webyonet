# Webyonet

Nginx ve Apache üzerinde web sitelerini yönetmek için geliştirilen Python tabanlı terminal aracı.

## Özellikler

- 🌐 **Site Yönetimi**: Yeni site oluşturma, domain değiştirme, site silme
- 🔒 **Otomatik SSL**: Let's Encrypt sertifikası (Certbot entegrasyonu)
- ☁️ **Cloudflare DNS**: Otomatik DNS kaydı oluşturma/silme
- 📦 **WordPress**: Otomatik WordPress kurulumu
- 💾 **Yedekleme**: Home dizinleri ve veritabanlarını rclone ile buluta yedekleme
- 🧹 **DB Temizleme**: WordPress veritabanı optimizasyonu
- 🖥️ **Çoklu Web Sunucu**: Nginx ve Apache desteği

## Kurulum

### Deb Paketi ile (Önerilen)

```bash
./make-deb.sh
sudo dpkg -i webyonet-2.0.0.deb
# Eksik bağımlılıklar için:
sudo apt install -f
```

### Bağımlılıklar

- Python 3.10+
- `python3-yaml` - YAML yapılandırma
- `python3-requests` - Cloudflare API
- `rclone` - Bulut depolama
- `certbot` - SSL sertifikası
- `curl`, `jq`, `unzip`, `pv`

### Veritabanı Yedekleme Kullanıcısı

MySQL "backup" kullanıcısını oluşturun:

```bash
sudo mysql -u root -p
```

```sql
-- 1️⃣ Yedekleme kullanıcısını oluştur
CREATE USER 'backup'@'localhost' IDENTIFIED BY 'GUVENLI_PAROLA';

-- 2️⃣ Gerekli minimum izinleri ver
GRANT SELECT, SHOW DATABASES, LOCK TABLES, SHOW VIEW ON *.* TO 'backup'@'localhost';

-- 3️⃣ İzinleri yenile
FLUSH PRIVILEGES;
```

## Kullanım

### İnteraktif Menü

```bash
sudo webyonet
```

### Komut Satırı

```bash
# Home dizinlerini yedekle
sudo webyonet --backup

# Veritabanlarını yedekle
sudo webyonet --database-backup

# WordPress DB temizle
sudo webyonet --wp-clean

# Yapılandırma sihirbazı
sudo webyonet --setup

# Versiyon bilgisi
sudo webyonet --version
```

## Yapılandırma

Yapılandırma dosyası: `/etc/webyonet/webyonet.yaml`

İlk çalıştırmada `sudo webyonet --setup` komutu ile interaktif olarak yapılandırılır.

Ayrıca oluşturulan dosyalar:
- `/etc/webyonet/rclone.conf` - rclone bulut depolama ayarları
- `/etc/webyonet/mysql-backup.cnf` - MySQL yedekleme kullanıcı bilgileri (izin: 600)

## Proje Yapısı

```
webyonet/
├── webyonet/                  # Python paketi
│   ├── __init__.py
│   ├── __main__.py            # python3 -m webyonet desteği
│   ├── cli.py                 # CLI ve interaktif menü
│   ├── config.py              # YAML yapılandırma yönetimi
│   ├── logger.py              # Loglama yardımcıları
│   ├── utils.py               # Ortak yardımcı fonksiyonlar
│   ├── site_manager.py        # Site oluşturma/silme/domain değiştirme
│   ├── webserver.py           # Nginx/Apache yapılandırma
│   ├── cloudflare.py          # Cloudflare DNS API
│   ├── backup.py              # Dizin yedekleme
│   ├── db_backup.py           # MySQL veritabanı yedekleme
│   ├── wp_db_clean.py         # WordPress DB temizleme
│   └── templates/
│       ├── nginx_site.conf    # Nginx vhost şablonu
│       └── apache_site.conf   # Apache vhost şablonu
├── bin/
│   └── webyonet               # CLI wrapper
├── config/
│   └── webyonet.yaml.example  # Örnek yapılandırma
├── docs/
│   ├── kurulum.md
│   ├── kullanim.md
│   └── yapilandirma.md
├── make-deb.sh                # Deb paket oluşturma
├── setup.py                   # Python paket tanımı
├── requirements.txt           # Python bağımlılıkları
└── readme.md
```