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
# Eksik bağımlılıklar için:
sudo apt install -f 
```
### Veri tabanı kurulumu
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

**Önemli**: Şifre saklama işlemi (mysql-backup.cnf) `webyonet` ilk çalıştırıldığında `/etc/webyonet/` altında güvenli bir şekilde otomatik olarak gerçekleştirilecektir.

Ardından `webyonet` komutunu çalıştırdığınızda, araç eksik yapılandırmaları (rclone, mysql) tespit ederek sizi otomatik kurulum sihirbazına yönlendirecektir.