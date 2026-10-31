import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';

export class ReadingReminderSound {
  private player: media.AVPlayer | undefined = undefined;
  private generation: number = 0;
  private timer: number = -1;
  private descriptor: number = -1;
  private queue: Promise<void> = Promise.resolve();
  stop(): void {
    ++this.generation;
    if (this.timer !== -1) clearTimeout(this.timer);
    this.timer = -1;
    const old = this.player, descriptor = this.descriptor; this.player = undefined; this.descriptor = -1;
    if (old || descriptor >= 0) this.queue = this.queue.catch(() => {}).then(async () => {
      try { await old?.release(); } catch {}
      try { if (descriptor >= 0) fs.closeSync(descriptor); } catch {}
    });
  }
  async play(context: common.UIAbilityContext): Promise<void> {
    this.stop();
    const generation = this.generation;
    await this.queue;
    if (generation !== this.generation) return;
    try {
      if (await audio.getAudioManager().getRingerMode() !== audio.AudioRingMode.RINGER_MODE_NORMAL) return;
      if (generation !== this.generation) return;
      const bytes = await context.resourceManager.getRawFileContent('health_reminder_alarm.wav');
      if (generation !== this.generation) return;
      const path = `${context.cacheDir}/say_ring_reading_alarm.wav`;
      const output = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
      try { fs.writeSync(output.fd, bytes.buffer); } finally { fs.closeSync(output); }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      this.descriptor = file.fd;
      const player = await media.createAVPlayer();
      if (generation !== this.generation) { await player.release(); return; }
      this.player = player;
      player.on('stateChange', (state: media.AVPlayerState) => {
        if (generation !== this.generation) return;
        if (state === 'initialized') {
          player.audioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_NOTIFICATION, rendererFlags: 0 };
          player.prepare().catch(() => { if (generation === this.generation) this.stop(); });
        } else if (state === 'prepared') player.play().catch(() => { if (generation === this.generation) this.stop(); });
        else if (state === 'completed' || state === 'error') this.stop();
      });
      player.on('error', () => { if (generation === this.generation) this.stop(); });
      player.fdSrc = { fd: file.fd, offset: 0, length: bytes.length };
      this.timer = setTimeout(() => { if (generation === this.generation) this.stop(); }, 6000);
    } catch { if (generation === this.generation) this.stop(); }
  }
}
export const readingReminderSound: ReadingReminderSound = new ReadingReminderSound();
