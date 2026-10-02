@echo off
setlocal
set PI=fikret@192.168.1.114
set BEKLE=%SystemRoot%\System32\timeout.exe
set SEC=%SystemRoot%\System32\choice.exe

echo ================================================
echo  TV MODU
echo  k3s ve konteynerler kapatilir, TV yayini acilir.
echo ================================================
echo.
echo  DIKKAT: Kubernetes uzerinde calisan uygulamalariniz
echo  (redis, nodeapp, traefik...) duracak. Kubernetes
echo  moduna geri dondugunuzde kendiliginden geri gelirler.
echo.
"%SEC%" /c EH /n /m "Devam edilsin mi? (E=Evet, H=Hayir): "
if errorlevel 2 goto iptal

echo.
echo [1/3] k3s kapatiliyor...
ssh %PI% "sudo systemctl stop k3s"
if errorlevel 1 goto hata

echo [2/3] Konteynerler kapatiliyor (islemciyi serbest birakmak icin)...
ssh %PI% "sudo /usr/local/bin/k3s-killall.sh > /dev/null 2>&1; echo tamam"
if errorlevel 1 goto hata

echo [3/3] TV yayin alicisi baslatiliyor...
ssh %PI% "sudo systemctl start tv-receiver"
if errorlevel 1 goto hata

"%BEKLE%" /t 8 /nobreak > nul

echo.
echo --- Durum ---
ssh %PI% "echo 'tv-receiver : '$(systemctl is-active tv-receiver); echo 'k3s         : '$(systemctl is-active k3s); echo 'mpv         : '$(pgrep -c mpv)' kopya'; echo 'sicaklik    : '$(vcgencmd measure_temp | cut -d= -f2)"
echo.
echo TV modu aktif. Yayini baslatmak icin tv_yayin_baslat.bat dosyasini calistirin.
goto son

:iptal
echo.
echo Iptal edildi, hicbir sey degistirilmedi.
goto son

:hata
echo.
echo HATA: Pi'ye baglanilamadi veya komut basarisiz oldu.
echo  - Pi acik mi?
echo  - IP adresi dogru mu? (%PI%)

:son
echo.
pause
