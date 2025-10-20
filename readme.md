# Webyonet

Apache üzerinde web sitelerini yönetmek için geliştirilen terminal aracı.

## Özellikler
- Site kur (geçici domain desteği)
- WordPress otomatik kurulum
- Certbot SSL önerisi
- Subdomain değiştir
- Site sil
- Yandex disk'e yedek alma işlemi

## Kurulum
```bash
./make-deb.sh
sudo dpkg -i webyonet-x.x.x.deb
#eksik bağımlılıklar için 
sudo apt install -f 
# ardından rclone yapılandırması için 
rclone config
```
## Veri tabanı kurulumu
MySQL “backup” kullanıcısını oluştur

Öncelikle root olarak MySQL’e gir:
```bash
sudo mysql -u root -p
```

Sonra bu SQL komutlarını sırayla çalıştır:
```bash
-- 1️⃣ Yedekleme kullanıcısını oluştur (şifreyi kendin belirle)
CREATE USER 'backup'@'localhost' IDENTIFIED BY 'GUVENLI_PAROLA';

-- 2️⃣ Gerekli minimum izinleri ver:
GRANT SELECT, SHOW DATABASES, LOCK TABLES, SHOW VIEW ON *.* TO 'backup'@'localhost';


-- 3️⃣ İzinleri yenile:
FLUSH PRIVILEGES;
```

✅ Bu kullanıcı sadece okuma (SELECT), görüntüleme (SHOW) ve tablo kilitleme (LOCK) yapabilir — yedekleme için yeterlidir.

🔐 Parola saklama — `~/.my.cnf` kullanımı

`backup` kullanıcısının parolasını betiklere düz metin yazmak yerine `~/.my.cnf` dosyasında saklayabilirsiniz. Aşağıdaki adımları izleyin (kullanıcı hesabınızda):

1. Dosyayı oluşturun ve içeriği şu şekilde ayarlayın:

```ini
[client]
user=backup
password=GUVENLI_PAROLA
host=localhost
```

2. Dosyanın izinlerini sıkılaştırın:

```bash
chmod 600 ~/.my.cnf
```

Not: `--defaults-file` opsiyonunu kullanmak isteğe bağlıdır; CLI araçları otomatik olarak `~/.my.cnf` dosyasını okuyabilir. Ancak betiklerinizde açıkça belirlemek güvenlik/taşınabilirlik açısından yardımcı olabilir.