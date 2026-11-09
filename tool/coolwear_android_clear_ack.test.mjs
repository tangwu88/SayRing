import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('history clear completes only for its current request, owner, target and real ACK',()=>{
  const bridge=read('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java');
  const methods=['onHistoryClearResult','finishHistoryClear'].map(name=>{
    const m=new RegExp('\\n    private [^\\n]+ '+name+'\\(').exec(bridge);assert.ok(m,name);
    let end=bridge.indexOf('{',m.index), depth=0;
    for(;end<bridge.length;end++){if(bridge[end]==='{')depth++;else if(bridge[end]==='}'&&--depth===0)return bridge.slice(m.index,end+1);}
    throw new Error('Unclosed production method');
  }).join('\n');
  const folder=mkdtempSync(join(tmpdir(),'sayring-clear-ack-'));
  const java=name=>process.env.JAVA_HOME?join(process.env.JAVA_HOME,'bin',name):name;
  try{
    const jar=join(folder,'classes.jar');
    writeFileSync(jar,execFileSync('unzip',['-p',fileURLToPath(new URL('../android/app/libs/coolwear_bluesdk-release.aar',import.meta.url)),'classes.jar'],{maxBuffer:16*1024*1024}));
    const helper=join(folder,'CoolWearClearAck.java');
    writeFileSync(helper,read('android/app/src/main/java/cc/saidian/saydian_app/CoolWearClearAck.java'));
    const file=join(folder,'ClearAckHarness.java');
    writeFileSync(file,`package cc.saidian.saydian_app;
import ce.com.cenewbluesdk.entity.CEDevData;
public final class ClearAckHarness {
  static final class MethodChannel { interface Result { void success(Object result); void error(String code,String message,Object details); } }
  static final class Reply implements MethodChannel.Result { int calls; Object value; String code;
    public void success(Object v){calls++;value=v;} public void error(String c,String m,Object d){calls++;code=c;} }
  static final class Main { void removeCallbacks(Runnable r){} }
  static final class Owner { long generation=3; boolean active=true; long generation(){return generation;} boolean isActive(){return active;} }
  static ClearAckHarness activeBridge;
  final Main main=new Main(); final Owner recoveryTarget=new Owner();
  boolean linkConnected=true,deviceInfoReceived=true;
  long connectionEpoch=7,clearOwnerGeneration=3; String connectedId="synthetic-r7";
  final Reply result=new Reply(); MethodChannel.Result pendingClear=result;
  CEDevData pendingClearCommand=CoolWearClearAck.request(); Runnable clearDeadline=()->{};
  static final class Tap { boolean closed; void close(){closed=true;} } Tap clearResultTap=new Tap();
  ClearAckHarness(){activeBridge=this;}
  ${methods}
  static int checks;
  static void check(boolean value){checks++;if(!value)throw new AssertionError("Clear ACK isolation "+checks);}
  void ack(CEDevData request,long epoch,String target,long owner,int status){
    onHistoryClearResult(epoch,target,owner,request,status);
  }
  void valid(){ack(pendingClearCommand,7,"synthetic-r7",3,1);}
  public static void main(String[] args){
    ClearAckHarness b=new ClearAckHarness();
    CEDevData original=b.pendingClearCommand;
    b.ack(original,6,b.connectedId,3,1);check(b.result.calls==0);
    b.ack(original,7,"other",3,1);check(b.result.calls==0);
    b.ack(original,7,b.connectedId,2,1);check(b.result.calls==0);
    b.recoveryTarget.generation=4;b.valid();check(b.result.calls==0);b.recoveryTarget.generation=3;
    b.recoveryTarget.active=false;b.valid();check(b.result.calls==0);b.recoveryTarget.active=true;
    b.linkConnected=false;b.valid();check(b.result.calls==0);b.linkConnected=true;
    b.deviceInfoReceived=false;b.valid();check(b.result.calls==0);b.deviceInfoReceived=true;
    activeBridge=null;b.valid();check(b.result.calls==0);activeBridge=b;
    b.ack(CoolWearClearAck.request(),7,b.connectedId,3,1);check(b.result.calls==0);
    for(int status:new int[]{-1,2,-101,207})b.ack(original,7,b.connectedId,3,status);
    check(b.result.calls==0);
    b.valid();check(b.result.calls==1&&"acknowledged".equals(b.result.value));check(b.pendingClear==null&&b.pendingClearCommand==null&&b.clearDeadline==null);
    b.ack(original,7,b.connectedId,3,1);check(b.result.calls==1);
    b=new ClearAckHarness();b.finishHistoryClear(false,null);check("requested".equals(b.result.value));b.valid();check(b.result.calls==1);
    b=new ClearAckHarness();b.finishHistoryClear(false,"CONNECTION_DROPPED");b.valid();check(b.result.calls==1&&"CONNECTION_DROPPED".equals(b.result.code));
    b=new ClearAckHarness();b.ack(b.pendingClearCommand,7,b.connectedId,3,0);check(b.result.calls==1&&b.result.value==null);
    System.out.println("Production clear acknowledgement isolation checks: "+checks);
  }
}`);
    execFileSync(java('javac'),['-encoding','UTF-8','-Xlint:all','-Werror','-cp',jar,'-d',folder,helper,file],{stdio:'pipe'});
    process.stdout.write(execFileSync(java('java'),['-cp',folder+(process.platform==='win32'?';':':')+jar,'cc.saidian.saydian_app.ClearAckHarness'],{encoding:'utf8'}));
  }finally{rmSync(folder,{recursive:true,force:true});}
});
