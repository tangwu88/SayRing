import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
registerHooks({resolve(specifier,context,next){return next(specifier.startsWith('.')&&context.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(specifier)?specifier+'.ts':specifier,context)}});
const{appText}=await import('../entry/src/main/ets/model/GlobalLocale.ts');
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('camera merge keeps international identity, reports, explicit permissions and disabled provider metadata',()=>{
 const app=JSON.parse(read('AppScope/app.json5')),module=JSON.parse(read('entry/src/main/module.json5')).module,source=read('entry/src/main/ets/pages/Index.ets');
 assert.equal(app.app.bundleName,'cn.saydian.app.global.hm');assert.deepEqual(module.metadata,[]);
 const permission=module.requestPermissions.find(p=>p.name==='ohos.permission.CAMERA');assert.equal(permission.reason,'$string:reason_camera');assert.equal(permission.usedScene.when,'inuse');
 for(const token of ['this.globalReportAction(',"id('reports_generate')",'await saveReportPdf','XComponentType.SURFACE','this.captureCameraPhoto(true)','this.cameraSurfaceDestroyed()'])assert.ok(source.includes(token),token);
 assert.doesNotMatch(source,/^(<<<<<<<|=======|>>>>>>>)/m);
});
test('camera permission rationale has eight locale resources and English base fallback',()=>{
 const base=JSON.parse(read('entry/src/main/resources/base/element/string.json')).string;
 for(const locale of ['en','zh_Hans','zh_Hant','de','fr','es','ja','ko']){
  const strings=JSON.parse(read('entry/src/main/resources/'+locale+'/element/string.json')).string;
  assert.deepEqual(strings.map(item=>item.name),base.map(item=>item.name));assert.equal(strings.every(item=>typeof item.value==='string'&&item.value.length>0),true);
 }
 assert.match(base.find(item=>item.name==='reason_camera').value,/only when you start/);
});
test('all incoming camera literals have English fallback and visible controls use localization',()=>{
 const ui=read('entry/src/main/ets/pages/Index.ets'),native=read('entry/src/main/ets/services/HarmonyCameraController.ets');
 const section=ui.slice(ui.indexOf("} else if (this.selectedDeviceFeature === 'camera')"),ui.indexOf("} else if (this.selectedDeviceFeature === 'phoneCalls')"));
 for(const literal of [...(section+native).matchAll(/'([^'\n]*[\u4e00-\u9fff][^'\n]*)'/g)].map(match=>match[1]))assert.doesNotMatch(appText(literal,'en'),/[\u4e00-\u9fff]/,literal);
 assert.doesNotMatch(section,/(?:Text|Button|accessibilityText)\('[\u4e00-\u9fff]/);
 assert.match(native,/known\.includes\(error.message\)/);
});
