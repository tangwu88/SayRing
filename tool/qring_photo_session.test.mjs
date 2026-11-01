import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
test('native on-entry Photo UI preserves ACK, cancellation and current-session boundaries', {skip:process.platform!=='darwin'},()=>{
 const source=read('ios/Runner/QRingWearableBridge.m');
 const signatures=['- (BOOL)canOpenRemoteCamera {','- (BOOL)supportsGesture {','- (BOOL)cameraFlag:', '- (void)registerRemoteCameraCallbacks {','- (void)resetRemoteCamera {','- (void)cameraShutter:', '- (void)cameraStopped:', '- (void)scheduleCameraKeepAlive:', '- (void)remoteCameraAction:', '- (void)finishCamera:'];
 const methods=signatures.map(signature=>{const start=source.indexOf(signature);assert.ok(start>=0,signature);return source.slice(start,source.indexOf('\n- (',start+1));}).join('\n');
 const folder=mkdtempSync(join(tmpdir(),'sayring-photo-session-'));
 try{
  const src=join(folder,'session.m'),exe=join(folder,'session');
  const run=body=>{writeFileSync(src,read('tool/fixtures/qring_photo_session.m').replace('// PRODUCTION_METHODS',body));execFileSync('xcrun',['clang','-fobjc-arc','-Wall','-Wextra','-Werror','-framework','Foundation',src,'-o',exe],{stdio:'pipe'});return spawnSync(exe,[],{encoding:'utf8'});};
  const result=run(methods);assert.equal(result.status,0,result.stderr);process.stdout.write(result.stdout);
  const regression=methods.replace('if (entering && epoch != weakSelf.remoteCameraEpoch)', 'if (NO && entering && epoch != weakSelf.remoteCameraEpoch)');
  assert.notEqual(regression,methods);const bad=run(regression);assert.equal(bad.status,1);assert.match(bad.stderr,/Photo session assertion failed/);
 }finally{rmSync(folder,{recursive:true,force:true});}
});
