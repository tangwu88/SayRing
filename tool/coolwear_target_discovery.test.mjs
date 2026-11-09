import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';

const source = readFileSync(new URL('../android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java', import.meta.url), 'utf8');
function method(name) {
  const start = source.indexOf('    private void ' + name + '(');
  assert.notEqual(start, -1);
  let end = source.indexOf('{', start), depth = 0;
  for (; end < source.length; end++) {
    if (source[end] === '{') depth++;
    else if (source[end] === '}' && --depth === 0) return source.slice(start, end + 1);
  }
  throw new Error('Unclosed production method');
}

test('actual scan handler finishes exact recovery early without adopting same-name candidates', () => {
  const folder = mkdtempSync(join(tmpdir(), 'sayring-target-scan-'));
  let javaHome = process.env.JAVA_HOME;
  if (!javaHome && process.platform === 'darwin') javaHome = execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding:'utf8'}).trim();
  const java = name => javaHome ? join(javaHome, 'bin', name) : name;
  try {
    const file = join(folder, 'TargetScanTest.java');
    writeFileSync(file, `import java.util.*;
public class TargetScanTest {
  static class Result { int calls; List<?> value; void success(Object v) { calls++; value=(List<?>)v; } }
  static class MethodChannel { static class Result extends TargetScanTest.Result {} }
  static class Handler { void removeCallbacks(Runnable r) {} }
  static class Helper { int stops; void stopScan() { stops++; } }
  static class Device { String id; Device(String id) { this.id=id; } String getAddress() { return id; } }
  static class Manufacturer { String name; }
  static class MyBleDevice {
    String id,name; MyBleDevice(String i,String n) { id=i;name=n; }
    Device getmBluetoothDevice() { return new Device(id); }
    String getName() { return name; } int getRssi() { return -45; }
    Manufacturer getmK6ManufacturerInfo() { return null; }
  }
  MethodChannel.Result pendingScan; String scanExactTargetId; long scanGeneration;
  Runnable scanDeadline; Handler main=new Handler(); Helper helper=new Helper();
  Map<String,Map<String,Object>> scanned=new LinkedHashMap<>();
  String supportedModel(String n) { return n.startsWith("R7") ? n : null; }
  void emit(String type,Object value) {}
  static void profileTrace(String value) {}
${method('receiveScannedDevices')}
${method('finishScan')}
  static void check(boolean ok) { if (!ok) throw new AssertionError(); }
  public static void main(String[] args) {
    TargetScanTest t=new TargetScanTest();
    MethodChannel.Result r=new MethodChannel.Result(); t.pendingScan=r;
    t.scanExactTargetId="AA:BB:CC:DD:EE:FF";
    t.receiveScannedDevices(Arrays.asList(new MyBleDevice("11:22:33:44:55:66","R7 Pro")));
    check(r.calls==0 && t.pendingScan==r);
    t.receiveScannedDevices(Arrays.asList(new MyBleDevice("AA:BB:CC:DD:EE:FF","unknown")));
    check(r.calls==0);
    t.receiveScannedDevices(Arrays.asList(new MyBleDevice("AA:BB:CC:DD:EE:FF","R7 Pro")));
    check(r.calls==1 && t.pendingScan==null && t.scanExactTargetId==null && t.helper.stops==1);
    t.receiveScannedDevices(Arrays.asList(new MyBleDevice("AA:BB:CC:DD:EE:FF","R7 Pro")));
    check(r.calls==1);
    r=new MethodChannel.Result(); t.pendingScan=r;
    t.receiveScannedDevices(Arrays.asList(new MyBleDevice("AA:BB:CC:DD:EE:FF","R7 Pro")));
    check(r.calls==0); t.finishScan(); check(r.calls==1);
    t.scanned.clear(); r = new MethodChannel.Result(); t.pendingScan=r; t.scanExactTargetId="aa:bb:cc:dd:ee:ff";
    t.receiveScannedDevices(Arrays.asList(new MyBleDevice("AA:BB:CC:DD:EE:FF","R7 Pro")));
    check(r.calls==1 && t.scanned.containsKey("aa:bb:cc:dd:ee:ff"));
    System.out.println("exact match, wrong target, unsupported name, duplicate callback, normal scan passed");
  }
}`);
    execFileSync(java('javac'), ['-d', folder, file], {stdio:'pipe'});
    const output=execFileSync(java('java'), ['-cp',folder,'TargetScanTest'], {encoding:'utf8'});
    assert.match(output,/passed/);
  } finally { rmSync(folder,{recursive:true,force:true}); }
});

test('exact manual system lookup distinguishes current GATT, bond and stale candidates', () => {
  const folder = mkdtempSync(join(tmpdir(), 'sayring-system-target-'));
  let javaHome = process.env.JAVA_HOME;
  if (!javaHome && process.platform === 'darwin') javaHome = execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding:'utf8'}).trim();
  const java = name => javaHome ? join(javaHome, 'bin', name) : name;
  try {
    const names = ['isExactSystemTarget', 'matchingSystemTarget', 'findExactSystemTarget', 'currentConnectCandidate'];
    const bodies = names.map(name => {
      const pattern = new RegExp('^    (?:private |static )[^\\n]* ' + name + '\\(', 'm');
      const start = source.search(pattern);
      assert.notEqual(start, -1, name);
      let end = source.indexOf('{',start), depth=0;
      for (; end<source.length; end++) {
        if (source[end]==='{') depth++;
        else if (source[end]==='}' && --depth===0) return source.slice(start,end+1);
      }
      throw new Error(name);
    }).join('\n');
    const fixture = readFileSync(new URL('./fixtures/CoolWearSystemTargetTest.java', import.meta.url),'utf8');
    const file = join(folder, 'CoolWearSystemTargetTest.java');
    writeFileSync(file, fixture.replace('// PRODUCTION_METHODS', () => bodies));
    execFileSync(java('javac'), ['-d',folder,file], {stdio:'pipe'});
    execFileSync(java('java'), ['-cp',folder,'CoolWearSystemTargetTest'], {stdio:'pipe'});
  } finally { rmSync(folder,{recursive:true,force:true}); }
});
