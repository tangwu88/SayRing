import test from 'node:test';
import assert from 'node:assert/strict';
import { alarmDraftError, alarmRepeatText, copyWatchAlarm, deleteWatchAlarm, nextWatchAlarmId,
  newWatchAlarm, emptyWatchUnits, readWatchAlarms, readWatchUnits, saveWatchAlarm, saveWatchUnit } from '../entry/src/main/ets/model/DeviceSettingsTransactions.ts';
import { refreshSummaryOnSettingsReturn } from '../entry/src/main/ets/model/DeviceSettingsTransactions.ts';

const current = () => {};
const alarm = (id, changes = {}) => ({ ...newWatchAlarm(), id, ...changes });
const units = (changes = {}) => ({ ...emptyWatchUnits(), unitSystem: 1, tempUnit: 1, timeFormat: 1, ...changes });
class Port {
  calls = [];
  units = units();
  alarms = [alarm(1)];
  writeSuccess = true;
  ignoreWrite = false;
  async readUnits() { this.calls.push('readUnits'); return { success: true, data: { ...this.units } }; }
  async writeUnits(config) {
    this.calls.push('writeUnits');
    if (this.writeSuccess && !this.ignoreWrite) this.units = { ...config };
    return { success: this.writeSuccess };
  }
  async readAlarms() { this.calls.push('readAlarms'); return { success: true, data: this.alarms.map(copyWatchAlarm) }; }
  async writeAlarm(item) {
    this.calls.push(`alarm:${item.id}`);
    if (this.writeSuccess && !this.ignoreWrite) this.alarms = [...this.alarms.filter(a => a.id !== item.id), copyWatchAlarm(item)];
    return { success: this.writeSuccess };
  }
  async deleteAlarm(id) {
    this.calls.push(`delete:${id}`);
    if (this.writeSuccess && !this.ignoreWrite) this.alarms = this.alarms.filter(a => a.id !== id);
    return { success: this.writeSuccess };
  }
}

