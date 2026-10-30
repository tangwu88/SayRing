"""Generate the bundled four-second reminder tone; no third-party audio."""
import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
DURATION = 4


def generate(destination):
    frames = bytearray()
    for index in range(SAMPLE_RATE * DURATION):
        at = index / SAMPLE_RATE
        phase = at % 1.0
        value = 0.0
        for start, frequency in ((0.08, 880), (0.36, 1174)):
            elapsed = phase - start
            if 0 <= elapsed < 0.18:
                envelope = min(1.0, elapsed / 0.012, (0.18 - elapsed) / 0.022)
                value += 0.25 * envelope * math.sin(2 * math.pi * frequency * elapsed)
        frames.extend(struct.pack('<h', round(value * 32767)))
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(SAMPLE_RATE)
        audio.writeframes(frames)


if __name__ == '__main__':
    generate(Path(__file__).resolve().parents[1] / 'assets/audio/health_reminder_alarm.wav')
