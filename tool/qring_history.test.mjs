import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
const bridge=readFileSync('ios/Runner/QRingWearableBridge.m','utf8');
const method=signature=>{const a=bridge.indexOf(signature);assert.notEqual(a,-1);return bridge.slice(a,bridge.indexOf('\n- (',a+1));};
test('seven-day QRing completeness, timeout retention, scheduling and stale generation', {skip:process.platform!=='darwin'},()=>{
 const names=['- (void)noteHistory:', '- (void)advanceSyncDay:', '- (void)finishTimedOutHealthSyncForGeneration:', '- (void)finishHealthSync'];
 const actual=names.map(method).join('\n');const template=readFileSync('tool/fixtures/qring_history.m','utf8');
 const dir=mkdtempSync(join(tmpdir(),'sayring-history-'));try {
 const source=join(dir,'history.m'),bin=join(dir,'history');
 const compile=text=>{writeFileSync(source,template.replace('// ACTUAL_HISTORY_METHODS',text));execFileSync('xcrun',['clang','-fobjc-arc','-Wall','-Wextra','-Werror','-framework','Foundation',source,'-o',bin],{stdio:'pipe'});};
 compile(actual);const out=execFileSync(bin,{encoding:'utf8'});assert.match(out,/history bookkeeping: [1-9]\d* assertions passed/);process.stdout.write(out);
 // Negative control: one day must never establish a seven-day complete result.
 compile(actual.replace('days.count != 7','days.count < 1'));
 assert.throws(()=>execFileSync(bin,{stdio:'pipe'}),e=>e.status===1);
 } finally{rmSync(dir,{recursive:true,force:true});}
});
test('all SDK phases use fresh callbacks, timeout returns partial records and core comes first',()=>{
 const sync=method('- (void)syncDay:');const start=method('- (void)syncHealth:');
 assert.match(sync,/phaseGeneration == weakSelf.syncPhaseGeneration/);
 assert.match(sync,/phase == 0\) \[self syncDay:0 phase:2\]/);
 assert.match(start,/finishTimedOutHealthSyncForGeneration:generation/);
 assert.match(start,/self.syncStatuses\[metric\] = @"pending"/);
 assert.doesNotMatch(start,/pending\(\[weakSelf error:@"QRING_SYNC_TIMEOUT"/);
});
