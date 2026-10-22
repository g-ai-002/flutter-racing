# -*- coding: utf-8 -*-
"""生成全部游戏音效资产（assets/audio/*.wav），纯 stdlib、确定性输出。

用法：
    python .build/generate_audio.py

重新运行会覆盖旧文件；音色为 8-bit 风格 chiptune（方波/锯齿/噪声），
采样率 22050Hz、单声道、16-bit PCM。循环类音效（bgm/engine/drift）的
波形按整数周期设计，保证 ReleaseMode.loop 下无缝循环。
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / 'assets' / 'audio'

random.seed(42)


def write_wav(name, samples):
    """samples 为 [-1, 1] 浮点列表，写入 16-bit PCM WAV。"""
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32767)
        frames += struct.pack('<h', v)
    path = OUT_DIR / name
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f'  {name:14s} {len(samples) / SR:6.2f}s  {path.stat().st_size / 1024:7.1f} KB')


def silence(dur):
    return [0.0] * int(dur * SR)


def square(freq, dur, duty=0.5, amp=1.0):
    n = int(dur * SR)
    out = []
    for i in range(n):
        ph = (i * freq / SR) % 1.0
        out.append(amp * (1.0 if ph < duty else -1.0))
    return out


def sine(freq, dur, amp=1.0, phase=0.0):
    n = int(dur * SR)
    return [amp * math.sin(2 * math.pi * freq * i / SR + phase) for i in range(n)]


def saw(freq, dur, amp=1.0):
    n = int(dur * SR)
    return [amp * (2.0 * ((i * freq / SR) % 1.0) - 1.0) for i in range(n)]


def noise(dur, amp=1.0):
    n = int(dur * SR)
    return [amp * (random.random() * 2.0 - 1.0) for _ in range(n)]


def mix(*tracks):
    """按最长长度叠加。"""
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def adsr(samples, attack=0.01, decay=0.0, sustain=1.0, release=0.05):
    """简单包络：attack/decay/release 秒。"""
    n = len(samples)
    na = int(attack * SR)
    nr = int(release * SR)
    nd = int(decay * SR)
    out = list(samples)
    for i in range(n):
        g = 1.0
        if i < na:
            g = i / max(1, na)
        elif i < na + nd:
            g = sustain + (1.0 - sustain) * (1.0 - (i - na) / max(1, nd))
        if i > n - nr:
            g *= max(0.0, (n - i) / max(1, nr))
        out[i] *= g
    return out


def sweep(f0, f1, dur, amp=1.0, wave_fn=sine):
    """线性频率扫描（相位积分保证连续）。"""
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SR
        out.append(amp * math.sin(phase) if wave_fn is sine else amp * math.sin(phase))
    return out


def highpass(samples, k=0.95):
    """一阶高通（差分），让噪声/引擎更有颗粒感。"""
    out = [samples[0]]
    for i in range(1, len(samples)):
        out.append(samples[i] - k * samples[i - 1])
    return out


def gen_bgm():
    """8 小节 140BPM 循环 BGM：Am F C G 琶音 + 贝斯 + hat。"""
    bpm = 140
    eighth = 60.0 / bpm / 2.0
    total = eighth * 64
    n = int(total * SR)
    buf = [0.0] * n

    chords = [
        (110.00, [220.00, 261.63, 329.63, 440.00]),  # Am
        (87.31, [174.61, 220.00, 261.63, 349.23]),   # F
        (130.81, [261.63, 329.63, 392.00, 523.25]),  # C
        (98.00, [196.00, 246.94, 293.66, 392.00]),   # G
    ]
    arp_pat = [0, 1, 2, 3, 2, 3, 1, 2]

    for bar in range(8):
        chord = chords[bar // 2 % 4]
        for e in range(8):
            idx = (bar * 8 + e)
            t0 = idx * eighth
            # 琶音（八分音符）
            f = chord[1][arp_pat[e]]
            dur = eighth * 0.9
            seg = square(f, dur, duty=0.28, amp=0.085)
            i0 = int(t0 * SR)
            for j, v in enumerate(seg):
                buf[i0 + j] += v
            # hat（每个八分一个 tick，正拍重音）
            ht = noise(0.03, 0.05 if e % 2 == 0 else 0.028)
            ht = adsr(ht, 0.001, 0.0, 1.0, 0.02)
            i0 = int(t0 * SR)
            for j, v in enumerate(ht):
                buf[i0 + j] += v
            # 贝斯（每拍一次，占两个八分）
            if e % 2 == 0:
                bs = square(chord[0], eighth * 1.8, duty=0.5, amp=0.13)
                bs = adsr(bs, 0.004, 0.05, 0.8, 0.03)
                i0 = int(t0 * SR)
                for j, v in enumerate(bs):
                    buf[i0 + j] += v
    write_wav('bgm.wav', buf)


def gen_engine():
    """引擎循环：55Hz 谐波堆叠 + LFO 颤动，1.0s 整周期无缝循环。"""
    dur = 1.0
    n = int(dur * SR)
    buf = [0.0] * n
    harmonics = [(55, 0.42), (110, 0.22), (165, 0.13), (220, 0.08), (275, 0.05), (330, 0.03)]
    for f, a in harmonics:
        for i in range(n):
            buf[i] += a * math.sin(2 * math.pi * f * i / SR)
    nz = noise(dur, 0.035)
    nz = highpass(nz, 0.85)
    for i in range(n):
        lfo = 1.0 + 0.14 * math.sin(2 * math.pi * 4 * i / SR)
        buf[i] = buf[i] * lfo + nz[i]
    write_wav('engine.wav', buf)


def gen_drift():
    """漂移摩擦循环：高通噪声 + 10Hz 抖动，0.8s 整周期。"""
    dur = 0.8
    nz = noise(dur, 0.4)
    nz = highpass(nz, 0.6)
    n = len(nz)
    for i in range(n):
        nz[i] *= 0.75 + 0.25 * math.sin(2 * math.pi * 10 * i / SR)
    write_wav('drift.wav', nz)


def gen_countdown():
    write_wav('beep.wav', adsr(sine(880, 0.16, 0.35), 0.004, 0.04, 0.7, 0.06))


def gen_go():
    lead = sweep(660, 1320, 0.14, 0.32)
    lead += sine(1320, 0.31, 0.3)
    lead = adsr(lead, 0.004, 0.02, 0.85, 0.1)
    write_wav('go.wav', lead)


def gen_pickup():
    c1 = adsr(square(660, 0.08, 0.3, 0.22), 0.003, 0.01, 0.8, 0.02)
    c2 = adsr(square(990, 0.11, 0.3, 0.22), 0.003, 0.02, 0.75, 0.03)
    write_wav('pickup.wav', c1 + c2)


def gen_boost():
    whoosh = noise(0.5, 0.28)
    whoosh = highpass(whoosh, 0.5)
    for i in range(len(whoosh)):
        whoosh[i] *= min(1.0, i / (0.1 * SR)) * math.exp(-2.2 * i / SR)
    tone = sweep(220, 990, 0.5, 0.2)
    write_wav('boost.wav', adsr(mix(whoosh, tone), 0.01, 0.05, 0.7, 0.1))


def gen_missile():
    tone = sweep(900, 280, 0.6, 0.3)
    nz = noise(0.6, 0.12)
    nz = highpass(nz, 0.6)
    write_wav('missile.wav', adsr(mix(tone, nz), 0.01, 0.03, 0.8, 0.12))


def gen_explosion():
    dur = 0.7
    nz = noise(dur, 0.55)
    nz = highpass(nz, 0.2)
    thump = sine(60, dur, 0.5)
    for i in range(len(nz)):
        env = math.exp(-5.5 * i / SR)
        nz[i] *= env
        thump[i] *= math.exp(-8.0 * i / SR)
    write_wav('explosion.wav', mix(nz, thump))


def gen_spin():
    n = int(0.5 * SR)
    buf = []
    phase = 0.0
    for i in range(n):
        f = 320 + 180 * math.sin(2 * math.pi * 6 * i / SR)
        phase += 2 * math.pi * f / SR
        trem = 0.7 + 0.3 * math.sin(2 * math.pi * 12 * i / SR)
        env = math.exp(-3.5 * i / SR)
        buf.append(0.3 * trem * env * math.sin(phase))
    write_wav('spin.wav', buf)


def gen_lap():
    notes = [(523.25, 0.09), (659.25, 0.09), (783.99, 0.14)]
    buf = []
    for f, d in notes:
        buf += adsr(square(f, d, 0.3, 0.2), 0.003, 0.01, 0.8, 0.02)
    write_wav('lap.wav', buf)


def gen_finish():
    seq = [(523.25, 0.12), (523.25, 0.12), (659.25, 0.12), (783.99, 0.12)]
    buf = []
    for f, d in seq:
        buf += adsr(square(f, d, 0.3, 0.24), 0.004, 0.01, 0.85, 0.02)
    chord_dur = 0.55
    chord = mix(
        sine(1046.5, chord_dur, 0.2),
        sine(783.99, chord_dur, 0.14),
        sine(659.25, chord_dur, 0.1),
    )
    buf += adsr(chord, 0.02, 0.05, 0.85, 0.2)
    write_wav('finish.wav', buf)


def gen_shield():
    tone = mix(sine(440, 0.3, 0.2), sine(660, 0.3, 0.14))
    write_wav('shield.wav', adsr(tone, 0.03, 0.05, 0.8, 0.12))


def gen_click():
    write_wav('click.wav', adsr(sine(1200, 0.05, 0.25), 0.002, 0.01, 0.6, 0.02))


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f'生成音效到 {OUT_DIR}')
    gen_bgm()
    gen_engine()
    gen_drift()
    gen_countdown()
    gen_go()
    gen_pickup()
    gen_boost()
    gen_missile()
    gen_explosion()
    gen_spin()
    gen_lap()
    gen_finish()
    gen_shield()
    gen_click()
    print('完成')


if __name__ == '__main__':
    main()
