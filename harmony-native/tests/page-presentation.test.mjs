import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? `${specifier}.ts` : specifier, context);
} });
const { careDaySummary, pageLayout, controlHeight, waveformPageCount, waveformPageLabel } = await import('../entry/src/main/ets/model/PagePresentation.ts');
const record = (id, order, fields) => ({ id, order, time: '合成时间', fields, samples: [], frequency: 0 });
const field = (label, value, unit = '次/分') => ({ label, value, unit });
const metric = (key, records, state = 'ready') => ({ key, title: '合成指标', unit: '', state, records });

test('shared day summary uses chronological latest and never changes source record order', () => {
  const rows = [record('late', 20, [field('心率', 82)]), record('early', 10, [field('心率', 62)])];
  const summary = Object.fromEntries(careDaySummary(metric('heart', rows)).map(item => [item.label, item.value]));
  assert.deepEqual(summary, { '记录数': '2 条', '最近': '82 次/分', '平均': '72 次/分', '最高': '82 次/分', '最低': '62 次/分' });
  assert.equal(rows[0].id, 'late');
});

test('pressure summary only averages complete pairs from the same record', () => {
  const rows = [record('a', 1, [field('收缩压', 120, 'mmHg'), field('舒张压', 80, 'mmHg')]),
    record('partial', 2, [field('收缩压', 180, 'mmHg')]),
    record('b', 3, [field('收缩压', 140, 'mmHg'), field('舒张压', 90, 'mmHg')])];
  const summary = careDaySummary(metric('pressure', rows));
  assert.equal(summary.find(item => item.label === '平均').value, '130/85 mmHg');
  assert.equal(summary.find(item => item.label === '最高').value, '140/90 mmHg');
});

test('empty denied and unavailable members never become a zero-valued summary', () => {
  for (const state of ['empty', 'unauthorized', 'unavailable']) {
    assert.deepEqual(careDaySummary(metric('heart', [record('a', 1, [field('心率', 80)])], state)), []);
  }
  assert.deepEqual(careDaySummary(metric('heart', [])), []);
  for (const key of ['ecg', 'body', 'blood']) {
    assert.deepEqual(careDaySummary(metric(key, [record('a', 1, [field('心率', 80)])])), [{ label: '记录数', value: '1 条' }]);
  }
});

test('page layout respects 320 through 840 widths and 100 through 200 percent system text', () => {
  for (const width of [320, 360, 390, 430, 600, 840]) {
    for (const scale of [1, 1.3, 1.5, 2]) {
      const layout = pageLayout(width, scale);
      assert.ok(layout.contentWidth <= 720);
      assert.equal(layout.singleColumn, width < 360 || scale > 1.3);
      assert.ok(controlHeight(44, scale) >= 48);
      assert.ok(controlHeight(56, scale) >= 24 * scale + 24);
    }
  }
  assert.equal(pageLayout(NaN, NaN).fontScale, 1);
});

test('complete ECG pagination exposes the tail and uses seconds only with a known sample rate', () => {
  assert.equal(waveformPageCount(2501), 3);
  assert.equal(waveformPageLabel(2501, 2, 250), '8–10 秒');
  assert.equal(waveformPageLabel(2501, 2, 0), '2001–2501 / 2501 个采样点');
  assert.equal(waveformPageLabel(2501, 99, 0), '2001–2501 / 2501 个采样点');
});

test('foreground notification arrival refreshes verified inbox state; a messages click opens the inbox', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  const arrived = source.slice(source.indexOf('private notificationArrived()'), source.indexOf('private wechatAuthChanged()'));
  assert.match(source, /@StorageLink\(NOTIFICATION_REVISION\)\s+@Watch\('notificationArrived'\)/);
  assert.match(arrived, /if \(this.guest \|\| this.restoring \|\| !careNotifications.isForeground\(\)\) return/);
  assert.match(arrived, /this.refreshInbox\(\)/);
  assert.match(arrived, /this.refreshCare\(\)/);
  assert.doesNotMatch(arrived, /this.screen\s*=|openCare\(|openMessages\(/);
  assert.match(source, /route === 'messages'\)\s*\{\s*await this.openMessages\(\)/);
});
