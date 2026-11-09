import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
function method(source,name){
  const match=new RegExp('\\n    private [^\\n]+ '+name+'\\(').exec(source);assert.ok(match,name);
  const start=source.indexOf('{',match.index);let depth=0;
  for(let end=start;end<source.length;end++){
    if(source[end]==='{')depth++;
    if(source[end]==='}'&&--depth===0)return source.slice(match.index,end+1);
  }
  throw new Error('Method not closed');
}
test('a matching physical reset write requests a fresh handshake but never confirms reset or unlocks imports',()=>{
  const source=read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  const methods=method(source,'onFactoryResetWrite')+method(source,'factoryInitializationKey')+method(source,'currentReadScope')+method(source,'initializationHandshakeReady');
  const folder=mkdtempSync(join(tmpdir(),'sayring-noack-write-'));
  const java=n=>process.env.JAVA_HOME?join(process.env.JAVA_HOME,'bin',n):n;
  try{
    const src=join(folder,'NoAckWriteHarness.java');
    writeFileSync(src,`package cc.saidian.saydian_app;
import java.util.*;
public final class NoAckWriteHarness {
 static final class Constants{static final UUID UUID_WRITE=UUID.fromString("00000000-0000-0000-0000-000000000001");}
 static final class BleAction{static final String EXTRA_CHARACTER_UUID="uuid",EXTRA_DATA="data",EXTRA_STATUS="status";}
 static final class BluetoothGatt{static final int GATT_SUCCESS=0;}
 static final class Context{static final int MODE_PRIVATE=0;}
 static final class Intent{String uuid=Constants.UUID_WRITE.toString();byte[] data={1,2};int status;
   String getStringExtra(String k){return uuid;}byte[] getByteArrayExtra(String k){return data;}int getIntExtra(String k,int d){return status;}}
 static final class Prefs{String token="request";String getString(String k,String d){return token;}}
 static final class Activity{final Prefs p=new Prefs();Prefs getSharedPreferences(String n,int m){return p;}}
 static final class ResetWrite{int generation=4;String id="ring",context="realm:owner",token="request";byte[] frame={1,2};}
 final Activity activity=new Activity();ResetWrite pendingResetWrite=new ResetWrite();Integer factoryWriteConfirmedGeneration;
 int generation=4,emits,phase=1;String id="ring",context="realm:owner";
 boolean currentFactoryTarget(int g,String i,String c){return g==generation&&i.equals(id)&&c.equals(context);}
 boolean isCurrentConnection(int g,String i){return g==generation&&i!=null&&i.equals(id);}
 String recoveryContext="realm:owner";
 static final class Manager{boolean connected=true;boolean isConnected(){return connected;}}
 Manager manager=new Manager();Object setTimeFlags=new Object(),supportFlags=new Object();boolean cancellingConnection;
 boolean hasBlePermissions(){return true;}boolean isBluetoothEnabled(){return true;}
 void emitFactoryInitialization(){emits++;}
 ${methods}
 static int checks;static void check(boolean b){if(!b)throw new AssertionError("No-ACK write isolation "+checks);checks++;}
 public static void main(String[] args){
   NoAckWriteHarness h=new NoAckWriteHarness();h.onFactoryResetWrite(new Intent());
   check(h.emits==1&&h.factoryWriteConfirmedGeneration==4&&h.phase==1&&h.pendingResetWrite==null);
   h.onFactoryResetWrite(new Intent());check(h.emits==1);
   for(int mutation=0;mutation<6;mutation++){
     h=new NoAckWriteHarness();Intent i=new Intent();
     switch(mutation){case 0:h.generation++;break;case 1:h.id="other";break;case 2:h.context="realm:other";break;
       case 3:i.uuid="other";break;case 4:i.data=new byte[]{3,4};break;case 5:i.status=133;break;default:break;}
     h.onFactoryResetWrite(i);check(h.emits==0&&h.factoryWriteConfirmedGeneration==null&&h.phase==1);
   }
   h=new NoAckWriteHarness();h.activity.p.token="retired";h.onFactoryResetWrite(new Intent());
   check(h.emits==0&&h.phase==1&&h.factoryWriteConfirmedGeneration==null);
   h=new NoAckWriteHarness();check(h.currentReadScope(4,"ring","realm:owner"));
   check(!h.currentReadScope(4,"ring","realm:other"));check(!h.currentReadScope(5,"ring","realm:owner"));
   h.recoveryContext=null;check(h.currentReadScope(4,"ring",null));
   check(!h.currentReadScope(4,"ring","realm:owner"));
   h=new NoAckWriteHarness();check(h.initializationHandshakeReady());
   h.manager.connected=false;check(!h.initializationHandshakeReady());h.manager.connected=true;
   h.setTimeFlags=null;check(!h.initializationHandshakeReady());h.setTimeFlags=new Object();
   h.supportFlags=null;check(!h.initializationHandshakeReady());h.supportFlags=new Object();
   h.cancellingConnection=true;check(!h.initializationHandshakeReady());
   System.out.println("Production NO_ACK physical-write assertions: "+checks);
 }
}`);
    execFileSync(java('javac'),['-encoding','UTF-8','-Xlint:all','-Werror','-d',folder,src],{stdio:'pipe'});
    process.stdout.write(execFileSync(java('java'),['-cp',folder,'cc.saidian.saydian_app.NoAckWriteHarness'],{encoding:'utf8'}));
    assert.match(source,/onFactoryResetWrite\(intent\)/);
    assert.match(source,/healthRecordAllowed\(record, factorySyncNotBefore\(\)\)/);
    assert.match(source,/sleepTimelineAllowed\(timeline, factorySyncNotBefore\(\)\)/);
    assert.match(source,/sportRecordAllowed\(record, factorySyncNotBefore\(\)\)/);
  }finally{rmSync(folder,{recursive:true,force:true});}
});
