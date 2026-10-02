@echo off
setlocal
set PI=fikret@192.168.1.114
set BEKLE=%SystemRoot%\System32\timeout.exe

echo ================================================
echo  KUBERNETES MODU
echo  TV yayini kapatilir, k3s baslatilir.
echo ================================================
echo.

echo [1/2] TV yayin alicisi kapatiliyor...
ssh %PI% "sudo systemctl stop tv-receiver"
if errorlevel 1 goto hata

echo [2/2] k3s baslatiliyor (hazir olmasi 20-30 saniye surer)...
ssh %PI% "sudo systemctl start k3s"
if errorlevel 1 goto hata

"%BEKLE%" /t 25 /nobreak > nul

echo.
echo --- Durum ---
ssh %PI% "echo 'tv-receiver : '$(systemctl is-active tv-receiver); echo 'k3s         : '$(systemctl is-active k3s); echo 'sicaklik    : '$(vcgencmd measure_temp | cut -d= -f2); echo; sudo k3s kubectl get nodes 2>/dev/null"
echo.
echo Kubernetes modu aktif. TV yayini kapali.
goto son

:hata
echo.
echo HATA: Pi'ye baglanilamadi veya komut basarisiz oldu.
echo  - Pi acik mi?
echo  - IP adresi dogru mu? (%PI%)

:son
echo.
pause
