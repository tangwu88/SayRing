import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
registerHooks({resolve(specifier,context,next){return next(specifier.startsWith('.')&&context.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(specifier)?`${specifier}.ts`:specifier,context)}});
const {ModuleDisplayState,parseRingModules,ringModuleForPath,withModuleVisibility} = await import('../entry/src/main/ets/model/ModuleDisplay.ts');
const config=(library=true,mall=false,seconds=300)=>({product:'say-ring',platform:'harmonyos',moduleVisibility:{schemaVersion:1,validForSeconds:seconds,modules:{health_library:library,mall}}});
test('Harmony accepts exact product/platform and strict module booleans only',()=>{
 assert.deepEqual(parseRingModules(config()).modules,{health_library:true,mall:false});
 for(const change of [{product:'another'},{platform:'ios'},{moduleVisibility:{...config().moduleVisibility,validForSeconds:301}},{moduleVisibility:{...config().moduleVisibility,modules:{health_library:true,mall:'false'}}}])assert.throws(()=>parseRingModules({...config(),...change}));
});
test('default, failed refresh and expired grants close without persisted allow cache',async t=>{
 t.mock.timers.enable({apis:['setTimeout','Date'],now:1000});
 let response=config(true,true,1); const state=new ModuleDisplayState(async()=>response); t.after(()=>state.close());
 assert.equal(state.allows('mall'),false); await state.refresh(); assert.equal(state.allows('mall'),true);
 t.mock.timers.tick(1001); assert.equal(state.allows('mall'),false);
 await state.refresh(); response={product:'say-ring'}; await state.refresh(); assert.equal(state.allows('health_library'),false);
});
test('revoked request cannot return late content, and hidden reads never touch transport',async t=>{
 let response=config(true,true); const state=new ModuleDisplayState(async()=>response); t.after(()=>state.close()); await state.refresh();
 let resolve; const read=withModuleVisibility('/global/api/saydian-app/v2/commerce/orders',state,()=>new Promise(done=>resolve=done));
 response=config(true,false); await state.refresh(); resolve('private-order'); await assert.rejects(read);
 let calls=0; await assert.rejects(withModuleVisibility('/api/v1/pages?code=SHOP_HOME',state,async()=>{calls++;})); assert.equal(calls,0);
 assert.equal(await withModuleVisibility('/global/api/saydian-app/v2/content/articles',state,async()=>'library'),'library');
});
test('legal documents, auth, healthcare and other product routes are not module grants',()=>{
 for(const path of ['/global/api/saydian-app/v2/content/legal/say_ring_privacy_policy','/global/api/saydian-app/v2/auth/login','/global/api/saydian-app/v2/health/reports','/global/api/saydian-app/v2/support/app-display'])assert.equal(ringModuleForPath(path),undefined);
 assert.equal(ringModuleForPath('/global/api/saydian-app/v2/commerce/orders/id'),'mall');
 assert.equal(ringModuleForPath('/global/api/saydian-app/v2/content/categories'),'health_library');
});