test('unit write changes one field and succeeds only after an equal readback', async () => {
  const port = new Port();
  assert.deepEqual(await saveWatchUnit(port, current, 'unitSystem', 2, 1), units({ unitSystem: 2 }));
  assert.deepEqual(port.calls, ['readUnits', 'writeUnits', 'readUnits']);
  port.calls = [];
  assert.deepEqual(await saveWatchUnit(port, current, 'tempUnit', 2, 1), units({ unitSystem: 2, tempUnit: 2 }));
});
test('every non-target setting must survive the complete readback, not only time format', async () => {
  for (const field of Object.keys(units()).filter(field => field !== 'unitSystem')) {
    const port = new Port();
    port.writeUnits = async config => {
      port.units = { ...config, [field]: config[field] === 1 ? 2 : 1 };
      return { success: true };
    };
    await assert.rejects(saveWatchUnit(port, current, 'unitSystem', 2, 1), /其他设置/, field);
  }
});
test('incomplete configuration cannot be defaulted into a full device write', async () => {
  for (const field of Object.keys(units())) {
    const port = new Port(); delete port.units[field];
    await assert.rejects(saveWatchUnit(port, current, 'unitSystem', 2, 1), /不完整/, field);
    assert.deepEqual(port.calls, ['readUnits']);
  }
  const port = new Port(); port.units.ledLevel = 255;
  assert.equal((await saveWatchUnit(port, current, 'unitSystem', 2, 1)).ledLevel, 255);
});
test('time format can be restored independently without touching units or health switches', async () => {
  const port = new Port(); port.units = units({ timeFormat: 2, heartRateAutoDetect: 1, tempUnit: 2 });
  const original = { ...port.units };
  assert.deepEqual(await saveWatchUnit(port, current, 'timeFormat', 1, 2), { ...original, timeFormat: 1 });
});
test('unsupported, invalid and stale unit choices do not write', async () => {
  const port = new Port(); port.units.tempUnit = 0;
  await assert.rejects(saveWatchUnit(port, current, 'tempUnit', 2, 1), /不支持/);
  await assert.rejects(saveWatchUnit(port, current, 'unitSystem', 0, 1), /无效/);
  await assert.rejects(saveWatchUnit(port, current, 'heartRateAutoDetect', 2, 1), /无效/);
  await assert.rejects(saveWatchUnit(port, current, 'unitSystem', 2, 2), /已变化/);
  assert.ok(port.calls.every(call => call === 'readUnits'));
});
test('ACK success without matching unit readback is never save success', async () => {
  const port = new Port(); port.ignoreWrite = true;
  await assert.rejects(saveWatchUnit(port, current, 'unitSystem', 2, 1), /未确认/);
  port.ignoreWrite = false; port.writeSuccess = false;
  await assert.rejects(saveWatchUnit(port, current, 'unitSystem', 2, 1), /保存失败/);
});
test('read errors and missing data are not an empty list or default units', async () => {
  const port = new Port();
  port.readUnits = async () => ({ success: false });
  await assert.rejects(readWatchUnits(port, current), /无法读取/);
  port.readAlarms = async () => ({ success: true });
  await assert.rejects(readWatchAlarms(port, current), /未返回/);
  port.readAlarms = async () => ({ success: true, data: [] });
  assert.deepEqual(await readWatchAlarms(port, current), []);
});
test('alarm label is capped by UTF-8 bytes, and all seven repeat days survive copying', () => {
  assert.equal(alarmDraftError(alarm(-1, { label: '一二三四五六七' })), '');
  assert.match(alarmDraftError(alarm(-1, { label: '一二三四五六七八' })), /过长/);
  assert.match(alarmDraftError(alarm(-1, { label: '😀'.repeat(6) })), /过长/);
  assert.match(alarmDraftError(alarm(-1, { time: '24:00' })), /有效时间/);
  assert.match(alarmDraftError(alarm(-1, { label: '提醒\n名称' })), /控制字符/);
  const value = alarm(1, { days: [true, false, true, false, true, false, true] });
  const copied = copyWatchAlarm(value); copied.days[0] = false;
  assert.equal(value.days[0], true);
  assert.equal(alarmRepeatText(value.days), '周一、周三、周五、周日');
  assert.equal(alarmRepeatText([false, false, false, false, false, false, false]), '仅一次');
});
test('new alarm ID never overwrites an existing 255; a full ID space rejects', async () => {
  const port = new Port(); port.alarms = [alarm(255), alarm(1)];
  const original = port.alarms.map(copyWatchAlarm);
  const result = await saveWatchAlarm(port, current, newWatchAlarm());
  assert.equal(nextWatchAlarmId(original), 2);
  assert.deepEqual(result.filter(a => a.id !== 2), original);
  assert.throws(() => nextWatchAlarmId(Array.from({ length: 255 }, (_, i) => alarm(i + 1))), /上限/);
});
test('alarm edit and toggle preserve untouched fields and read back the full device list', async () => {
  const port = new Port(); const expected = copyWatchAlarm(port.alarms[0]);
  const result = await saveWatchAlarm(port, current, { ...expected, enabled: false }, expected);
  assert.deepEqual(result[0], { ...expected, enabled: false });
  assert.deepEqual(port.calls, ['readAlarms', 'alarm:1', 'readAlarms']);
});
test('stale and missing alarms cannot be overwritten or deleted from an old page', async () => {
  const port = new Port(); const expected = copyWatchAlarm(port.alarms[0]);
  port.alarms[0].time = '09:00';
  await assert.rejects(saveWatchAlarm(port, current, { ...expected, enabled: false }, expected), /已变化/);
  await assert.rejects(deleteWatchAlarm(port, current, expected), /已变化/);
  assert.ok(port.calls.every(call => call === 'readAlarms'));
});
test('alarm ACK mismatch, malformed duplicates and unexpected removal of other alarms fail closed', async () => {
  const port = new Port(); port.ignoreWrite = true;
  await assert.rejects(saveWatchAlarm(port, current, newWatchAlarm()), /未确认/);
  await assert.rejects(deleteWatchAlarm(port, current, port.alarms[0]), /未确认/);
  port.alarms.push(copyWatchAlarm(port.alarms[0]));
  await assert.rejects(readWatchAlarms(port, current), /无法识别/);
  port.alarms = [alarm(1), alarm(2)];
  port.writeAlarm = async item => { port.alarms = [item]; return { success: true }; };
  await assert.rejects(saveWatchAlarm(port, current, newWatchAlarm()), /未确认/);
});
test('confirmed alarm deletion succeeds only when absent in readback', async () => {
  const port = new Port();
  assert.deepEqual(await deleteWatchAlarm(port, current, port.alarms[0]), []);
  assert.deepEqual(port.calls, ['readAlarms', 'delete:1', 'readAlarms']);
});
test('connection change after a read forbids later writes on the new watch', async () => {
  const port = new Port(); let live = true;
  const check = () => { if (!live) throw new Error('连接已变化'); };
  const oldRead = port.readUnits.bind(port);
  port.readUnits = async () => { const result = await oldRead(); live = false; return result; };
  await assert.rejects(saveWatchUnit(port, check, 'unitSystem', 2, 1), /连接已变化/);
  assert.deepEqual(port.calls, ['readUnits']);
  live = true;
  const oldAlarms = port.readAlarms.bind(port);
  port.readAlarms = async () => { const result = await oldAlarms(); live = false; return result; };
  await assert.rejects(saveWatchAlarm(port, check, newWatchAlarm()), /连接已变化/);
  assert.deepEqual(port.calls, ['readUnits', 'readAlarms']);
});

