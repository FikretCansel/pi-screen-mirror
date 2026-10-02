@echo off
setlocal
set PI=fikret@192.168.1.114

echo ================================================
echo  RASPBERRY PI DURUMU
echo ================================================
echo.

ssh %PI% "echo 'tv-receiver : '$(systemctl is-active tv-receiver)' / acilista: '$(systemctl is-enabled tv-receiver); echo 'k3s         : '$(systemctl is-active k3s)' / acilista: '$(systemctl is-enabled k3s); echo 'mpv         : '$(pgrep -c mpv)' kopya'; echo 'sicaklik    : '$(vcgencmd measure_temp | cut -d= -f2); echo 'calisma     : '$(uptime -p); echo; echo '--- bellek ---'; free -h | head -2; echo; echo '--- en yuksek islemci kullanimi ---'; top -bn2 -d1 -o %%CPU | awk '/^top -/{n++} n==2' | sed -n '8,12p'"

if errorlevel 1 (
  echo.
  echo HATA: Pi'ye baglanilamadi. Pi acik mi? IP dogru mu? ^(%PI%^)
)

echo.
pause
