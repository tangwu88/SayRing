import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join,resolve,delimiter} from 'node:path';

test('actual bundled SDK retains parsers, excludes ACKs and exposes complete empty history',()=>{
 const dir=mkdtempSync(join(tmpdir(),'sayring-history-sdk-'));
 const java=bin=>process.env.JAVA_HOME?join(process.env.JAVA_HOME,'bin',bin):bin;
 try{
  execFileSync(java('jar'),['xf',resolve('android/app/libs/coolwear_bluesdk-release.aar'),'classes.jar'],{cwd:dir});
  execFileSync(java('javac'),['-Xlint:all','-Werror','-cp',join(dir,'classes.jar'),'-d',dir,
   resolve('android/app/src/main/java/ce/com/cenewbluesdk/proxy/k6AnalysisDevData/AnalysisReceiveDataHelper/BlueProcessBean/SayRingHistoryObserver.java'),
   resolve('android/app/src/main/java/cc/saidian/saydian_app/CoolWearHistoryBatch.java'),
   resolve('tool/fixtures/CoolWearHistorySdkTest.java')]);
  const output=execFileSync(java('java'),['-ea','-cp',[dir,join(dir,'classes.jar'),join(process.env.ANDROID_HOME,'platforms','android-36','android.jar')].join(delimiter),'cc.saidian.saydian_app.CoolWearHistorySdkTest'],{encoding:'utf8'});
  assert.match(output,/Actual bundled history SDK PASS/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
