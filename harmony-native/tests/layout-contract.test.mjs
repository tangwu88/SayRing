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
  const updateSource=readFileSync(new URL('../entry/src/main/ets/services/AppUpdateService.ets',import.meta.url),'utf8');
  assert.ok(source.includes('SayDian赛电 V${HARMONY_VERSION_NAME} (${HARMONY_VERSION_CODE})'));
  assert.ok(updateSource.includes(`HARMONY_VERSION_NAME: string = '${app.versionName}'`));
  assert.ok(updateSource.includes(`HARMONY_VERSION_CODE: number = ${app.versionCode}`));
});

test('release identity stays aligned with the confirmed AGC HarmonyOS app',()=>{
  const app=JSON.parse(readFileSync(new URL('../AppScope/app.json5',import.meta.url),'utf8')).app;
  assert.equal(app.bundleName,'cc.saidian.app.hm');
  assert.equal(app.bundleName.endsWith('.dev'),false);
  const module=JSON.parse(readFileSync(new URL('../entry/src/main/module.json5',import.meta.url),'utf8')).module;
  assert.equal(module.srcEntry,'./ets/abilitystage/EntryAbilityStage.ets');
  assert.equal(module.metadata.find(item=>item.name==='client_id')?.value,'2031340074867668160');
  const stage=readFileSync(new URL('../entry/src/main/ets/abilitystage/EntryAbilityStage.ets',import.meta.url),'utf8');
  const push=readFileSync(new URL('../entry/src/main/ets/services/HarmonyPushService.ets',import.meta.url),'utf8');
  assert.ok(stage.includes('prepareJPush(this.context)'));
  assert.ok(push.includes('JPushInterface.setCallBackMsg(new SaydianPushCallback())'));
  assert.ok(push.includes('initializationTask = Promise.resolve(JPushInterface.init(context))'));
  assert.ok(push.includes('configureJPush(applicationContext)'));
  assert.ok(push.includes('await initializeJPush(context)'));
  assert.ok(push.includes('await this.waitForRegistrationId()'));
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

test('payment flow times out safely and always rechecks the server order',()=>{
  const page=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const service=readFileSync(new URL('../entry/src/main/ets/services/HarmonyPaymentService.ets',import.meta.url),'utf8');
  const startPayment=page.slice(page.indexOf('private async startPayment()'),page.indexOf('private money('));
  const back=page.slice(page.indexOf('private back()'),page.indexOf('onBackPress()'));
  const heading=page.slice(page.indexOf('Heading()'),page.indexOf('private careHeading()'));
  assert.ok(startPayment.includes('const orderId = this.selectedOrder.id'));
  assert.ok(startPayment.includes('await saydianApi.shopOrder(orderId)'));
  assert.ok(startPayment.includes('订单状态暂未核实'));
  assert.ok(service.includes('await withPaymentTimeout(client.pay(request.payInfo))'));
  assert.ok(service.includes('finally'));
  assert.ok(back.includes('this.careBusy || this.paymentBusy'));
  assert.ok(heading.includes('.enabled(!this.careBusy && !this.paymentBusy)'));
  const provider=page.slice(page.indexOf('private selectPaymentProvider('),page.indexOf('private async startPayment()'));
  assert.ok(provider.includes("this.paymentMessage = ''"));
  assert.ok(page.includes("this.selectPaymentProvider('wechat')"));
  assert.ok(page.includes("this.selectPaymentProvider('alipay')"));
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

test('visual system uses the approved warm Saydian palette and consistent surfaces',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  for(const token of [
    "const BG: string = '#FFF9F7'",
    "const RED_SOFT: string = '#FFF0F3'",
    "const GOLD_SOFT: string = '#FFF5DB'",
    "const LINE: string = '#EEE7E5'",
    'const CARD_SHADOW:'
  ]) assert.ok(source.includes(token),`Missing design token: ${token}`);
  assert.ok((source.match(/type\(ButtonType\.Normal\)/g)||[]).length>=24,
    'Primary and card actions should use predictable rectangular touch surfaces');
  assert.ok((source.match(/border\(\{ width: 1, color:/g)||[]).length>=20,
    'Cards and controls should keep visible boundaries on the warm background');
});

test('polished UI avoids text glyphs as fake icons and keeps minimum button targets',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  assert.equal(/Text\(['"`][^'"`]*[›◷✓][^'"`]*['"`]\)/.test(source),false);
  for(const match of source.matchAll(/Button\([^\n]*?\.height\((\d+)\)/g)) {
    assert.ok(Number(match[1])>=48,`Button height ${match[1]} is below the 48 vp touch target`);
  }
});

test('shop thumbnails preserve product artwork instead of cropping it',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const productImage=source.slice(source.indexOf('Image(product.picture)'),source.indexOf('.accessibilityText(product.name)'));
  assert.ok(productImage.includes('objectFit(ImageFit.Contain)'));
  assert.ok(productImage.includes('backgroundColor(SURFACE_ALT)'));
});

test('device and mine pages follow the iOS information hierarchy without dropping actions',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const device=source.slice(source.indexOf('DeviceHome()'),source.indexOf('MineHome()'));
  const homeStart=source.indexOf('\n  Home() {',source.indexOf('MineHome()'));
  const mine=source.slice(source.indexOf('MineHome()'),homeStart);
  const home=source.slice(homeStart,source.indexOf('HealthAllContent()',homeStart));
  for(const marker of ['device-current-card','设备功能','表盘与个性化','手动测量','关于设备','连接说明']) {
    assert.ok(device.includes(marker),`Missing iOS-aligned device section: ${marker}`);
  }
  for(const marker of ['mine-profile-card','profile_stat_device','profile_stat_health','profile_stat_care',
    'mine-orders-card','mine-quick-card','mine-services-card']) {
    assert.ok(mine.includes(marker),`Missing iOS-aligned mine section: ${marker}`);
  }
  assert.ok(home.includes("Text(this.tab === 1 ? '设备' : '我的')"));
  assert.ok(home.includes(".id('section-titlebar')"));
  assert.equal(home.includes('.backgroundColor(this.tab === index ? RED_SOFT : SURFACE)'),false,
    'Bottom navigation should not use the oversized selected pill removed from the iOS layout');
});

test('launcher identity uses the requested name and a high-resolution brand icon',()=>{
  const app=JSON.parse(readFileSync(new URL('../AppScope/app.json5',import.meta.url),'utf8')).app;
  const strings=JSON.parse(readFileSync(new URL('../AppScope/resources/base/element/string.json',import.meta.url),'utf8')).string;
  assert.equal(strings.find(item=>item.name==='app_name')?.value,'SayDian赛电');
  assert.equal(app.icon,'$media:app_icon_v2');
  const icon=readFileSync(new URL('../AppScope/resources/base/media/app_icon_v2.png',import.meta.url));
  assert.equal(icon.subarray(1,4).toString(),'PNG');
  assert.equal(icon.readUInt32BE(16),1024);
  assert.equal(icon.readUInt32BE(20),1024);
});
