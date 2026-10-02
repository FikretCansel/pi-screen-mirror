# Ekranı TV'ye Yayınlama — Nasıl Çalışıyor?

Bilgisayarın ekranı ve sesi, ağ üzerinden Raspberry Pi'ye gönderilir. Pi de bunu HDMI
ile bağlı olduğu TV'ye basar.

```
Windows PC (192.168.1.106)                    Raspberry Pi (192.168.1.114)
┌──────────────────────────────┐              ┌──────────────────────────────┐
│ ekran görüntüsü  (ddagrab)   │              │ mpv                          │
│ ses  (Stereo Mix)            │              │  - UDP 1234'ü dinler         │
│         ↓                    │   WiFi/UDP   │  - donanımla çözer           │
│ ffmpeg: H.264 + AAC          │ ──────────→  │  - HDMI'dan TV'ye basar      │
│         ↓                    │   port 1234  │                              │
│ MPEG-TS akışı                │              │ tv-receiver.service          │
└──────────────────────────────┘              └──────────────────────────────┘
```

---

## Kullanım

### Yayını başlatmak

`tv_yayin_baslat.bat` dosyasına çift tıklayın. Bu kadar.

Açılan siyah pencere yayının kendisidir; içinde `frame= ... fps=24` gibi satırlar akar.

### Yayını durdurmak

Açılan o pencereyi kapatın.

### Pi tarafında ne yapmak gerekiyor?

Hiçbir şey. Pi açıldığında yayını beklemeye başlar, siz `.bat`'i çalıştırınca görüntü
gelir, kapatınca bekleme konumuna döner. SSH'a girmeniz gerekmez.

---

## Pi ne dinliyor?

`tv-receiver` adlı bir systemd servisi, Pi her açıldığında otomatik başlar. Bu servis
`/home/fikret/tv-receiver.sh` dosyasını çalıştırır; o da sonsuz bir döngü içinde mpv'yi
çağırır:

```sh
mpv ... "udp://@:1234?overrun_nonfatal=1&fifo_size=50000&buffer_size=8388608"
```

- **`udp://@:1234`** — tüm ağ arayüzlerinde **1234 numaralı UDP portunu** dinler.
  Yayın gelmediğinde mpv orada bekler, bir şey göstermez.
- **Döngü** — yayını kapattığınızda mpv de kapanır, 1 saniye sonra döngü onu yeniden
  başlatır ve tekrar beklemeye geçer. Yani yayını kaç kez açıp kapatsanız da çalışır.
- **`Restart=always`** — servis bir şekilde tamamen çökerse systemd onu geri getirir.

### Pi'deki dosyalar

| Dosya | Görevi |
|---|---|
| `/home/fikret/tv-receiver.sh` | mpv'yi doğru ayarlarla sonsuz döngüde çalıştırır |
| `/etc/systemd/system/tv-receiver.service` | Açılışta bu betiği başlatır |
| `/etc/sysctl.d/90-tv-stream.conf` | Ağ tamponu sınırını 16 MB'a çıkarır (paket kaybını önler) |

### Pi tarafı komutları

```bash
systemctl status tv-receiver      # durumu
sudo systemctl restart tv-receiver # yeniden başlat
sudo systemctl stop tv-receiver    # durdur (TV siyah kalır)
journalctl -u tv-receiver -n 50    # kayıtları gör
```

---

## PC'den yayın nasıl yapılıyor?

`tv_yayin_baslat.bat` tek bir ffmpeg komutu çalıştırır. İşin tamamını o yapar:
görüntüyü yakalar, sesi yakalar, ikisini sıkıştırır ve ağa gönderir.

### 1. Görüntüyü yakalamak — `ddagrab`

```
ddagrab=0:framerate=25
```

Windows'un Desktop Duplication arayüzünü kullanır, yani görüntüyü doğrudan ekran
kartından alır. Saniyede 25 kare, 1. ekran (`0`).

> **Not:** Bir diğer yöntem olan `gdigrab` denendi ve çok yavaştı — saniyede sadece 4-5
> kare veriyordu. VLC de denendi, görüntüde iyiydi ama ses eklenince çöküyordu.

### 2. Küçültmek

```
scale=1280:720
```

Ekranınız 2560x1440. Bu haliyle Pi çözemez ve WiFi taşır, o yüzden 720p'ye küçültülür.

### 3. Sesi yakalamak — Stereo Mix

```
-f dshow -i "audio=@device_cm_{33D9A762-...}\wave_{F57E83F4-...}"
```

Windows'taki **"Stereo Karışımı"** kayıt cihazı, hoparlörlerinize giden sesin bir
kopyasını verir. Bu yüzden hoparlörden çıkan her şey (film, müzik, bildirim sesi) TV'ye
gider.

> **Neden o uzun kod?** Cihazın adı `Stereo Karışımı (Realtek(R) Audio)`. İçindeki
> boşluklar, parantezler ve Türkçe harfler ffmpeg/VLC'nin komut ayrıştırmasını bozuyordu.
> Yukarıdaki kimlik, aynı cihazın ASCII karşılığıdır ve sorunsuz çalışır.

### 4. Ses ve görüntüyü senkronlamak

```
setpts=(RTCTIME-RTCSTART)/(TB*1000000)      # görüntü için
asetpts=(RTCTIME-RTCSTART)/(TB*1000000)     # ses için
```

