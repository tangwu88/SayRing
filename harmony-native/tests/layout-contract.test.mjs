import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

test('all root scroll surfaces remain top aligned while loading content',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  assert.equal((source.match(/Scroll\(\)/g)||[]).length,3);
  assert.equal((source.match(/align\(Alignment.Top\)/g)||[]).length,3);
});

test('dynamic heading and notices are not passed as frozen scalar builder arguments',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  assert.ok(source.includes('Heading()'));
  assert.equal(source.includes('Heading(title: string)'),false);
  assert.ok(source.includes('Notice($$: NoticeOptions)'));
  assert.equal((source.match(/this\.Notice\(/g)||[]).length,(source.match(/this\.Notice\(\{ message:/g)||[]).length);
});

test('native app explicitly follows system text size up to double size',()=>{
  const app=JSON.parse(readFileSync(new URL('../AppScope/app.json5',import.meta.url),'utf8')).app;
  assert.equal(app.configuration,'$profile:configuration');
  const config=JSON.parse(readFileSync(new URL('../AppScope/resources/base/profile/configuration.json',import.meta.url),'utf8')).configuration;
  assert.equal(config.fontSizeScale,'followSystem');
  assert.equal(config.fontSizeMaxScale,'2');
});

test('package metadata meets bundled build-tool rules without overstating the app version',()=>{
  for(const file of ['../oh-package.json5','../entry/oh-package.json5']) {
    const pkg=JSON.parse(readFileSync(new URL(file,import.meta.url),'utf8'));
    assert.match(pkg.version,/^[1-9]\d?(\.([1-9]?\d)){2}$/);
  }
  const app=JSON.parse(readFileSync(new URL('../AppScope/app.json5',import.meta.url),'utf8')).app;
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  assert.ok(source.includes(`赛电鸿蒙 ${app.versionName} ·`));
});

test('release identity stays aligned with the confirmed AGC HarmonyOS app',()=>{
  const app=JSON.parse(readFileSync(new URL('../AppScope/app.json5',import.meta.url),'utf8')).app;
  assert.equal(app.bundleName,'cc.saidian.app.hm');
  assert.equal(app.bundleName.endsWith('.dev'),false);
});

test('optional PaymentKit is not loaded during cold start',()=>{
  const page=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const ability=readFileSync(new URL('../entry/src/main/ets/entryability/EntryAbility.ets',import.meta.url),'utf8');
  const startPayment=page.slice(page.indexOf('private async startPayment()'),page.indexOf('private money('));
  assert.equal(page.includes("import { harmonyPayment } from '../services/HarmonyPaymentService'"),false);
  assert.equal(ability.includes("import { handleHarmonyPaymentCallback } from '../services/HarmonyPaymentService'"),false);
  assert.ok(startPayment.includes("canIUse('SystemCapability.Payment.ThirdPaymentService')"));
  assert.ok(startPayment.indexOf("canIUse('SystemCapability.Payment.ThirdPaymentService')") <
    startPayment.indexOf('saydianApi.harmonyPayment'));
  assert.ok(startPayment.indexOf('saydianApi.harmonyPayment') <
    startPayment.indexOf("await import('../services/HarmonyPaymentService')"));
  assert.ok(ability.includes("await import('../services/HarmonyPaymentService')"));
});

test('foreground notification changes trigger the whitelisted route consumer',()=>{
  const page=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  assert.ok(page.includes("@Watch('pendingNotificationChanged')"));
  assert.ok(page.includes('private pendingNotificationChanged(): void { this.consumeNotificationRoute(); }'));
});

test('care session invalidation clears profile loading before presenting login again',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const handler=source.slice(source.indexOf('private careFailure('),source.indexOf('private async openCare('));
  for(const reset of ['this.profileLoading = false','this.profileError = \'\'','this.busy = false','this.restoring = false'])assert.ok(handler.includes(reset));
});
test('failed or remotely handled invitation refreshes actionable list rather than retaining old buttons',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const handler=source.slice(source.indexOf('private async respondInvitation('),source.indexOf('private async openCareSettings('));
  const failure=handler.slice(handler.indexOf('catch (error)'));
  assert.ok(failure.includes('this.careInvitations = []'));
  assert.ok(failure.includes('await this.readCareInvitations(epoch)'));
});

test('care member and sharing buttons allow multiline labels instead of the native one-line default',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  for(const marker of ['Button(`${member.name}', 'Button(`${invite.name}']) {
    const start=source.indexOf(marker);
    assert.ok(start>=0);
    const card=source.slice(start,source.indexOf('.onClick(',start));
    assert.ok(card.includes('.labelStyle({ maxLines: 8 })'));
    assert.ok(card.includes('.constraintSize({ minHeight:'));
    assert.equal(card.includes('.height('),false,'Cards must grow for system large text');
  }
});
