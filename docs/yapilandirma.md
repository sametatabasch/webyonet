# Yapılandırma Kılavuzu

## Yapılandırma Dosyası

Ana yapılandırma dosyası: `/etc/webyonet/webyonet.yaml`

İlk çalıştırmada `sudo webyonet --setup` komutu ile interaktif olarak oluşturulur.

## Yapılandırma Değişkenleri

```yaml
# Web sunucu türü: "nginx" veya "apache"
web_server: "nginx"

# Sunucu IP adresi (DNS A kaydı kontrolü için)
server_ip: "1.2.3.4"

# Cloudflare ayarları (opsiyonel - geçici subdomain desteği için)
cloudflare_api_token: "your-api-token"
cloudflare_zone_id: "your-zone-id"
cf_domain: "example.com"  # Geçici subdomain'ler bu domain altında oluşturulur

# WordPress DB temizleme için veritabanı isimleri
db_names:
  - wordpress_db1
  - wordpress_db2

# rclone remote adı
# rclone remote adı
backup_remote: ""
# Örnek: backup_remote: "gdrive"

# Yedekleme hedefleri
backup_list: []
# Örnek:
# backup_list:
#   - local_dir: "/home"
#     remote_dir: "Backups/HomeBackups"
#     backup_dir: "~/.backup/HomeBackups"
#     exclude: ["**/cache", "**/cache/*"]
#     only_subdirs: true

# Veritabanı yedekleme ayarları
db_backup_dir: ""
db_remote_dir: ""
# Örnek:
# db_backup_dir: "~/.backup/db"
# db_remote_dir: "Backups/DBBackups"
```

## Ek Yapılandırma Dosyaları

### rclone Yapılandırması

Dosya: `/etc/webyonet/rclone.conf`

İlk çalıştırmada otomatik olarak `rclone config` sihirbazı başlatılır. Google Drive, Yandex Disk veya başka bir hedef yapılandırılabilir.

### MySQL Yedekleme Ayarları

Dosya: `/etc/webyonet/mysql-backup.cnf`
İzinler: 600 (sadece root okuyabilir)

```ini
[client]
user=backup
password=GUVENLI_PAROLA
host=localhost
```

## Dosya İzinleri

| Dosya | İzin | Açıklama |
|---|---|---|
| `/etc/webyonet/webyonet.yaml` | 644 | Yapılandırma (hassas token içerebilir) |
| `/etc/webyonet/mysql-backup.cnf` | 600 | MySQL şifresi içerir |
| `/etc/webyonet/rclone.conf` | 600 | Bulut depolama kimlik bilgileri |

## Web Sunucu Şablonları

Şablon dosyaları `/usr/local/lib/webyonet/templates/` dizininde bulunur:

- `nginx_site.conf` - Nginx vhost şablonu
- `apache_site.conf` - Apache vhost şablonu

Şablonlardaki `SUBDOMAIN` ve `WEB_DIR` yer tutucuları site oluşturma sırasında gerçek değerlerle değiştirilir.