**Bu satırlar projenin en kritik kısmı.** İkisine de "şu an saat kaç" damgası vurur.
Ses ve görüntü aynı saate göre damgalandığı için senkron kalırlar.

> **Neden gerekti?** Başlangıçta görüntüyü VLC, sesi ffmpeg yakalıyordu. İki ayrı program
> olduğu için zaman damgaları birbirini tutmuyordu ve **ses görüntünün 22 saniye
> önünden gidiyordu.** Tek programda, tek saatle yakalayınca fark 0'a indi.

### 5. Sıkıştırmak

```
-c:v libx264 -preset superfast -tune zerolatency -b:v 3000k -g 25 -x264-params repeat-headers=1
-c:a aac -b:a 128k
```

- **`zerolatency`** — kodlayıcı kare biriktirip beklemez, gecikmeyi düşük tutar.
- **`-g 25`** — her saniye bir anahtar kare (tam görüntü) üretir.
- **`repeat-headers=1`** — **bu olmazsa hiç görüntü gelmez.** Yayın akarken Pi sonradan
  bağlanır; görüntüyü çözmek için gereken teknik bilgiyi (SPS/PPS) kaçırır. Bu ayar o
  bilgiyi her anahtar karede tekrar gönderir, böylece Pi en fazla 1 saniye içinde
  görüntüyü yakalar.
- **`libx264` (ekran kartı değil, işlemci)** — ekran kartıyla kodlama (NVENC) denendi,
  NVIDIA sürücünüz bu ffmpeg sürümü için eski olduğundan çalışmadı. Sürücüyü
  güncellerseniz kodlama ekran kartına aktarılabilir ve 1080p'ye çıkılabilir.

### 6. Göndermek

```
-f mpegts -muxrate 3600k "udp://192.168.1.114:1234?pkt_size=1316&bitrate=3800000&burst_bits=100000"
```

- **UDP** — TCP gibi kayıp paketi tekrar istemez. Canlı yayında istenen de budur:
  gecikmek yerine o kareyi atlamak daha iyidir.
- **`bitrate=3800000`** — paketleri düzgün aralıklara yayar. Toplu halde gönderilirse
  Pi'nin tamponu taşıyor ve görüntü bozuluyordu.
- **`pkt_size=1316`** — ağ paketine tam oturan boyut (7 × 188 bayt).

---

## Ayarları değiştirmek

`tv_yayin_baslat.bat` dosyasını Not Defteri ile açıp düzenleyebilirsiniz.

| İstediğiniz | Yapacağınız |
|---|---|
| Pi'nin IP'si değişti | En üstteki `set PI_IP=192.168.1.114` satırını güncelleyin |
| Daha net görüntü | `scale=1280:720` → `1920:1080` ve `-b:v 3000k` → `5000k`. Takılma olabilir |
| Takılmayı azaltmak | `-b:v 3000k` → `2000k`, ya da `scale=1280:720` → `960:540` |
| İkinci ekranı yayınlamak | `ddagrab=0` → `ddagrab=1` |

Değişiklikten sonra yayın penceresini kapatıp `.bat`'i tekrar çalıştırmanız yeterli,
Pi tarafında bir şey yapmak gerekmez.

---

## Sorun giderme

**TV'de görüntü yok**
1. `.bat` penceresi açık mı ve içinde `frame=` satırları akıyor mu?
2. Pi'de servis çalışıyor mu: `ssh fikret@192.168.1.114 "systemctl status tv-receiver"`
3. Pi'nin IP'si hâlâ `192.168.1.114` mü? Değiştiyse `.bat` içindeki `PI_IP`'yi güncelleyin.

**Görüntü var, ses yok**
- Windows'ta **Stereo Karışımı** kayıt cihazı etkin olmalı. Ses ayarları → Kayıt
  sekmesi → boş alana sağ tık → "Devre dışı bırakılmış aygıtları göster".
- TV'nin sesi kapalı olabilir; Pi sesi HDMI'dan gönderiyor.

**Görüntü bozuk / kareler bloklaşıyor**
- WiFi sinyali zayıf olabilir. Bit hızını düşürün ya da Pi'yi kabloyla bağlayın
  (kablo, WiFi'dan belirgin şekilde daha stabildir).

**Pi ısınıyor**
- Sıcaklığı görmek için: `ssh fikret@192.168.1.114 "vcgencmd measure_temp"`
- 80°C üzerinde Pi kendini yavaşlatır. Yayın sırasında ~66-68°C normaldir.
- k3s (Kubernetes) çalışırken sıcaklık ~72°C'ye çıkıyordu, bu yüzden kapatıldı.
  Açılışta otomatik başlamaz. Elle başlatmak için: `sudo systemctl start k3s`

---

## Bilinen sınırlamalar

- **Gecikme ~1-2 saniye.** Film izlemek için sorun değil, oyun oynamak için uygun değil.
- **Saniyede ~2 kare düşüyor.** Hızlı sahnelerde hafif takılma olabilir.
- **Pi WiFi üzerinden bağlı.** Kabloyla bağlamak hem takılmayı hem bozulmayı azaltır.
- **Ekranın tamamı gider.** Sadece belirli bir pencereyi göndermek bu kurulumda yapılmıyor.
