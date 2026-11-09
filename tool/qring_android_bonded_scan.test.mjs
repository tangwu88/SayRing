import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');

test('Android scan publishes bonded rings without advertisements, preserving real scan data', () => {
  const source = read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  const methods = ['readBondedDevices', 'publishBondedScanCandidates'].map(name => {
    const match = new RegExp('\\n    private [^\\n]+ ' + name + '\\(').exec(source);
    assert.ok(match, name);
    const start = match.index;
    const next = /\n    (?:private|public|protected) /.exec(source.slice(start + 1));
    return source.slice(start, next ? start + 1 + next.index : source.length);
  }).join('\n');
  const folder = mkdtempSync(join(tmpdir(), 'sayring-bonded-scan-'));
  const tool = name => process.env.JAVA_HOME ? join(process.env.JAVA_HOME, 'bin', name) : name;
  try {
    writeFileSync(join(folder, 'RingNamePolicy.java'), read('android/app/src/main/java/cc/saidian/saydian_app/RingNamePolicy.java'));
    writeFileSync(join(folder, 'BondedScanHarness.java'), `package cc.saidian.saydian_app;
import java.util.*;
public final class BondedScanHarness {
  static final class Context { static final String BLUETOOTH_SERVICE="bluetooth"; }
  record BluetoothDevice(String address, String name) {
    String getAddress() { return address; } String getName() { return name; }
  }
  static final class Adapter {
    boolean denied;
    final Set<BluetoothDevice> devices=new LinkedHashSet<>();
    Set<BluetoothDevice> getBondedDevices() { if(denied) throw new SecurityException(); return devices; }
  }
  static final class BluetoothManager { final Adapter adapter=new Adapter(); Adapter getAdapter(){return adapter;} }
  static final class Activity {
    BluetoothManager bluetooth=new BluetoothManager(); Object getSystemService(String ignored){return bluetooth;}
  }
  final Activity activity=new Activity();
  final Map<String,Map<String,Object>> scanned=new HashMap<>();
  final List<Map<String,Object>> events=new ArrayList<>();
  Object pendingScan=new Object();
  boolean isQRingName(String name){return RingNamePolicy.isQRingName(name);}
  void emit(String type, Map<String,Object> value){check(type.equals("scanDevice")); events.add(value);}
  static void check(boolean value){if(!value) throw new AssertionError("Bonded scan regression");}
  ${methods}
  public static void main(String[] args){
    BondedScanHarness b=new BondedScanHarness();
    b.activity.bluetooth.adapter.devices.add(new BluetoothDevice("synthetic-r8","SD_RING_R8"));
    b.activity.bluetooth.adapter.devices.add(new BluetoothDevice("synthetic-r22","R22_Test"));
    b.activity.bluetooth.adapter.devices.add(new BluetoothDevice("synthetic-watch","HR05"));
    b.activity.bluetooth.adapter.devices.add(new BluetoothDevice("synthetic-unknown",null));
    Map<String,Object> live=new HashMap<>(); live.put("id","synthetic-r22"); live.put("rssi",-45);
    b.scanned.put("synthetic-r22",live);
    b.publishBondedScanCandidates();
    check(b.events.size()==1 && b.events.get(0).get("id").equals("synthetic-r8"));
    check(Boolean.TRUE.equals(b.events.get(0).get("bonded")));
    check(!b.events.get(0).containsKey("rssi"));
    check(b.scanned.size()==2 && b.scanned.get("synthetic-r22")==live);
    b.publishBondedScanCandidates(); check(b.events.size()==1);
    b.scanned.clear(); b.pendingScan=null; b.publishBondedScanCandidates(); check(b.scanned.isEmpty());
    b.pendingScan=new Object(); b.activity.bluetooth.adapter.denied=true;
    b.publishBondedScanCandidates(); check(b.scanned.isEmpty());
    b.activity.bluetooth=null; b.publishBondedScanCandidates(); check(b.scanned.isEmpty());
    System.out.println("Bonded scan: no broadcast, duplicate, live RSSI, provider filter, permission and stopped scan passed");
  }
}`);
    execFileSync(tool('javac'), ['-Xlint:all', '-Werror', '-d', folder, join(folder,'RingNamePolicy.java'),join(folder,'BondedScanHarness.java')], {stdio:'pipe'});
    process.stdout.write(execFileSync(tool('java'), ['-cp',folder,'cc.saidian.saydian_app.BondedScanHarness'], {encoding:'utf8'}));
    // Ensure the production scanner, rather than only the test harness, uses the merge.
    assert.match(source.slice(source.indexOf('private void startScan('),source.indexOf('private void publishBondedScanCandidates(')), /publishBondedScanCandidates\(\);/);
  } finally { rmSync(folder,{recursive:true,force:true}); }
});
