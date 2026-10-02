@echo off
title TV Yayini (kapatmak icin bu pencereyi kapat)
set PI_IP=192.168.1.114
set STEREO_MIX=@device_cm_{33D9A762-90C8-11D0-BD43-00A0C911CE86}\wave_{F57E83F4-7D10-4BEB-B086-7D1E562DEEE8}

ffmpeg -hide_banner -loglevel warning -stats ^
 -f dshow -audio_buffer_size 50 -i "audio=%STEREO_MIX%" ^
 -filter_complex "ddagrab=0:framerate=25,hwdownload,format=bgra,scale=1280:720:flags=fast_bilinear,format=yuv420p,setpts=(RTCTIME-RTCSTART)/(TB*1000000)[v];[0:a]aresample=44100,asetpts=(RTCTIME-RTCSTART)/(TB*1000000),aresample=async=1000[a]" ^
 -map "[v]" -map "[a]" ^
 -c:v libx264 -preset superfast -tune zerolatency -b:v 3000k -maxrate 3000k -bufsize 1500k -g 25 -x264-params repeat-headers=1 ^
 -c:a aac -b:a 128k ^
 -f mpegts -muxrate 3600k "udp://%PI_IP%:1234?pkt_size=1316&bitrate=3800000&burst_bits=100000"

pause
