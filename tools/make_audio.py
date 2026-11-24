#!/usr/bin/env python3
"""Generates every sound and music track in assets/audio/.

Everything is synthesised from scratch with numpy (no samples, no recordings),
so the output is original and released under CC0 along with this script.
Re-run it after changing a sound:

    python3 tools/make_audio.py          # needs numpy and ffmpeg (libvorbis)

Each sound is a function below. Loops (ambience, music) are rendered so the
end wraps onto the start, which makes them loop without a click.
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ helpers

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def fft_filter(x, lo=0.0, hi=SR / 2, tilt=0.0):
    """Band-pass x with soft edges in the frequency domain (circular, so loops stay seamless)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = np.ones_like(f)
    if lo > 0:
        gain *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4)
    if hi < SR / 2:
        gain *= 1 / (1 + (f / hi) ** 4)
    if tilt:
        gain *= (np.maximum(f, 20) / 1000.0) ** tilt
    return np.fft.irfft(spec * gain, len(x))


def env(n, a=0.005, d=0.1, curve=1.0):
    """Attack then exponential-ish decay over n samples."""
    t = np.arange(n) / SR
    att = np.clip(t / max(a, 1e-4), 0, 1)
    dec = np.exp(-np.maximum(t - a, 0) / max(d, 1e-4)) ** curve
    return att * dec


def adsr(n, a, r):
    t = np.arange(n) / SR
    total = n / SR
    e = np.clip(t / max(a, 1e-4), 0, 1)
    e *= np.clip((total - t) / max(r, 1e-4), 0, 1)
    return e


