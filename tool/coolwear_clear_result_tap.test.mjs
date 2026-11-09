import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('fixed SDK reports cmd1 only after ACK, and temporary tap preserves/restores its original dispatcher',()=>{
 const dir=mkdtempSync(join(tmpdir(),'sayring-clear-result-'));
 const java=name=>process.env.JAVA_HOME?join(process.env.JAVA_HOME,'bin',name):name;
 try{
  const jar=join(dir,'classes.jar');writeFileSync(jar,execFileSync('unzip',['-p',fileURLToPath(new URL('../android/app/libs/coolwear_bluesdk-release.aar',import.meta.url)),'classes.jar'],{maxBuffer:16*1024*1024}));
  const bytecode=execFileSync(java('javap'),['-c','-p','-classpath',jar,'ce.com.cenewbluesdk.proxy.CEDevQueue'],{encoding:'utf8',maxBuffer:1024*1024});
  const transport=bytecode.split('public void dataSendSucceed(byte[]);')[1].split('public synchronized void dataSendFailed')[0];
  assert.ok(transport);assert.doesNotMatch(transport,/CEBluetoothProxyBase\.dataSendSucceed/);
  const ack=bytecode.split('public void blueToothReceiptData(byte[]);')[1].split('public void dataSendSucceed(byte[]);')[0];
  assert.match(ack,/bipush\s+-101/);assert.match(ack,/CEBluetoothProxyBase\.dataSendSucceed/);
  const files={
   'CEBluetoothProxyBase.java':`package ce.com.cenewbluesdk.proxy; public class CEBluetoothProxyBase {}`,
   'CEDevK6Proxy.java':`package ce.com.cenewbluesdk.proxy; import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.SendDataHelper.K6SendDataManager; public final class CEDevK6Proxy extends CEBluetoothProxyBase { K6SendDataManager mIK6SendDataManager; }`,
   'K6BleDataResult.java':`package ce.com.cenewbluesdk.proxy.interfaces; public interface K6BleDataResult<T> { boolean bleDataResult(T value); }`,
   'K6SendDataManager.java':`package ce.com.cenewbluesdk.proxy.k6AnalysisDevData.SendDataHelper; import ce.com.cenewbluesdk.proxy.CEDevK6Proxy; import ce.com.cenewbluesdk.proxy.interfaces.K6BleDataResult;
     public class K6SendDataManager {public int calls,registrations,volume; public K6SendDataManager(CEDevK6Proxy p){} public void processResult(int t,int s){calls++;} public void addSendDataResultListener(String t,K6BleDataResult<Integer> r){registrations++;} public void setVolume(int v){volume=v;} }`,
   'SayRingClearResultTap.java':read('android/app/src/main/java/ce/com/cenewbluesdk/proxy/SayRingClearResultTap.java'),
   'TapHarness.java':`package ce.com.cenewbluesdk.proxy; import ce.com.cenewbluesdk.proxy.k6AnalysisDevData.SendDataHelper.K6SendDataManager;
     public final class TapHarness {static int checks; static void check(boolean b){checks++;if(!b)throw new AssertionError("Result tap "+checks);}
      public static void main(String[] args){
       CEDevK6Proxy p=new CEDevK6Proxy();K6SendDataManager original=new K6SendDataManager(p);p.mIK6SendDataManager=original;
       int[] results={0};SayRingClearResultTap tap=SayRingClearResultTap.install(p,s->results[0]+=s);check(p.mIK6SendDataManager==tap);
       tap.addSendDataResultListener("existing",v->false);check(original.registrations==1);
       tap.processResult(8,1);check(results[0]==0&&original.calls==1);
       tap.processResult(207,1);check(results[0]==1&&original.calls==2);
       tap.setVolume(4);check(original.volume==4);
       check(SayRingClearResultTap.install(p,s->{})==null);
       tap.close();check(p.mIK6SendDataManager==original);tap.processResult(207,1);check(results[0]==1&&original.calls==3);
       tap.close();check(p.mIK6SendDataManager==original);
       tap=SayRingClearResultTap.install(p,s->{throw new IllegalStateException("test");});tap.processResult(207,1);check(original.calls==4);
       K6SendDataManager next=new K6SendDataManager(p);p.mIK6SendDataManager=next;tap.close();check(p.mIK6SendDataManager==next);
       check(SayRingClearResultTap.install(new CEBluetoothProxyBase(),s->{})==null);
       System.out.println("SDK cmd1 ACK path verified; production result tap checks: "+checks);
      }} `
  };
  for(const[name,content]of Object.entries(files))writeFileSync(join(dir,name),content);
  execFileSync(java('javac'),['-encoding','UTF-8','-Xlint:all','-Werror','-d',dir,...Object.keys(files).map(f=>join(dir,f))],{stdio:'pipe'});
  process.stdout.write(execFileSync(java('java'),['-cp',dir,'ce.com.cenewbluesdk.proxy.TapHarness'],{encoding:'utf8'}));
 }finally{rmSync(dir,{recursive:true,force:true});}
});