test('draft edits during an awaited read cannot alter an already submitted alarm', async () => {
  const port = new Port(); const draft = newWatchAlarm();
  const originalRead = port.readAlarms.bind(port);
  let first = true;
  port.readAlarms = async () => {
    const result = await originalRead();
    if (first) { first = false; draft.time = '23:59'; draft.days[0] = false; }
    return result;
  };
  const result = await saveWatchAlarm(port, current, draft);
  assert.equal(result.find(item => item.id === 2).time, '08:00');
  assert.equal(result.find(item => item.id === 2).days[0], true);
});

test('return from a changed unit or alarm rereads the parent summary instead of reusing its old snapshot', async () => {
  const port = new Port();
  let summary = await port.readUnits();
  await saveWatchUnit(port, current, 'unitSystem', 2, 1);
  assert.equal(summary.data.unitSystem, 1, 'old parent snapshot reproduces the issue');
  const refreshed = await refreshSummaryOnSettingsReturn('device-units', 'device-settings', async () => {
    summary = await port.readUnits(); return summary.success;
  });
  assert.equal(refreshed, true);
  assert.equal(summary.data.unitSystem, 2);
  let parentAlarms = await port.readAlarms();
  await saveWatchAlarm(port, current, newWatchAlarm());
  await refreshSummaryOnSettingsReturn('device-alarms', 'device-settings', async () => {
    parentAlarms = await port.readAlarms(); return parentAlarms.success;
  });
  assert.equal(parentAlarms.data.length, 2);
});

test('parent refresh failure stays unavailable and unrelated back paths do not issue SDK reads', async () => {
  assert.equal(await refreshSummaryOnSettingsReturn('device-units', 'device-settings', async () => false), false);
  let called = false;
  const refresh = async () => { called = true; return true; };
  assert.equal(await refreshSummaryOnSettingsReturn('device-alarm-edit', 'device-alarms', refresh), undefined);
  assert.equal(await refreshSummaryOnSettingsReturn('care', 'home', refresh), undefined);
  assert.equal(called, false);
});
