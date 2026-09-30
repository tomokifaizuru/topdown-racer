#!/usr/bin/env python3
"""
TopDown Racer - Main Menu BGM  ("Pole Position Sunshine" working title)
Original composition by DJ for Tomoki R / Asuka.  No quotes of any existing
song; all melodies, riffs and progressions written from scratch.

BPM 135 | D major (mixolydian bVII colour in intro/B) | 4/4 | 36 bars
Loop body = 36 bars * 4 beats * 60/135 = 64.000 s exactly.

Structure (bars):
  1-4   Intro   D  C  G  A      bass+drums+clav, engine-rev riser, rev-cymbal
  5-12  A hook  D  G  Bm A  D  G  Em A
  13-20 B lift  G  A  F#m Bm G  A  C  A
  21-28 A' hook (full: octave double, brass stabs, 4-on-floor)
  29-32 Bridge  G  A  Bm A      lead rests, rev riser + snare build
  33-36 Tag     D  G  Bm A      hook first half; bar 36 (A = V) turns back to bar 1 (D)

Outputs (written next to this script):
  menu-bgm.mid          one loop pass (the musical source)
  _render_3x.mid        loop x3 (used to extract a click-free loop with correct reverb tails)
  _render_preview.mid   one pass + final resolving D hit (preview with natural tail)
"""
import os
from midiutil import MIDIFile

HERE = os.path.dirname(os.path.abspath(__file__))
BPM = 135
BARS = 36
BAR = 4.0
LOOP_BEATS = BARS * BAR

# tracks / channels / GM programs
T_BASS, T_LEAD, T_DBL, T_CLAV, T_PAD, T_BRASS, T_FX, T_RCYM, T_DRUM = range(9)
CH = {T_BASS: 0, T_LEAD: 1, T_DBL: 2, T_CLAV: 3, T_PAD: 4, T_BRASS: 5,
      T_FX: 6, T_RCYM: 7, T_DRUM: 9}
PROG = {T_BASS: 38,   # Synth Bass 1 (bright harmonics -> audible on phones)
        T_LEAD: 80,   # Square Lead  (clear hook)
        T_DBL: 81,    # Saw Lead     (quiet octave-below double)
        T_CLAV: 7,    # Clavinet     (funk offbeat stabs)
        T_PAD: 50,    # Synth Strings 1 (soft bed)
        T_BRASS: 62,  # Synth Brass 1 (hits)
        T_FX: 81,     # Saw (pitch-bent engine-rev riser)
        T_RCYM: 119}  # Reverse Cymbal (swell into downbeats)

KICK, SNARE, CLAP, CHH, PHH, OHH, CRASH, RIDE = 36, 38, 39, 42, 44, 46, 49, 51
TOM_L, TOM_M, TOM_H = 45, 47, 50

# ---- note names ----
NOTE = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7,
        'G#': 8, 'A': 9, 'A#': 10, 'B': 11}


def n(name):
    """'F#5' -> midi number (C4 = 60)."""
    p, o = name[:-1], int(name[-1])
    return 12 * (o + 1) + NOTE[p]


CHORDS = {  # mid voicings for clav/pad (kept in C4..A4-ish: clear, not muddy)
    'D':   ['D4', 'F#4', 'A4'],
    'C':   ['C4', 'E4', 'G4'],
    'G':   ['D4', 'G4', 'B4'],
    'A':   ['C#4', 'E4', 'A4'],
    'Bm':  ['D4', 'F#4', 'B4'],
    'Em':  ['E4', 'G4', 'B4'],
    'F#m': ['C#4', 'F#4', 'A4'],
}
ROOT = {'D': 'D2', 'C': 'C2', 'G': 'G2', 'A': 'A2', 'Bm': 'B1', 'Em': 'E2', 'F#m': 'F#2'}

INTRO = ['D', 'C', 'G', 'A']
A_PROG = ['D', 'G', 'Bm', 'A', 'D', 'G', 'Em', 'A']
B_PROG = ['G', 'A', 'F#m', 'Bm', 'G', 'A', 'C', 'A']
BRIDGE = ['G', 'A', 'Bm', 'A']
TAG = ['D', 'G', 'Bm', 'A']
SONG = INTRO + A_PROG + B_PROG + A_PROG + BRIDGE + TAG
assert len(SONG) == BARS
SECTION = (['intro'] * 4 + ['A'] * 8 + ['B'] * 8 + ['A2'] * 8 + ['bridge'] * 4 + ['tag'] * 4)

