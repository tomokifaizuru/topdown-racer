# TopDown Racer: Main Menu BGM

Original composition by DJ for Tomoki R / Asuka. Working title: "Pole Position Sunshine".

| | |
|---|---|
| BPM | 135 |
| Key | D major (a mixolydian ♭VII C chord in the intro and B section) |
| Meter / bars | 4/4, 36 bars |
| Loop length | 36 × 4 × 60 / 135 = **64.000 s** (2,822,400 samples @ 44.1 kHz) |
| Preview | ~69.1 s (one pass + resolving D hit + natural tail) |
| Loudness | loop: max −1.6 dBFS (WAV) / −1.1 (OGG), mean −16.9 dB. Preview: max −1.5, mean −17.5 |

## Structure
| Bars | Section | Chords | Notes |
|---|---|---|---|
| 1–4 | Intro | D C G A | bass groove, drums, clav; subtle pitch-bent saw "engine rev" + reverse-cymbal swell; brass pickup into the hook |
| 5–12 | A (hook) | D G Bm A · D G Em A | square-lead hook, light drums |
| 13–20 | B (lift) | G A F#m Bm · G A C A | longer notes that climb higher; 4-on-the-floor; C→A (♭VII→V) lift |
| 21–28 | A′ | same as A | full version: saw double an octave below, brass stabs, open hats |
| 29–32 | Bridge | G A Bm A | lead drops out, snare builds, rev riser (energy dip then build) |
| 33–36 | Tag | D G Bm A | first half of the hook; bar 36 (A = V) has a tom fill that leads back to bar 1 (D) |

## Instruments (GM / FluidR3)
Synth Bass 1 (bright, so it still reads on phone speakers), Square Lead (hook), Saw Lead (quiet octave double),
Clavinet (offbeat funk stabs), Synth Strings (soft bed), Synth Brass (hits), Saw + pitch wheel (engine-rev riser),
Reverse Cymbal, GM drums. Master: HPF 38 Hz, −2.5 dB at 110 Hz (cuts mud), +2 dB at 3.2 kHz (lead presence), light air, limiter at −1.6 dBFS.

## Files
- `menu-bgm-loop.ogg`: **use this in Godot**. On import, turn on Loop (loop offset 0) or set `stream.loop = true`.
- `menu-bgm-loop.wav`: the same loop as 16-bit PCM.
- `menu-bgm-preview.mp3` / `menu-bgm-preview.mp4`: for listening and sharing (the MP4 is a 1280×720 waveform video, H.264/AAC).
- `menu-bgm.mid`: one loop pass (source). `_render_3x.mid` and `_render_preview.mid` are render helpers.
- `compose_menu_bgm.py`: writes the MIDI files. `render_menu_bgm.sh`: rebuilds every audio/video file from them.

## Seamless-loop method
The script renders the loop 3× back to back and masters that render as one continuous file. It then keeps pass 2, which
already contains the reverb and release tails from pass 1, just as the loop will when it repeats. The last 2048 samples
(46 ms) are crossfaded into the audio that comes just before the loop start. Checked with loop×2: the jump at the seam
is ≤0.006, while the median difference between neighbouring samples is 0.016. So there is no click or gap.

## Originality
All melodies, riffs, basslines and chord choices were written for this track. There are no quotes from Mario Kart, OutRun,
Ridge Racer, Initial D, eurobeat songs or any other existing piece, and no samples (everything is rendered from MIDI with the
GM soundfont). Every lead note on a strong beat is a chord tone or a mild colour tone (add9, 6th or m7), so the harmony stays consonant.
