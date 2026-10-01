"""Original synthesized game sounds. No third-party recordings are used."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets/audio/sfx"
SPECS = {
    "pistol": (.18, "dry crack and short brass ping"),
    "sword": (.28, "wide airy slash with steel resonance"),
    "fist": (.19, "low soft body thud"),
    "shotgun": (.46, "broad heavy blast and pump rattle"),
    "smg": (.10, "high tight mechanical tick"),
    "rifle": (.22, "sharp mid-range rifle crack"),
    "lmg": (.23, "deep metallic hammer"),
    "grenade": (.40, "hollow launcher thunk and falling whistle"),
    "flamethrower": (.18, "continuous filtered rushing flame"),
    "sniper": (.60, "long sharp crack with spaced echoes"),
    "rocket": (.60, "rising rocket engine rush"),
    "laser": (.42, "bright descending frequency-modulated beam"),
    "zombie": (.36, "wet splat with a low gurgle"),
    "player_hurt": (.34, "body impact and short low vocal grunt"),
    "boss_warning": (.40, "two rising warning tones"),
    "boss_launch": (.24, "missile launch clank and hiss"),
    "round_change": (.65, "ascending three-note round transition"),
    "electric_trap": (.32, "electrical crackle and resonant zap"),
    "explosion": (.65, "deep explosion with gritty debris tail"),
}

def create(name, duration):
    rng = random.Random(name)
    values = []
    low = 0.0
    for i in range(int(duration * RATE)):
        t = i / RATE
        n = rng.uniform(-1, 1)
        low += .12 * (n - low)
        high = n - low
        tone = lambda frequency: math.sin(2 * math.pi * frequency * t)
        decay = lambda rate: math.exp(-rate * t)
        if name == "pistol":
            v = high * decay(55) + .65 * tone(190) * decay(24) + .22 * tone(1800) * decay(18)
        elif name == "sword":
            env = math.sin(math.pi * t / duration) ** 1.6
            v = high * env * .65 + .18 * tone(920) * env
        elif name == "fist":
            v = .9 * tone(74) * decay(25) + .8 * low * decay(34)
        elif name == "shotgun":
            pump = max(0, t - .20)
            rattle = (.35 * high * math.exp(-pump * 35)) if t > .20 else 0
            v = n * decay(15) + .8 * tone(58) * decay(12) + rattle
        elif name == "smg":
            v = high * decay(100) + .4 * tone(860) * decay(65)
        elif name == "rifle":
            v = n * decay(38) + .65 * tone(310) * decay(23) + .16 * tone(2450) * decay(18)
        elif name == "lmg":
            v = .9 * tone(95) * decay(22) + n * decay(43) + .35 * tone(430) * decay(17)
        elif name == "grenade":
            v = tone(85) * decay(14) + low * decay(20) + .18 * math.sin(2 * math.pi * (1100 * t - 700 * t*t)) * decay(5)
        elif name == "flamethrower":
            env = min(1, t * 160) * min(1, (duration - t) * 100)
            v = (low * 2.2 + .15 * n) * env * (.8 + .2 * tone(32))
        elif name == "sniper":
            v = n * decay(60) + tone(110) * decay(20)
            for delay, gain in [(.10, .32), (.23, .18), (.37, .10)]:
                if t > delay: v += gain * n * math.exp(-40 * (t - delay))
        elif name == "rocket":
            env = min(1, t * 50) * math.sin(math.pi * t / duration) ** .65
            v = (low * 2.5 + .3 * high + .35 * math.sin(2 * math.pi * (50 * t + 110 * t*t))) * env
        elif name == "laser":
            carrier = 1800 * t - 1400 * t*t
            v = math.sin(2 * math.pi * carrier + 2.5 * tone(110)) * decay(6) + .18 * tone(3600) * decay(18)
        elif name == "zombie":
            v = low * 2 * decay(11) + .4 * tone(61) * decay(10) + high * decay(42) * (.5 + .5 * tone(53))
        elif name == "player_hurt":
            v = .85 * tone(90) * decay(21) + n * decay(60) + .5 * (tone(125) + .35 * tone(375) + .18 * tone(625)) * decay(9)
        elif name == "boss_warning":
            v = (.55 * tone(620 if t < .17 else 880) + .16 * tone(1240)) * min(1,t*100) * min(1,(duration-t)*60)
        elif name == "round_change":
            note = min(2, int(t / .18))
            v = (.7 * tone([523, 659, 784][note]) + .2 * tone([1046, 1318, 1568][note])) * math.exp(-8 * (t % .18)) * min(1,(duration-t)*25)
        elif name == "electric_trap":
            v = (high * .5 + .7 * math.sin(2*math.pi*(1700*t-2200*t*t) + 2*tone(73))) * decay(11)
        elif name == "explosion":
            v = low * 3 * decay(7) + .8 * math.sin(2*math.pi*(90*t-60*t*t)) * decay(9) + n * decay(17)
        else:
            v = n * decay(28) + tone(145) * decay(16) + low * 1.2 * decay(8)
        values.append(v)
    # Remove DC, normalize safely and avoid discontinuities at either edge.
    mean = sum(values) / len(values)
    values = [v - mean for v in values]
    peak = max(abs(v) for v in values)
    return [v / peak * .82 * min(1, i / 18) * min(1, (len(values) - 1 - i) / 80) for i, v in enumerate(values)]

def write(path, values):
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in values))

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (duration, _) in SPECS.items():
        write(OUT / (name + ".wav"), create(name, duration))
    (OUT / "README.md").write_text("# Original synthesized sound effects\n\n" + "\n".join("- " + name + ": " + desc for name, (_, desc) in SPECS.items()) + "\n", encoding="utf-8")
    print("Created", len(SPECS), "original WAV effects")
