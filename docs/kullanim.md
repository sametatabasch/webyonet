# Kullanım Kılavuzu

## Başlatma

Webyonet, root yetkisi gerektirir:

```bash
sudo webyonet
```

## Komut Satırı Seçenekleri

| Seçenek | Açıklama |
|---|---|
| (argümansız) | İnteraktif menüyü başlatır |
| `-b`, `--backup` | Home dizinlerini buluta yedekler |
| `-db`, `--database-backup` | MySQL veritabanlarını yedekler |
| `--wp-clean` | WordPress veritabanlarını temizler ve optimize eder |
| `--setup` | Yapılandırma sihirbazını başlatır |
| `-v`, `--version` | Versiyon bilgisini gösterir |

## İnteraktif Menü

```
🔧 Web Sitesi Yönetim Paneli
1) Yeni site oluştur
2) Geçici subdomain'i gerçek domain ile değiştir
3) Siteyi sil
4) Home dizin(leri)ni yedekle
5) Veritabanlarını yedekle
6) WordPress veritabanlarını temizle ve optimize et
7) Yapılandırmayı yeniden kur
8) Çıkış
```

## İşlevler

### 1. Yeni Site Oluşturma

Sırasıyla aşağıdaki işlemleri yapar:
- Domain DNS kontrolü (A kaydı, IP eşleşme)
- DNS bulunamazsa geçici Cloudflare subdomain oluşturma
- Linux kullanıcı oluşturma (SSH key ile)
- Web dizini oluşturma (`/home/kullanıcı/www/domain/public_html`)
- Nginx veya Apache vhost yapılandırması
- Cloudflare DNS kaydı (geçici subdomain ise)
- Let's Encrypt HTTPS sertifikası
- Opsiyonel WordPress kurulumu

### 2. Domain Değiştirme

Geçici subdomain'i gerçek domain ile değiştirir:
- Dosyaları yeni dizine taşır
- Eski vhost yapılandırmasını kaldırır
- Yeni vhost yapılandırmasını oluşturur

### 3. Site Silme

Tüm site bileşenlerini kaldırır:
- Web sunucu yapılandırması
- SSL sertifikası
- Web dizini
- Cloudflare DNS kaydı
- Kullanıcı (başka sitesi yoksa)

### 4. Home Dizin Yedekleme

`/home`, `/etc`, `/srv`, `/opt/monitoring` dizinlerini arşivler ve Google Drive'a yükler.

### 5. Veritabanı Yedekleme

Tüm MySQL veritabanlarını dump eder, sıkıştırır ve Google Drive'a yükler.

### 6. WordPress DB Temizleme

Yapılandırmadaki veritabanlarında şu işlemleri yapar:
- Transient verileri silme
- Action Scheduler temizleme
- Wordfence tabloları optimizasyonu
- Post/meta tabloları optimizasyonu

## Cron ile Otomatik Yedekleme

```bash
# Her gece 03:00'da Home + DB yedekleme
sudo crontab -e
```

```cron
0 3 * * * /usr/local/bin/webyonet --backup >> /var/log/webyonet-backup.log 2>&1
30 3 * * * /usr/local/bin/webyonet --database-backup >> /var/log/webyonet-db-backup.log 2>&1
```
