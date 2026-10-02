# Raspberry Pi Ayarları — Yedek ve Sıfırdan Kurulum

Bu klasör, Pi'de yapılan **tüm** ayarları içerir. İşletim sistemini silerseniz veya
değiştirirseniz buradan aynı kurulumu geri yapabilirsiniz.

Yayının nasıl çalıştığının anlatımı bir üst klasördeki
`TV-YAYIN-NASIL-CALISIYOR.md` dosyasında.

---

## Mevcut sistemin künyesi

| | |
|---|---|
| Cihaz | Raspberry Pi 4 Model B Rev 1.4, 2 GB RAM |
| İşletim sistemi | Raspberry Pi OS / Debian 13 (trixie), 64 bit |
| Kullanıcı | `fikret` |
| Makine adı | `fikretpi` |
| IP | `192.168.1.114` (WiFi, wlan0) |
| Oynatıcı | mpv 0.40.0 (Debian deposundan, `apt install mpv`) |
| Ekran | HDMI-1 portu TV'ye bağlı |

---

## Sıfırdan kurulum

### 1. İşletim sistemini kur

Raspberry Pi Imager ile **Raspberry Pi OS (64-bit)** yazın. Imager'ın ayarlar
ekranında şunları girin:
- Kullanıcı adı: `fikret` (farklı olursa kurulum betiği kendini ona göre ayarlar)
- WiFi bilgileri
- **SSH'ı etkinleştirin**

### 2. Bu klasörü Pi'ye kopyala

Windows'ta bu klasörün içindeyken:

```bash
scp -r . fikret@192.168.1.114:~/tv-kurulum/
```

### 3. Kurulum betiğini çalıştır

```bash
ssh fikret@192.168.1.114
cd ~/tv-kurulum
chmod +x kurulum.sh
./kurulum.sh
```

Betik şunları yapar:
1. mpv'yi kurar (yoksa)
2. Donanımsal video çözücünün (`/dev/video10`) var olduğunu doğrular
3. HDMI portlarının durumunu bilgi olarak gösterir
4. `tv-receiver.sh` betiğini ev dizinine yazar
5. Ağ tamponu ayarını kurar
6. Servisi kurar, açılışta başlayacak şekilde etkinleştirir ve çalıştırır

> Bu betik gerçek Pi üzerinde çalıştırılarak test edildi.

Sonunda IP adresini yazar. O IP'yi Windows'taki `tv_yayin_baslat.bat` dosyasındaki
`PI_IP` satırına yazın.

### 4. SSH anahtarı (isteğe bağlı)

Her bağlanışta şifre sormaması için, Windows'ta:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh fikret@192.168.1.114 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Bu, yayının çalışması için gerekli değil; sadece kolaylık.

---

## Klasördeki dosyalar

| Dosya | Pi'deki yeri | Görevi |
|---|---|---|
| `kurulum.sh` | — | Hepsini tek komutla kurar |
| `tv-receiver.sh` | `/home/fikret/tv-receiver.sh` | mpv'yi doğru ayarlarla sonsuz döngüde çalıştırır |
| `tv-receiver.service` | `/etc/systemd/system/tv-receiver.service` | Açılışta betiği başlatır |
| `90-tv-stream.conf` | `/etc/sysctl.d/90-tv-stream.conf` | UDP tampon sınırını 16 MB'a çıkarır |

---

## Elle kurulum

Kurulum betiğini kullanmak istemezseniz, Pi'de sırayla:

```bash
# 1. mpv
sudo apt update && sudo apt install -y mpv

# 2. Alıcı betiği
nano ~/tv-receiver.sh        # tv-receiver.sh içeriğini yapıştırın
chmod +x ~/tv-receiver.sh

# 3. Ağ tamponu
echo "net.core.rmem_max=16777216" | sudo tee /etc/sysctl.d/90-tv-stream.conf
sudo sysctl --system

# 4. Servis
sudo nano /etc/systemd/system/tv-receiver.service   # tv-receiver.service içeriğini yapıştırın
sudo systemctl daemon-reload
sudo systemctl enable --now tv-receiver

```

Ses cihazını elle ayarlamanız gerekmez; `tv-receiver.sh` her mpv başlangıcında bağlı
HDMI portunu kendisi bulur.

---

## Neden bu ayarlar? (hangi sorunu çözüyorlar)

Her biri gerçek bir sorunu çözmek için eklendi. Silerseniz o sorun geri gelir.

