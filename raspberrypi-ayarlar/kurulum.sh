#!/bin/bash
# Raspberry Pi'yi TV yayin alicisi olarak kurar.
#
# Kullanim (Pi uzerinde, bu klasordeki dosyalarla ayni dizinde):
#   chmod +x kurulum.sh
#   ./kurulum.sh
#
# Tekrar tekrar calistirilabilir, mevcut kurulumu bozmaz.

set -e

KULLANICI="${SUDO_USER:-$USER}"
EV="/home/$KULLANICI"

echo "== Kullanici: $KULLANICI"

# --- 1. mpv kurulumu -------------------------------------------------------
if ! command -v mpv > /dev/null; then
  echo "== mpv kuruluyor"
  sudo apt-get update
  sudo apt-get install -y mpv
else
  echo "== mpv zaten kurulu: $(mpv --version | head -1)"
fi

# --- 2. Donanimsal video cozucu kontrolu -----------------------------------
# /dev/video10 = bcm2835-codec-decode (H.264 donanim cozucu).
# Yoksa mpv yazilimla cozmeye calisir ve islemci yetmez.
if [ -e /dev/video10 ]; then
  echo "== Donanim cozucu bulundu: /dev/video10"
else
  echo "!! UYARI: /dev/video10 yok. /boot/firmware/config.txt icinde"
  echo "!! 'dtoverlay=vc4-kms-v3d' satiri olmali ve Pi yeniden baslatilmali."
fi

# --- 3. Bagli HDMI portunu bildir ------------------------------------------
# Ses cihazini betik her mpv baslangicinda kendisi secer; burada sadece
# o anki durumu bilgi olarak gosteriyoruz. TV kapaliysa "disconnected" gorunur,
# bu normaldir.
for n in 1 2; do
  durum=$(cat /sys/class/drm/card*-HDMI-A-$n/status 2>/dev/null | head -1)
  echo "== HDMI-$n: ${durum:-bulunamadi}  (ses cihazi: vc4hdmi$((n-1)))"
done

# --- 4. Alici betigi -------------------------------------------------------
echo "== $EV/tv-receiver.sh yaziliyor"
cp tv-receiver.sh "$EV/tv-receiver.sh"
chmod +x "$EV/tv-receiver.sh"

# --- 5. Ag tamponu ---------------------------------------------------------
echo "== /etc/sysctl.d/90-tv-stream.conf yaziliyor"
sudo cp 90-tv-stream.conf /etc/sysctl.d/90-tv-stream.conf
sudo sysctl --system > /dev/null
echo "   rmem_max = $(cat /proc/sys/net/core/rmem_max)"

# --- 6. Servis -------------------------------------------------------------
echo "== Servis kuruluyor"
sed "s|^User=.*|User=$KULLANICI|; s|^ExecStart=.*|ExecStart=$EV/tv-receiver.sh|" \
  tv-receiver.service | sudo tee /etc/systemd/system/tv-receiver.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now tv-receiver.service

sleep 5
echo
echo "== Durum: $(systemctl is-active tv-receiver) / $(systemctl is-enabled tv-receiver)"
echo "== IP adresi: $(hostname -I | awk '{print $1}')"
echo
echo "Kurulum bitti. Bu IP adresini Windows'taki tv_yayin_baslat.bat dosyasindaki"
echo "PI_IP satirina yazin, sonra o dosyaya cift tiklayin."