def sweep(f0, f1, dur, shape="sine"):
    t = t_axis(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


def reverb(x, length=1.6, mix=0.25, damp=3000, seed=1):
    r = np.random.default_rng(seed)
    n = int(length * SR)
    ir = r.uniform(-1, 1, n) * np.exp(-np.arange(n) / SR * (6.9 / length))
    ir = fft_filter(ir, 200, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    size = len(x) + n
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    out = np.zeros(size)
    out[: len(x)] += x * (1 - mix)
    out += wet * mix
    return out


def loop_reverb(x, length=2.0, mix=0.3, damp=3000, seed=1):
    """Reverb whose tail wraps around, so the loop stays seamless."""
    y = reverb(x, length, mix, damp, seed)
    out = y[: len(x)].copy()
    tail = y[len(x):]
    out[: len(tail)] += tail
    return out


def mx(*parts):
    """Mixes arrays of different lengths."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade_edges(x, ms=4):
    n = int(SR * ms / 1000)
    if len(x) > 2 * n:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    return x


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def write(name, x, peak=0.89, loop=False, quality=4):
    os.makedirs(OUT, exist_ok=True)
    x = normalize(x, peak)
    if not loop:
        x = fade_edges(x)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "a.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        dst = os.path.join(OUT, name + ".ogg")
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", str(quality), dst],
            check=True,
        )
    print(f"  {name}.ogg  {len(x) / SR:5.2f}s")


# ------------------------------------------------------------------ instruments

def pluck(freq, dur, bright=1.0, decay=0.9):
    """Additive plucked string: upper harmonics die faster."""
    t = t_axis(dur)
    y = np.zeros_like(t)
    for k in range(1, 9):
        amp = (1.0 / k) * (bright ** (k - 1))
        y += amp * np.sin(2 * np.pi * freq * k * t * (1 + 0.0004 * k)) * np.exp(-t * (k * 1.6 / decay))
    return y * np.clip(t / 0.003, 0, 1) * end_fade(t, dur)


def end_fade(t, dur):
    return np.clip((dur - t) / min(0.2, dur * 0.4), 0, 1)


def bell(freq, dur):
    t = t_axis(dur)
    parts = [(1.0, 1.0, 1.2), (2.76, 0.45, 2.2), (5.4, 0.25, 3.5), (8.93, 0.12, 5.0), (0.5, 0.25, 0.9)]
    y = sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t * d) for r, a, d in parts)
    return y * np.clip(t / 0.002, 0, 1) * end_fade(t, dur)


def flute(freq, dur, breath=0.06):
    t = t_axis(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / SR
    y = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    y += breath * fft_filter(noise(dur), freq * 0.8, freq * 3)
    return y * adsr(len(t), 0.08, 0.18)


def pad(freqs, dur, attack=1.2, release=1.2):
    t = t_axis(dur)
    y = np.zeros_like(t)
    for f in freqs:
        for det in (-0.004, 0.0, 0.004):
            for k, a in ((1, 1.0), (2, 0.35), (3, 0.12)):
                y += a * np.sin(2 * np.pi * f * (1 + det) * k * t + rng.uniform(0, 6.28))
    return y * adsr(len(t), attack, release) / (len(freqs) * 3)


def bass(freq, dur):
    t = t_axis(dur)
    y = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)
    return y * env(len(t), 0.01, dur * 0.6) * adsr(len(t), 0.005, 0.05)


def drum(dur=0.5, f0=110, f1=45, nz=0.2):
    body = sweep(f0, f1, dur) * env(int(dur * SR), 0.002, 0.16)
    hit = fft_filter(noise(dur), 300, 2500) * env(int(dur * SR), 0.001, 0.025)
    return body + nz * hit


def place(buf, x, at, wrap=False):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:end] += x[: end - i]
    # Anything past the end wraps to the start (seamless loops).
    if wrap and i + len(x) > len(buf):
        over = x[end - i:]
        buf[: len(over)] += over


# ------------------------------------------------------------------ sound effects

def sfx():
    print("Sound effects")
    d = 0.11
    write("step_grass", fft_filter(noise(d), 300, 1800) * env(int(d * SR), 0.004, 0.03), 0.6)
    write("step_stone", (fft_filter(noise(d), 900, 5000) * env(int(d * SR), 0.001, 0.018)
                         + 0.4 * sweep(420, 300, d) * env(int(d * SR), 0.001, 0.02)), 0.6)
    write("step_wood", (fft_filter(noise(d), 500, 2500) * env(int(d * SR), 0.001, 0.02)
                        + 0.8 * sweep(230, 190, d) * env(int(d * SR), 0.001, 0.035)), 0.6)

    d = 0.22
    write("jump", fft_filter(noise(d), 400, 3000) * env(int(d * SR), 0.03, 0.06)
          + 0.25 * sweep(180, 330, d) * env(int(d * SR), 0.01, 0.06), 0.55)
    d = 0.3
    write("land", fft_filter(noise(d), 80, 900) * env(int(d * SR), 0.002, 0.06)
          + 0.7 * sweep(120, 50, d) * env(int(d * SR), 0.002, 0.07), 0.8)

    # Block breaking: a short crumble made of several tiny grains.
    def crumble(lo, hi, grains, tone=0.0, f=200):
        dur = 0.42
        buf = np.zeros(int(dur * SR))
        for g in range(grains):
            gd = 0.06
            x = fft_filter(noise(gd), lo, hi) * env(int(gd * SR), 0.001, 0.012)
            if tone:
                x += tone * sweep(f * rng.uniform(0.9, 1.2), f * 0.7, gd) * env(int(gd * SR), 0.001, 0.02)
            place(buf, x * rng.uniform(0.5, 1.0), rng.uniform(0, 0.12) + g * 0.025)
        return buf * env(len(buf), 0.001, 0.15)

    write("break_soft", crumble(200, 2200, 6))
    write("break_stone", crumble(800, 6000, 8, 0.6, 520))
    write("break_wood", crumble(300, 2400, 6, 1.0, 210))
    write("break_leaves", crumble(1500, 8000, 9), 0.6)
    write("break_glass", mx(sum(bell(f, 0.9) * 0.4 for f in (1900, 2530, 3170)), crumble(3000, 9000, 6)), 0.7)

    d = 0.09
    hit = fft_filter(noise(d), 200, 1500) * env(int(d * SR), 0.001, 0.02)
    write("hit_block", hit + 0.6 * sweep(260, 200, d) * env(int(d * SR), 0.001, 0.025), 0.45)

    d = 0.25
    write("place", fft_filter(noise(d), 150, 1500) * env(int(d * SR), 0.001, 0.03)
          + 0.9 * sweep(170, 110, d) * env(int(d * SR), 0.001, 0.05), 0.8)

    d = 0.26
    write("swing", fft_filter(noise(d), 700, 4500) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2, 0.5)

    d = 0.3
    write("enemy_hit", fft_filter(noise(d), 300, 3000) * env(int(d * SR), 0.001, 0.03)
          + 0.8 * sweep(520, 240, d, "tri") * env(int(d * SR), 0.002, 0.09), 0.8)
    d = 0.7
    poof = fft_filter(noise(d), 300, 4000) * env(int(d * SR), 0.01, 0.15)
    write("enemy_defeat", poof + 0.7 * sweep(600, 120, d, "tri") * env(int(d * SR), 0.002, 0.2)
          + 0.3 * bell(880, d), 0.8)
    d = 0.18
    write("enemy_hop", 0.6 * sweep(160, 260, d, "tri") * env(int(d * SR), 0.003, 0.04)
          + 0.5 * fft_filter(noise(d), 200, 1200) * env(int(d * SR), 0.002, 0.02), 0.5)

    d = 0.4
    write("hurt", fft_filter(noise(d), 120, 1400) * env(int(d * SR), 0.001, 0.05)
          + sweep(300, 110, d, "tri") * env(int(d * SR), 0.002, 0.12), 0.85)

    d = 0.45
    flap = sum(fft_filter(noise(d), 400, 2500) * np.exp(-((t_axis(d) - c) / 0.025) ** 2) for c in (0.05, 0.13, 0.2))
    write("glider_open", flap + 0.3 * fft_filter(noise(d), 300, 1500) * env(int(d * SR), 0.05, 0.15), 0.7)
    write("glider_close", flap[::-1] * 0.8, 0.55)

    d = 0.7
    buf = np.zeros(int(d * SR))
    for i, m in enumerate((74, 78, 81)):
        place(buf, pluck(mtof(m), 0.6, 0.6) * 0.6, i * 0.07)
    write("craft", reverb(mx(buf, 0.4 * crumble(300, 2400, 3)), 0.8, 0.2), 0.7)

    d = 0.3
    buf = np.zeros(int(d * SR))
    place(buf, bell(mtof(84), 0.25), 0)
    place(buf, bell(mtof(91), 0.25) * 0.7, 0.05)
    write("pickup", buf, 0.4)

    d = 2.2
    buf = np.zeros(int(d * SR))
    for i, m in enumerate((62, 66, 69, 74, 78)):
        place(buf, mx(bell(mtof(m), 1.6) * 0.7, pluck(mtof(m), 1.2) * 0.5), i * 0.11)
    place(buf, pad([mtof(50), mtof(57), mtof(62)], 1.8, 0.1, 1.2) * 0.8, 0.0)
    write("quest", reverb(buf, 2.0, 0.3), 0.8)

    d = 1.1
    buf = np.zeros(int(d * SR))
    place(buf, bell(mtof(69), 0.8), 0)
    place(buf, bell(mtof(76), 0.8) * 0.8, 0.12)
    write("goal", reverb(buf, 1.2, 0.25), 0.55)

    d = 2.0
    rumble = fft_filter(noise(d), 30, 260) * adsr(int(d * SR), 0.2, 0.6)
    grind = fft_filter(noise(d), 600, 2400) * adsr(int(d * SR), 0.3, 0.4) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t_axis(d)))
    write("door", rumble + 0.25 * grind + 0.4 * drum(d, 70, 35, 0.0), 0.9)

    d = 0.6
    write("plate_on", 0.8 * drum(d, 180, 90, 0.4) + 0.4 * bell(mtof(69), d), 0.7)
    write("plate_off", 0.7 * drum(d, 150, 70, 0.4) + 0.3 * bell(mtof(64), d), 0.6)

    d = 3.0
    buf = np.zeros(int(d * SR))
    for i, m in enumerate((69, 72, 76, 79, 84, 88)):
        place(buf, bell(mtof(m), 2.0) * 0.5, i * 0.09)
    swell = fft_filter(noise(d), 1000, 7000) * adsr(int(d * SR), 1.0, 1.5)
    write("node", reverb(buf + 0.15 * swell + pad([mtof(57), mtof(64), mtof(69)], d, 0.5, 1.5), 2.5, 0.35), 0.85)

    d = 1.4
    whoosh = fft_filter(noise(d), 200, 1600) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 3
    write("gust", whoosh * (0.7 + 0.3 * np.sin(2 * np.pi * 3 * t_axis(d))), 0.75)
    write("gust_warn", fft_filter(noise(0.9), 1500, 6000) * np.linspace(0, 1, int(0.9 * SR)) ** 2, 0.35)

    d = 0.08
    write("ui_click", 0.6 * sweep(1200, 900, d) * env(int(d * SR), 0.001, 0.015), 0.4)
    for i, f in enumerate((520, 600, 680)):
        d = 0.07
        write(f"talk{i + 1}", 0.6 * sweep(f, f * 1.1, d, "tri") * env(int(d * SR), 0.003, 0.03), 0.35)

    d = 0.7
    write("splash", fft_filter(noise(d), 300, 6000) * env(int(d * SR), 0.005, 0.12)
          + 0.4 * fft_filter(noise(d), 80, 400) * env(int(d * SR), 0.01, 0.2), 0.7)

    d = 0.6
    write("deny", 0.5 * (sweep(300, 220, d, "tri") * env(int(d * SR), 0.002, 0.12)), 0.4)

    d = 1.4
    rise = fft_filter(noise(d), 400, 3000) * np.linspace(0.2, 1, int(d * SR)) * adsr(int(d * SR), 0.05, 0.5)
    write("vent_place", rise + 0.4 * sweep(200, 600, d, "tri") * env(int(d * SR), 0.05, 0.6), 0.7)


# ------------------------------------------------------------------ loops

def ambience():
    print("Ambience")
    dur = 24.0
    n = int(dur * SR)
    t = np.arange(n) / SR

    # Hearthvale meadow: soft breeze plus a few birds.
    breeze = fft_filter(noise(dur), 150, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * t / dur * 3))
    buf = breeze * 0.35
    for i in range(14):
        at = rng.uniform(0, dur)
        f = rng.uniform(2400, 4200)
        notes = rng.integers(2, 5)
        for k in range(notes):
            cd = rng.uniform(0.06, 0.13)
            chirp = sweep(f * rng.uniform(0.9, 1.1), f * rng.uniform(1.1, 1.5), cd) * np.sin(np.linspace(0, np.pi, int(cd * SR)))
            place(buf, chirp * 0.12, at + k * (cd + 0.04), True)
    write("amb_meadow", loop_reverb(buf, 1.5, 0.25), 0.5, loop=True)

    # Gale Steppes: deeper wind with slow howling swells.
    w1 = fft_filter(noise(dur), 100, 700)
    w2 = fft_filter(noise(dur), 500, 1500)
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * t / dur * 4 + 1.0) ** 2
    howl = sum(np.sin(2 * np.pi * np.cumsum(f + 25 * np.sin(2 * np.pi * t / dur * 2 + f)) / SR) for f in (330, 440))
    buf = w1 * swell + 0.4 * w2 * (1 - swell) + 0.04 * howl * swell
    write("amb_steppes", buf, 0.6, loop=True)

    # Windworn Hollow: low hum, distant drips.
    hum = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((55, 1.0), (82.5, 0.4), (110, 0.2)))
    hum *= 0.8 + 0.2 * np.sin(2 * np.pi * t / dur * 2)
    buf = hum * 0.25 + 0.15 * fft_filter(noise(dur), 60, 300)
    for i in range(10):
        dd = 0.15
        drip = sweep(rng.uniform(900, 1500), rng.uniform(1800, 2600), dd) * env(int(dd * SR), 0.001, 0.025)
        place(buf, drip * 0.3, rng.uniform(0, dur), True)
    write("amb_hollow", loop_reverb(buf, 3.0, 0.4, 2500), 0.55, loop=True)

    # Wind while gliding (volume follows speed in game).
    dur = 6.0
    t = np.arange(int(dur * SR)) / SR
    buf = fft_filter(noise(dur), 250, 2500) * (0.8 + 0.2 * np.sin(2 * np.pi * t / dur * 3))
    write("glide_wind", buf, 0.6, loop=True)

    # Updraft vent: rushing air column.
    buf = fft_filter(noise(dur), 300, 3500) * (0.85 + 0.15 * np.sin(2 * np.pi * t / dur * 6))
    write("vent_loop", buf, 0.55, loop=True)


def song(bpm, bars, chords, scale, lead, seed, lead_density=0.55, drums=None, arp=True, octave=0):
    """A small generative arrangement: pad, bass, arpeggio and a lead line."""
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    dur = bar * bars
    buf = np.zeros(int(dur * SR))
    prev = scale[len(scale) // 2]
    for b in range(bars):
        root, quality = chords[b % len(chords)]
        third = 3 if quality == "m" else 4
        tones = [root, root + third, root + 7]
        start = b * bar
        place(buf, pad([mtof(m + 12) for m in tones], bar + 0.6, 0.6, 0.8) * 0.5, start, True)
        place(buf, bass(mtof(root - 12), beat * 1.8) * 0.5, start, True)
        place(buf, bass(mtof(root - 12 + (7 if b % 2 else 0)), beat * 1.8) * 0.4, start + beat * 2, True)
        if arp:
            pattern = [0, 1, 2, 1, 2, 0, 1, 2]
            for i, p in enumerate(pattern):
                m = tones[p] + 12 + (12 if i in (4, 6) else 0)
                place(buf, pluck(mtof(m), beat * 1.5, 0.5) * 0.22, start + i * beat / 2, True)
        if drums:
            for pos, kind in drums:
                if kind == "k":
                    place(buf, drum(0.5, 110, 45, 0.15) * 0.55, start + pos * beat, True)
                else:
                    place(buf, drum(0.25, 260, 160, 0.6) * 0.22, start + pos * beat, True)
        # Lead: stays near the last note, favours chord tones on strong beats.
        if b % 8 >= 6 and bars > 8:
            continue  # breathe every few bars
        pos = 0.0
        while pos < 4.0:
            length = r.choice([0.5, 1.0, 1.0, 1.5, 2.0]) if r.random() < 0.85 else 1.0
            length = min(length, 4.0 - pos)
            if r.random() < lead_density:
                strong = pos in (0.0, 2.0)
                cands = [m for m in scale if abs(m - prev) <= 4]
                if strong:
                    chord_c = [m for m in cands if (m - root) % 12 in ((0, third, 7))]
                    cands = chord_c or cands
                m = int(r.choice(cands))
                prev = m
                place(buf, lead(mtof(m + octave), length * beat + 0.3) * 0.32, start + pos * beat, True)
            pos += length
    return loop_reverb(buf, 2.4, 0.3, 3500)


def music():
    print("Music")
    # Hearthvale: warm and gentle, D major pentatonic over I-vi-IV-V.
    d_pent = [62, 64, 66, 69, 71, 74, 76, 78, 81]
    hv = song(88, 24, [(50, "M"), (47, "m"), (43, "M"), (45, "M"), (50, "M"), (45, "M"), (47, "m"), (43, "M")],
              d_pent, lambda f, d: flute(f, d, 0.03) * 0.8 + pluck(f, d, 0.4) * 0.3, seed=11)
    write("music_hearthvale", hv, 0.8, loop=True, quality=5)

    # Gale Steppes: open and windy, D dorian over a drone, with frame drums.
    d_dor = [62, 64, 65, 67, 69, 71, 72, 74, 76]
    st = song(104, 24, [(50, "m"), (48, "M"), (55, "M"), (50, "m"), (53, "M"), (48, "M"), (55, "M"), (57, "m")],
              d_dor, lambda f, d: flute(f, d, 0.08), seed=23, lead_density=0.5,
              drums=[(0, "k"), (1.5, "s"), (2, "k"), (3, "s"), (3.5, "s")], arp=False)
    t = np.arange(len(st)) / SR
    drone = (np.sin(2 * np.pi * mtof(38) * t) + 0.5 * np.sin(2 * np.pi * mtof(45) * t)) * 0.08
    write("music_steppes", st + drone, 0.8, loop=True, quality=5)

    # Windworn Hollow: slow, mysterious bells over a low drone.
    a_min = [57, 59, 60, 64, 65, 69, 71, 72]
    ho = song(66, 12, [(45, "m"), (41, "M"), (45, "m"), (40, "M")], a_min,
              lambda f, d: bell(f, d + 1.0) * 0.6, seed=5, lead_density=0.35, arp=False, octave=12)
    t = np.arange(len(ho)) / SR
    drone = np.sin(2 * np.pi * 55 * t) * 0.12 * (0.7 + 0.3 * np.sin(2 * np.pi * t / (len(ho) / SR) * 3))
    write("music_hollow", ho + drone, 0.75, loop=True, quality=5)


if __name__ == "__main__":
    only = sys.argv[1:]
    for name, fn in (("sfx", sfx), ("ambience", ambience), ("music", music)):
        if not only or name in only:
            fn()