**`--hwdec=v4l2m2m-copy`** — H.264'ü Pi'nin donanım çözücüsüyle (`/dev/video10`) çözer.
Bu olmadan işlemci %300'ü aşıyor ve görüntü oynamıyordu. (Eski `mmal` yöntemi artık
desteklenmiyor, denendi ve "Unsupported hwdec" hatası verdi.)

**`--profile=fast`** — Ekran kartının görüntüyü büyütme işini hafifletir. Sıcaklığı
birkaç derece düşürdü.

**`--cache=no`, `--demuxer-max-bytes=8MiB`, `--demuxer-max-back-bytes=0`,
`--demuxer-seekable-cache=no`** — mpv varsayılan olarak yayını geri sarmak için
hafızada tutar. Canlı yayında bu gereksiz; hem bellek yiyor hem gecikme ekliyor.

**`fifo_size=50000`** — **Dikkat: birim bayt değil, 188 baytlık paket sayısı.** Yani bu
değer ~9 MB demek. Bir ara buraya 10000000 yazılmıştı; o ~1.9 GB'lık bir tampon anlamına
geliyordu ve mpv'nin belleği dakikada 27 MB artarak Pi'nin 2 GB'ını tüketmeye gidiyordu.

**`buffer_size=8388608` + `net.core.rmem_max=16777216`** — Soket alım tamponu. İkisi
birlikte çalışır: çekirdek sınırı (`rmem_max`) yükseltilmezse mpv'nin istediği 8 MB
kısıtlanır. Varsayılan 208 KB ile paketler kayboluyordu (`netstat -su` çıkışında
40.000'den fazla "receive buffer errors"). Bu ayarlarla kayıp sıfıra indi.

**`overrun_nonfatal=1`** — Tampon yine taşarsa mpv kapanmak yerine devam eder.

**`--audio-buffer=0.2`, `--framedrop=decoder+vo`** — Ses ve görüntünün senkron
kalmasını sağlar. Bunlar olmadan arada 4-5 saniyelik kayma oluşuyordu.

**`--audio-device=alsa/plughw:CARD=vc4hdmi0,DEV=0`** — Sesi TV'ye (HDMI) gönderir.
Belirtilmezse Pi'nin kulaklık jakına gidiyor ve TV'den ses gelmiyor. Betik bu değeri
her mpv başlangıcında bağlı HDMI portuna göre kendisi hesaplar (HDMI-1 → `vc4hdmi0`,
HDMI-2 → `vc4hdmi1`).

> **Dikkat:** TV kapalıyken Linux her iki HDMI portunu da "disconnected" görür. Bu
> durumda betik yedek değeri (`vc4hdmi0`, yani HDMI-1) kullanır. TV'yi HDMI-2'ye takıp
> Pi'yi TV kapalıyken başlatırsanız ses yanlış porta gidebilir; TV'yi açtıktan sonra
> `sudo systemctl restart tv-receiver` demek sorunu çözer.

**`--fs`** — Tam ekran.

**Servisteki `Restart=always` ve betikteki `while true` döngüsü** — Yayını her
kapattığınızda mpv de kapanır. Döngü onu hemen yeniden başlatıp beklemeye sokar; böylece
yayını kaç kez açıp kapatsanız da Pi'ye dokunmanız gerekmez.

**Servisteki `SupplementaryGroups=video audio render input`** — Servis olarak çalışan
mpv'nin ekran ve ses donanımına erişebilmesi için.

---

## Bu kurulumda yapılmayanlar (bilgi olsun diye)

- **`/boot/firmware/config.txt` değiştirilmedi.** Varsayılan `dtoverlay=vc4-kms-v3d`
  ayarı yeterli; donanım çözücü onunla geliyor.
- **Güvenlik duvarı ayarı yok.** Pi'de ufw kurulu değil, UDP 1234 için bir şey
  yapılmasına gerek kalmadı.
- **k3s ayarı bu kurulumun parçası değil.** Mevcut sistemde k3s (Kubernetes) kuruluydu
  ve ısınmaya yol açtığı için durdurulup açılışta başlaması kapatıldı
  (`sudo systemctl disable k3s`). Yeni bir kurulumda k3s olmayacağı için bu adıma gerek
  yok. Kurarsanız ve yayın sırasında sıcaklık 72°C'ye çıkarsa sebebi odur.
