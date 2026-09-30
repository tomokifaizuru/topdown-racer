#!/usr/bin/env bash
# Reproduce all menu-BGM deliverables from compose_menu_bgm.py (box pipeline).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
PY=/workspace/music-venv/bin/python; SF=/usr/share/sounds/sf2/FluidR3_GM.sf2
T=$(mktemp -d)
$PY compose_menu_bgm.py
fluidsynth -ni $SF _render_3x.mid -F $T/raw3x.wav -r 44100 >/dev/null 2>&1
fluidsynth -ni $SF _render_preview.mid -F $T/rawprev.wav -r 44100 >/dev/null 2>&1
EQ="highpass=f=38,equalizer=f=110:t=q:w=1:g=-2.5,equalizer=f=3200:t=q:w=1.2:g=2,treble=g=1.5:f=9000"
LIM="volume=12.5dB,alimiter=limit=0.83:attack=5:release=80:level=0:latency=1"
# loop: master the 3x render continuously, take pass 2 (with pass-1 tails), crossfade last 2048 smp into pre-roll
ffmpeg -loglevel error -y -i $T/raw3x.wav -af "$EQ,$LIM" -f f32le -ac 2 $T/m3x.raw
$PY - "$T" <<'PYEOF'
import sys, wave, numpy as np
T = sys.argv[1]; N = 2822400; K = 2048          # 36 bars @135 = 64.000 s
M = np.fromfile(f'{T}/m3x.raw', dtype=np.float32).reshape(-1, 2).astype(float)
L = M[N:2*N].copy(); w = (0.5 - 0.5*np.cos(np.pi*np.linspace(0, 1, K)))[:, None]
L[-K:] = L[-K:]*(1-w) + M[N-K:N]*w
o = wave.open('menu-bgm-loop.wav', 'wb'); o.setnchannels(2); o.setsampwidth(2); o.setframerate(44100)
o.writeframes(np.clip(np.round(L*32767), -32768, 32767).astype('<i2').tobytes()); o.close()
PYEOF
ffmpeg -loglevel error -y -i menu-bgm-loop.wav -c:a libvorbis -q:a 6 menu-bgm-loop.ogg
ffmpeg -loglevel error -y -i $T/rawprev.wav -af "$EQ,$LIM,silenceremove=stop_periods=-1:stop_duration=1.5:stop_threshold=-70dB" $T/prev.wav
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $T/prev.wav)
ST=$(python3 -c "print($D-0.5)")
ffmpeg -loglevel error -y -i $T/prev.wav -af "afade=t=out:st=$ST:d=0.5" -c:a libmp3lame -b:a 192k menu-bgm-preview.mp3
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 menu-bgm-preview.mp3)
printf 'TopDown Racer — Main Menu' > $T/title.txt
printf 'Main Menu BGM  ·  135 BPM  ·  D major  ·  seamless 64 s loop' > $T/sub.txt
F1="/usr/share/fonts/truetype/sand-box/google/Russo One/RussoOne-Regular.ttf"; F2=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
cat > $T/fg.txt <<FG
[0:a]asplit=2[a1][a2];
[a1]aformat=channel_layouts=mono,lowpass=f=260,lowpass=f=260,volume=4,showwaves=s=1200x300:mode=cline:rate=30:colors=0xFFD21F:scale=sqrt:draw=full,format=rgba[w];
[1:v]drawtext=fontfile='$F1':textfile=$T/title.txt:fontcolor=0xFFD21F:fontsize=64:x=(w-tw)/2:y=70:borderw=4:bordercolor=0x000000,
drawtext=fontfile='$F2':textfile=$T/sub.txt:fontcolor=0xDDDDDD:fontsize=26:x=(w-tw)/2:y=165,
drawbox=x=0:y=640:w=1280:h=16:color=0xFFFFFF@1:t=fill,drawbox=x=0:y=656:w=1280:h=16:color=0xE8262B@1:t=fill[bg0];
color=c=0xFFD21F:s=1280x8:r=30[pb];
[bg0][pb]overlay=x='-1280+1280*t/$D':y=620[bg];
[bg][w]overlay=x=40:y=260:shortest=1,format=yuv420p[v]
FG
ffmpeg -loglevel error -y -i menu-bgm-preview.mp3 -f lavfi -i "color=c=0x16181e:s=1280x720:r=30" \
  -filter_complex_script $T/fg.txt -map "[v]" -map "[a2]" -c:v libx264 -preset slow -crf 26 -tune animation \
  -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart -shortest menu-bgm-preview.mp4
rm -rf "$T" __pycache__
echo done
