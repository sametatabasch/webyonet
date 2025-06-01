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
# n tuşuna basarak yadisk yazın. 
#storage seçiminde Yandex Disk (32)i seçin
#yandex bağlantısı için gerekli işlemleri yapın