# ---- original hook (A section), per bar: (note, beat, dur, vel) ----
HOOK = [
    [('A5', 0, .5, 104), ('F#5', 1, .5, 96), ('A5', 1.5, .5, 100), ('D6', 2.5, .75, 110), ('A5', 3.5, .5, 98)],
    [('B5', 0, 1, 106), ('A5', 1, .5, 96), ('G5', 1.5, .5, 96), ('B5', 2.5, .5, 102), ('D6', 3, 1, 108)],
    [('D6', 0, .75, 106), ('B5', 1, .5, 98), ('F#5', 1.5, .5, 94), ('B5', 2.5, .5, 100), ('A5', 3, .5, 96), ('B5', 3.5, .5, 100)],
    [('C#6', 0, 1.5, 110), ('B5', 1.5, .5, 96), ('A5', 2, 1.5, 104), ('E5', 3.5, .5, 94)],
    [('A5', 0, .5, 104), ('F#5', 1, .5, 96), ('A5', 1.5, .5, 100), ('D6', 2.5, .75, 110), ('A5', 3.5, .5, 98)],
    [('B5', 0, 1, 106), ('A5', 1, .5, 96), ('G5', 1.5, .5, 96), ('B5', 2.5, .5, 102), ('D6', 3, .5, 106), ('E6', 3.5, .5, 108)],
    [('E6', 0, .75, 110), ('D6', 1, .5, 100), ('B5', 1.5, .5, 98), ('G5', 2.5, .5, 96), ('B5', 3, .5, 100), ('D6', 3.5, .5, 102)],
    [('C#6', 0, .5, 108), ('A5', .5, .5, 100), ('E5', 1, .5, 96), ('A5', 1.5, 1.75, 106)],
]
# ---- B section: longer, soaring answer ----
BMEL = [
    [('D6', 0, 1.5, 104), ('B5', 1.5, .5, 96), ('D6', 2, .5, 100), ('E6', 2.5, 1.5, 108)],
    [('C#6', 0, 1, 104), ('E6', 1, .5, 104), ('C#6', 1.5, .5, 98), ('A5', 2, 2, 102)],
    [('F#5', 0, .5, 96), ('A5', .5, .5, 100), ('C#6', 1, 1, 106), ('E6', 2, .5, 104), ('C#6', 2.5, 1.5, 104)],
    [('D6', 0, 1.5, 106), ('C#6', 1.5, .5, 98), ('B5', 2, 2, 104)],
    [('B5', 0, .5, 100), ('D6', .5, .5, 104), ('G6', 1, 1.5, 112), ('F#6', 2.5, .5, 102), ('E6', 3, 1, 106)],
    [('C#6', 0, .5, 102), ('E6', .5, 1, 108), ('D6', 1.5, .5, 100), ('C#6', 2, 1, 104), ('A5', 3, 1, 100)],
    [('G5', 0, .5, 100), ('C6', .5, .5, 104), ('E6', 1, 1.5, 110), ('D6', 2.5, .5, 100), ('C6', 3, 1, 104)],
    [('C#6', 0, 2, 112), ('E6', 2, 1.25, 108)],
]


