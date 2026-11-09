import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('real reset ACK survives old-link retirement but never initializes a different owner or target',()=>{
  const source=read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  const methods=['factoryInitializationKey','beginFactoryResetRequest','recordFactoryResetAck','acceptFactoryResetAck'].map(name=>{
    const m=new RegExp('\\n    private [^\\n]+ '+name+'\\(').exec(source);assert.ok(m,name);
    let end=source.indexOf('{',m.index),depth=0;
    for(;end<source.length;end++){if(source[end]==='{')depth++;else if(source[end]==='}'&&--depth===0)return source.slice(m.index,end+1);}
    throw new Error('Unclosed production method');
  }).join('\n');
  const folder=mkdtempSync(join(tmpdir(),'sayring-reset-receipt-'));
  const java=name=>process.env.JAVA_HOME?join(process.env.JAVA_HOME,'bin',name):name;
  try{
    const file=join(folder,'FactoryReceiptHarness.java');
    writeFileSync(file,`package cc.saidian.saydian_app;
import java.util.*;
public final class FactoryReceiptHarness {
  static final class Context{static final int MODE_PRIVATE=0;}
  static final class Prefs {
    final Map<String,Object> values=new HashMap<>(); boolean fail;
    int getInt(String key,int fallback){Object v=values.get(key);return v==null?fallback:(Integer)v;}
    String getString(String key,String fallback){Object v=values.get(key);return v==null?fallback:(String)v;}
    Editor edit(){return new Editor();}
    final class Editor {
      final Map<String,Object> staged=new HashMap<>();
      Editor putInt(String k,int v){staged.put(k,v);return this;}
      Editor putString(String k,String v){staged.put(k,v);return this;}
      boolean commit(){if(fail)return false;values.putAll(staged);return true;}
    }
  }
  static final class Activity{final Prefs prefs=new Prefs();Prefs getSharedPreferences(String name,int mode){return prefs;}}
  static final class Handler{void postDelayed(Runnable action,long delay){}}
  static final class BaseRspCmd{static final int RESULT_OK=0;final int status;BaseRspCmd(int s){status=s;}int getStatus(){return status;}}
  final Activity activity=new Activity();final Handler main=new Handler();
  String connectedId="synthetic-r8",recoveryContext="realm:owner-A";
  Map<String,Object> pendingProfile,recoveryProfile=Map.of("targetSteps",9000);
  int connectionGeneration=8,profileWrites,emits;boolean live=true;Integer factoryInitializingGeneration;
  boolean resolved(){return live;}
  boolean currentFactoryTarget(int g,String id,String owner){return g==connectionGeneration&&id.equals(connectedId)&&owner.equals(recoveryContext);}
  void emit(String name,Map<String,Object> value){emits++;}void emitFactoryInitialization(){emits++;}
  Map<String,Object> capabilities(){return Map.of();}
  void writeProfileWithCompletion(Runnable finish){profileWrites++;finish.run();}
  ${methods}
  int phase(String id,String owner){return activity.prefs.getInt(factoryInitializationKey(id,owner),0);}
  String start(){return beginFactoryResetRequest("synthetic-r8","realm:owner-A");}
  void ack(String token){acceptFactoryResetAck(8,"synthetic-r8","realm:owner-A",token,new BaseRspCmd(0));}
  static int checks;static void check(boolean ok){checks++;if(!ok)throw new AssertionError("Factory receipt isolation "+checks);}
  public static void main(String[] args){
    FactoryReceiptHarness b=new FactoryReceiptHarness();String token=b.start();check(token!=null&&b.phase(b.connectedId,b.recoveryContext)==1);
    b.connectionGeneration=9;b.connectedId=null;b.live=false;b.ack(token);
    check(b.phase("synthetic-r8","realm:owner-A")==3&&b.profileWrites==0&&b.emits==0);
    b=new FactoryReceiptHarness();token=b.start();b.connectionGeneration=9;b.recoveryContext="realm:owner-B";b.ack(token);
    check(b.phase("synthetic-r8","realm:owner-A")==3&&b.phase("synthetic-r8","realm:owner-B")==0&&b.profileWrites==0&&b.emits==0);
    b=new FactoryReceiptHarness();token=b.start();b.connectionGeneration=9;b.connectedId="other-ring";b.ack(token);
    check(b.phase("synthetic-r8","realm:owner-A")==3&&b.phase("other-ring","realm:owner-A")==0&&b.profileWrites==0);
    b=new FactoryReceiptHarness();token=b.start();b.ack("wrong-request");check(b.phase(b.connectedId,b.recoveryContext)==1&&b.emits==0);
    b.acceptFactoryResetAck(8,b.connectedId,b.recoveryContext,token,new BaseRspCmd(1));check(b.phase(b.connectedId,b.recoveryContext)==1);
    b.acceptFactoryResetAck(8,b.connectedId,b.recoveryContext,token,null);check(b.phase(b.connectedId,b.recoveryContext)==1);
    b.ack(token);check(b.phase(b.connectedId,b.recoveryContext)==3&&b.profileWrites==0&&b.emits==2);
    b.ack(token);check(b.emits==2&&b.profileWrites==0);
    b=new FactoryReceiptHarness();token=b.start();b.connectionGeneration=10;b.ack(token);
    check(b.phase(b.connectedId,b.recoveryContext)==3&&b.profileWrites==1&&b.factoryInitializingGeneration==null&&b.emits==2);
    b.ack(token);check(b.profileWrites==1);
    b=new FactoryReceiptHarness();token=b.start();b.activity.prefs.fail=true;b.ack(token);check(b.phase(b.connectedId,b.recoveryContext)==1&&b.emits==0);
    b=new FactoryReceiptHarness();b.activity.prefs.fail=true;check(b.start()==null&&b.activity.prefs.values.isEmpty());
    b=new FactoryReceiptHarness();b.activity.prefs.values.put(b.factoryInitializationKey(b.connectedId,b.recoveryContext),1);b.ack("invented");check(b.phase(b.connectedId,b.recoveryContext)==1&&b.profileWrites==0);
    b=new FactoryReceiptHarness();token=b.start();b.activity.prefs.values.put(b.factoryInitializationKey(b.connectedId,b.recoveryContext)+".request",123);b.ack(token);check(b.phase(b.connectedId,b.recoveryContext)==1);
    System.out.println("Production factory receipt checks: "+checks);
  }
}`);
    execFileSync(java('javac'),['-encoding','UTF-8','-Xlint:all','-Werror','-d',folder,file],{stdio:'pipe'});
    process.stdout.write(execFileSync(java('java'),['-cp',folder,'cc.saidian.saydian_app.FactoryReceiptHarness'],{encoding:'utf8'}));
    assert.match(source,/acceptFactoryResetAck\(generation, id, context, requestToken, ack\)/);
  }finally{rmSync(folder,{recursive:true,force:true});}
});
