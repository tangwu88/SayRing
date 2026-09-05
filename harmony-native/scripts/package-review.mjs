// Creates an UNSIGNED review archive, never a publishable or signed release.
// Build and stage the three artifacts first. Refuses to replace an existing ZIP.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const root=fileURLToPath(new URL('../',import.meta.url));
const app=JSON.parse(fs.readFileSync(path.join(root,'AppScope/app.json5'),'utf8')).app;
const date=process.argv[2];
assert.match(date??'',/^\d{8}$/,'Pass a YYYYMMDD review date');
assert.match(app.versionName,/^\d+\.\d+\.\d+$/);
assert.equal(app.bundleName,'cc.saidian.saydian.harmony.dev');
const stage=path.join(root,'build',`release-review-${app.versionName}-${date}`);
const archive=path.join(root,'build',`Saydian-Harmony-${app.versionName}-UNSIGNED-REVIEW-${date}.zip`);
assert.ok(!fs.existsSync(archive),'Existing archives are preserved. Use a new review date/version.');
const prefix=`Saydian-Harmony-${app.versionName}`;
const artifacts=[`${prefix}-Debug-unsigned.hap`,`${prefix}-Release-unsigned.hap`,`${prefix}-Release-unsigned.app`];
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const run=(tool,args,options={})=>execFileSync(tool,args,{cwd:root,encoding:'utf8',timeout:60000,maxBuffer:16*1024*1024,...options});
for(const name of artifacts) {
  const file=path.join(stage,name);
  run('/usr/bin/unzip',['-tq',file]);
  const entries=run('/usr/bin/unzip',['-Z1',file]);
  assert.equal(/(?:^|\/)(?:\.env|[^/]*\.(?:p12|pfx|pem|key|cer))$/im.test(entries),false,'No signing or secret files in artifacts');
  if(name.endsWith('.hap')) {
    const meta=JSON.parse(run('/usr/bin/unzip',['-p',file,'module.json']));
    const debug=name.includes('-Debug-');
    assert.equal(meta.app.bundleName,app.bundleName);
    assert.equal(meta.app.versionName,app.versionName);
    assert.equal(meta.app.versionCode,app.versionCode);
    assert.equal(meta.app.debug,debug);
    assert.equal(meta.app.buildMode,debug?'debug':'release');
    assert.deepEqual(meta.module.requestPermissions.map(p=>p.name).sort(),[
      'ohos.permission.APP_TRACKING_CONSENT','ohos.permission.GET_NETWORK_INFO',
      'ohos.permission.GET_WIFI_INFO','ohos.permission.INTERNET'
    ]);
    if(!debug)assert.equal(entries.includes('sourceMaps.map'),false);
  }
}
const embedded=run('/usr/bin/unzip',['-p',path.join(stage,artifacts[2]),'entry-default.hap'],{encoding:'buffer'});
assert.equal(sha(embedded),sha(fs.readFileSync(path.join(stage,artifacts[1]))),'APP must contain the same reviewed Release HAP');

const tests=fs.readdirSync(path.join(root,'tests')).filter(n=>n.endsWith('.test.mjs')).map(n=>`tests/${n}`);
let verification='Host tests use synthetic fixtures; these are not native device tests.\n';
for(const tz of ['UTC','Asia/Shanghai']) {
  const output=run(process.execPath,['--test',...tests],{env:{...process.env,TZ:tz}});
  verification+=`\nTZ=${tz}\n${output}`;
}
fs.writeFileSync(path.join(stage,'HOST-TESTS.txt'),verification);
const documents=['PUSH-PAYMENT-IMPLEMENTATION-20260905.md','QA-RELEASE-20260905.md',
  `RELEASE-BLOCKERS-${app.versionName}.md`,`CANDIDATE-README-${app.versionName}.md`];
for(const name of documents) {
  fs.copyFileSync(path.join(root,'docs',name),path.join(stage,name));
}
const sources=['AppScope','entry/src','entry/oh-package.json5','entry/hvigorfile.ts','entry/build-profile.json5',
  'hvigor','hvigorfile.ts','build-profile.json5','oh-package.json5','oh-package-lock.json5','README.md','docs','tests','scripts'];
function checkSource(relative) {
  const full=path.join(root,relative),info=fs.lstatSync(full);
  assert.equal(info.isSymbolicLink(),false,'Source archive must not follow external links');
  assert.equal(/(?:^|\/)(?:\.env(?:\..*)?|\.DS_Store|[^/]*\.(?:p12|pfx|pem|key|cer|log))$/i.test(relative),false,'Source allowlist contains a private/cache file');
  if(info.isDirectory())for(const name of fs.readdirSync(full))checkSource(path.join(relative,name));
}
sources.forEach(checkSource);
run('/usr/bin/tar',['-czf',path.join(stage,'harmony-native-source.tgz'),...sources],{env:{...process.env,COPYFILE_DISABLE:'1'}});
run('/usr/bin/tar',['-tzf',path.join(stage,'harmony-native-source.tgz')]);
const manifest={schema_version:1,version:app.versionName,build:app.versionCode,bundle:app.bundleName,
  release_ready:false,signed:false,review_date:date,scope:'native HarmonyOS account, public content, remote care, push client and payment client; production platform configuration and full wearable product incomplete',
  required_reading:`RELEASE-BLOCKERS-${app.versionName}.md`,artifacts:artifacts.map(name=>({name,sha256:sha(fs.readFileSync(path.join(stage,name)))}))};
fs.writeFileSync(path.join(stage,'review-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
const names=[...artifacts,'HOST-TESTS.txt',...documents,'harmony-native-source.tgz','review-manifest.json'];
fs.writeFileSync(path.join(stage,'SHA256SUMS'),names.map(name=>`${sha(fs.readFileSync(path.join(stage,name)))}  ${name}`).join('\n')+'\n');
run('/usr/bin/zip',['-q',archive,...names,'SHA256SUMS'],{cwd:stage});
run('/usr/bin/unzip',['-tq',archive]);
const hash=sha(fs.readFileSync(archive));
fs.writeFileSync(`${archive}.sha256`,`${hash}  ${path.basename(archive)}\n`);
console.log(JSON.stringify({archive,sha256:hash,bytes:fs.statSync(archive).size,releaseReady:false},null,2));