class Song:
    def __init__(self, passes=1, ending=False):
        self.m = MIDIFile(9, deinterleave=False)
        self.active = {}
        for t in range(9):
            self.m.addTrackName(t, 0, ['bass', 'lead', 'double', 'clav', 'pad', 'brass',
                                       'fx-rev', 'rev-cym', 'drums'][t])
            self.m.addTempo(t, 0, BPM)
            if t != T_DRUM:
                self.m.addProgramChange(t, CH[t], 0, PROG[t])
        # channel volumes (mix)
        for t, v in {T_BASS: 100, T_LEAD: 96, T_DBL: 50, T_CLAV: 86, T_PAD: 72,
                     T_BRASS: 88, T_FX: 60, T_RCYM: 70, T_DRUM: 100}.items():
            self.m.addControllerEvent(t, CH[t], 0, 7, v)
        # reverb / chorus sends: keep bass dry, lead a bit wet
        for t, (rv, ch) in {T_BASS: (10, 0), T_LEAD: (45, 20), T_DBL: (40, 30),
                            T_CLAV: (35, 10), T_PAD: (60, 40), T_BRASS: (40, 10),
                            T_FX: (50, 0), T_RCYM: (30, 0), T_DRUM: (25, 0)}.items():
            self.m.addControllerEvent(t, CH[t], 0, 91, rv)
            self.m.addControllerEvent(t, CH[t], 0, 93, ch)
        # pitch-bend range 12 semitones on FX channel (RPN 0)
        for cc, val in ((101, 0), (100, 0), (6, 12), (38, 0)):
            self.m.addControllerEvent(T_FX, CH[T_FX], 0, cc, val)
        for p in range(passes):
            self.write_pass(p * LOOP_BEATS)
        if ending:
            self.write_ending(passes * LOOP_BEATS)

    # --- helpers ---
    def note(self, t, pitch, start, dur, vel):
        pitch = int(pitch)
        key = (t, pitch)
        end = start + dur
        prev = self.active.get(key, -1)
        if start < prev:          # never overlap the same pitch on the same track
            start = prev + 0.01
            dur = end - start
            if dur <= 0.03:
                return
        self.active[key] = start + dur
        self.m.addNote(t, CH[t], max(0, min(127, pitch)), float(start), float(dur),
                       max(1, min(127, int(vel))))

    def dr(self, p, s, v):
        self.m.addNote(T_DRUM, 9, p, float(s), 0.25, max(1, min(127, int(v))))

    # --- parts ---
    def bass_bar(self, s, chord, sec, nxt):
        r = n(ROOT[chord])
        v = 100 if sec in ('A2', 'tag') else 94
        # funky octave groove (original)
        pat = [(0, r, .4, v + 8), (.75, r, .2, v - 10), (1, r + 12, .3, v), (1.5, r, .3, v - 6),
               (2, r, .4, v + 4), (2.5, r + 12, .25, v - 4), (3, r + 7, .3, v - 4), (3.5, r + 12, .3, v - 2)]
        if sec == 'bridge':
            pat = [(b * .5, r, .3, v - 8 + (4 if b % 2 == 0 else 0)) for b in range(8)]
        for b, p, d, vv in pat:
            self.note(T_BASS, p, s + b, d, vv)

    def clav_bar(self, s, chord, sec):
        tones = [n(x) for x in CHORDS[chord]]
        vel = 72 if sec != 'bridge' else 60
        for off in (.5, 1.5, 2.5, 3.5):
            for p in tones:
                self.note(T_CLAV, p, s + off, .22, vel)
        if sec in ('A', 'A2', 'tag', 'B'):
            for p in tones:           # extra 16th push on 'and-a' of 2
                self.note(T_CLAV, p, s + 1.75, .15, vel - 14)

    def pad_bar(self, s, chord, sec):
        if sec == 'intro':
            return
        vel = 60 if sec in ('B', 'bridge') else 48
        for p in CHORDS[chord]:
            self.note(T_PAD, n(p) - 12 + 12, s, 3.9, vel)

    def lead_bar(self, s, bar_notes, dbl=False, vscale=1.0):
        for name, b, d, v in bar_notes:
            self.note(T_LEAD, n(name), s + b, d * .95, v * vscale)
            if dbl:
                self.note(T_DBL, n(name) - 12, s + b, d * .95, v * .8)

    def brass_hits(self, s, chord, pattern):
        tones = [n(x) + 12 for x in CHORDS[chord]]
        for b, d, v in pattern:
            for p in tones:
                self.note(T_BRASS, p, s + b, d, v)

    def drums_bar(self, s, sec, bar_in_sec, last_of_sec):
        full = sec in ('A2', 'tag', 'B')
        # kick
        if sec == 'B' or sec == 'A2':
            kicks = [0, 1, 2, 3]
            if sec == 'A2':
                kicks += [2.5]
        elif sec == 'bridge':
            kicks = [0, 2] if bar_in_sec < 2 else [0, 1, 2, 3]
        else:
            kicks = [0, 1.5, 2, 3.5] if sec != 'intro' else [0, 1.5, 2]
        for k in kicks:
            self.dr(KICK, s + k, 112 if k in (0, 2) else 100)
        # snare backbeat
        if sec != 'bridge':
            for b in (1, 3):
                self.dr(SNARE, s + b, 104)
                if full:
                    self.dr(CLAP, s + b, 70)
        # hats
        for i in range(8):
            b = i * .5
            if sec in ('B', 'A2') and i % 2 == 1:
                self.dr(OHH, s + b, 70)
            else:
                self.dr(CHH, s + b, 78 if i % 2 == 0 else 62)
        if sec in ('A', 'tag', 'intro'):
            for i in range(8):         # light 16th ghost hats
                self.dr(PHH, s + i * .5 + .25, 38)
        # bridge snare build (bars 3-4 of bridge)
        if sec == 'bridge':
            if bar_in_sec == 2:
                for i in range(8):
                    self.dr(SNARE, s + i * .5, 60 + i * 4)
            elif bar_in_sec == 3:
                for i in range(16):
                    self.dr(SNARE, s + i * .25, 80 + i * 2.5)
            else:
                self.dr(SNARE, s + 1, 90)
                self.dr(SNARE, s + 3, 90)
        # section-end fills
        if last_of_sec and sec not in ('bridge',):
            for i, (p, v) in enumerate([(TOM_H, 96), (TOM_H, 90), (TOM_M, 96), (TOM_L, 104)]):
                self.dr(p, s + 3 + i * .25, v)

    def fx_rev(self, s, beats, lo, hi, revs=0):
        """Engine-rev riser: held saw with pitch wheel sweep (range +-12 st)."""
        self.note(T_FX, lo, s, beats - .05, 70)
        steps = int(beats * 16)
        for i in range(steps + 1):
            x = i / steps
            if revs:
                import math
                # two blips then a full climb
                blip = 0.35 * abs(math.sin(math.pi * min(1.0, x * 2) * revs)) if x < .5 else 0
                y = blip if x < .5 else (x - .5) * 2
            else:
                y = x
            semis = (hi - lo) * y
            val = int(max(-8192, min(8191, semis / 12 * 8191)))
            self.m.addPitchWheelEvent(T_FX, CH[T_FX], s + beats * x, val)
        self.m.addPitchWheelEvent(T_FX, CH[T_FX], s + beats, 0)

    def write_pass(self, off):
        a_i = b_i = 0
        for bar, chord in enumerate(SONG):
            s = off + bar * BAR
            sec = SECTION[bar]
            first = bar == 0 or SECTION[bar - 1] != sec
            last = bar == BARS - 1 or SECTION[bar + 1] != sec
            bar_in_sec = bar - SECTION.index(sec)
            nxt = SONG[(bar + 1) % BARS]
            self.bass_bar(s, chord, sec, nxt)
            self.clav_bar(s, chord, sec)
            self.pad_bar(s, chord, sec)
            self.drums_bar(s, sec, bar_in_sec, last)
            if first and sec in ('A', 'B', 'A2', 'tag', 'intro'):
                self.dr(CRASH, s, 100 if sec != 'intro' else 84)
            if sec == 'A':
                self.lead_bar(s, HOOK[bar_in_sec])
            elif sec == 'B':
                self.lead_bar(s, BMEL[bar_in_sec], dbl=True)
                self.brass_hits(s, chord, [(0, .4, 66)])
            elif sec == 'A2':
                self.lead_bar(s, HOOK[bar_in_sec], dbl=True, vscale=1.04)
                self.brass_hits(s, chord, [(0, .3, 74), (1.5, .3, 66)] if bar_in_sec % 2 == 0
                                else [(0, .3, 70), (2.5, .3, 64)])
            elif sec == 'tag':
                self.lead_bar(s, HOOK[bar_in_sec], dbl=True, vscale=1.04)
                self.brass_hits(s, chord, [(0, .3, 74), (1.5, .3, 66)])
            elif sec == 'intro':
                if bar_in_sec == 3:  # brass pickup signalling the hook
                    self.brass_hits(s, chord, [(2, .3, 70), (2.5, .3, 74), (3, .6, 80)])
            # engine rev + reverse cymbal swells
            if sec == 'intro' and bar_in_sec == 2:
                self.fx_rev(s, 8, n('D3'), n('D4'), revs=2)
            if sec == 'bridge' and bar_in_sec == 2:
                self.fx_rev(s, 8, n('A2'), n('A3'))
            if last and sec in ('intro', 'B', 'bridge', 'A2'):
                self.note(T_RCYM, 60, s + 1, 3, 76)
            if sec == 'B' and last:
                self.brass_hits(s, chord, [(3, .25, 70), (3.5, .4, 78)])
        # (bar 36 = A chord + tom fill -> resolves to bar 1 D: seamless V-I loop)

    def write_ending(self, s):
        """Preview-only resolving hit so the listening render ends naturally."""
        self.dr(CRASH, s, 110)
        self.dr(KICK, s, 118)
        self.note(T_BASS, n('D2'), s, 1.5, 104)
        for p in CHORDS['D']:
            self.note(T_BRASS, n(p) + 12, s, 1.6, 84)
            self.note(T_PAD, n(p), s, 3.5, 60)
        self.note(T_LEAD, n('D6'), s, 1.8, 108)
        self.note(T_DBL, n('D5'), s, 1.8, 80)

    def save(self, path):
        with open(path, 'wb') as f:
            self.m.writeFile(f)


if __name__ == '__main__':
    Song(1).save(os.path.join(HERE, 'menu-bgm.mid'))
    Song(3).save(os.path.join(HERE, '_render_3x.mid'))
    Song(1, ending=True).save(os.path.join(HERE, '_render_preview.mid'))
    print('ok', BPM, 'bpm', BARS, 'bars', LOOP_BEATS * 60 / BPM, 's loop')
