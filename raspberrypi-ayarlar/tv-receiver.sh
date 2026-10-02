#!/bin/sh
# Ekran yayınını UDP 1234'ten alır ve HDMI'dan TV'ye basar.
# Hedef konum: /home/fikret/tv-receiver.sh  (chmod +x gerekir)

# Pi 4'te iki HDMI portu var. Hangisi bagliysa ses onun cihazina gitmeli,
# yoksa ses TV'ye degil Pi'nin kulaklik jakina gider.
#   HDMI-1 (karta yakin olan) -> vc4hdmi0
#   HDMI-2                    -> vc4hdmi1
# TV kapaliyken Linux portu "disconnected" gorur, o yuzden her mpv
# baslangicinda yeniden bakilir. Hicbiri bulunamazsa YEDEK deger kullanilir.
YEDEK="vc4hdmi0"

hdmi_ses_cihazi() {
  for n in 1 2; do
    durum=$(cat /sys/class/drm/card*-HDMI-A-$n/status 2>/dev/null | head -1)
    if [ "$durum" = "connected" ]; then
      echo "alsa/plughw:CARD=vc4hdmi$((n-1)),DEV=0"
      return
    fi
  done
  echo "alsa/plughw:CARD=$YEDEK,DEV=0"
}

while true; do
  mpv --hwdec=v4l2m2m-copy --cache=no --demuxer-lavf-o=fflags=+nobuffer \
      --demuxer-lavf-analyzeduration=0.5 --audio-buffer=0.2 --framedrop=decoder+vo \
      --profile=fast --demuxer-max-bytes=8MiB --demuxer-max-back-bytes=0 \
      --demuxer-seekable-cache=no --fs --really-quiet \
      --audio-device="$(hdmi_ses_cihazi)" \
      "udp://@:1234?overrun_nonfatal=1&fifo_size=50000&buffer_size=8388608"
  sleep 1
done
