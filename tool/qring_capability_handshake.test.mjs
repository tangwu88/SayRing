import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
test('actual reconnect handshake rereads partial SDK capabilities without inventing controls', {skip:process.platform!=='darwin'},()=>{
 const src=process.env.SAY_RING_CAPABILITY_SOURCE?readFileSync(process.env.SAY_RING_CAPABILITY_SOURCE,'utf8'):read('ios/Runner/QRingWearableBridge.m');
 const extract=signature=>{const a=src.indexOf(signature);return a<0?'':src.slice(a,src.indexOf('\n- (',a+1));};
 const methods=extract('- (void)resolveCapabilities {')+'\n'+extract('- (void)resolveExtendedCapabilities:');
 const template=read('tool/fixtures/qring_capability_handshake.m'),dir=mkdtempSync(join(tmpdir(),'sayring-capabilities-'));
 try {const path=join(dir,'fixture.m'),exe=join(dir,'fixture');
 const run=source=>{writeFileSync(path,template.replace('// PRODUCTION_METHODS',source));execFileSync('xcrun',['clang','-fobjc-arc','-Wall','-Wextra','-Werror','-framework','Foundation',path,'-o',exe],{stdio:'pipe'});return spawnSync(exe,[],{encoding:'utf8'});};
 const r=run(methods);assert.equal(r.status,0,r.stderr);process.stdout.write(r.stdout);
 const regressed=methods.replace('if ([features[QCBandFeatureGestureControl] isEqual:@YES] ||','if (YES ||');
 if(regressed!==methods){const bad=run(regressed);assert.equal(bad.status,1);assert.match(bad.stderr,/Capability fallback assertion failed/);process.stdout.write('Skipping extended read negative control rejected\n');}
 } finally {rmSync(dir,{recursive:true,force:true});}
});
