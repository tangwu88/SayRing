import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

test('bundled alert is bounded mono PCM with quiet gaps and no clipping', () => {
  const bytes = readFileSync(new URL('../assets/audio/health_reminder_alarm.wav', import.meta.url));
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
  assert.equal(bytes.toString('ascii', 8, 12), 'WAVE');
  assert.equal(bytes.readUInt16LE(20), 1);
  assert.equal(bytes.readUInt16LE(22), 1);
  assert.equal(bytes.readUInt16LE(34), 16);
  const seconds = (bytes.length - 44) / bytes.readUInt32LE(28);
  assert.ok(seconds >= 2 && seconds <= 6);
  let peak = 0, quiet = 0;
  for (let i = 44; i < bytes.length; i += 2) {
    const sample = Math.abs(bytes.readInt16LE(i));
    peak = Math.max(peak, sample);
    if (sample === 0) quiet++;
  }
  assert.ok(peak > 1000 && peak < 16000);
  assert.ok(quiet > (bytes.length - 44) / 8);
});
