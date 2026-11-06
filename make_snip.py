# Generates snip.wav: two short metallic clicks, like scissors closing.
import math, random, struct, wave
R = 44100
random.seed(7)
def burst(ms, freq, decay):
    n = int(R * ms / 1000)
    return [(0.6 * random.uniform(-1, 1) + 0.4 * math.sin(2 * math.pi * freq * i / R))
            * math.exp(-i / (R * decay)) for i in range(n)]
s = burst(18, 5200, 0.004) + [0.0] * int(R * 0.045) + burst(40, 3600, 0.008)
s += [0.0] * int(R * 0.05)
with wave.open("snip.wav", "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 0.8 * 32767)) for x in s))
