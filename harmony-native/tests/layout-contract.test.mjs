import { readUiSource } from './support/localized-ui-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

test('all root scroll surfaces remain top aligned while loading content',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const scrolls=(source.match(/Scroll\([^)]*\)/g)||[]).length;
  assert.ok(scrolls>=4);
  assert.equal((source.match(/align\(Alignment.Top\)/g)||[]).length,scrolls);
});

test('dynamic heading and notices are not passed as frozen scalar builder arguments',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
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
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const updateSource=readFileSync(new URL('../entry/src/main/ets/services/AppUpdateService.ets',import.meta.url),'utf8');
  assert.ok(source.includes('V${HARMONY_VERSION_NAME} (${HARMONY_VERSION_CODE})'));
  assert.ok(updateSource.includes(`HARMONY_VERSION_NAME: string = '${app.versionName}'`));
  assert.ok(updateSource.includes(`HARMONY_VERSION_CODE: number = ${app.versionCode}`));
});

test('international identity is separate and does not reuse domestic AGC identity',()=>{
  const app=JSON.parse(readFileSync(new URL('../AppScope/app.json5',import.meta.url),'utf8')).app;
  assert.equal(app.bundleName,'cn.saydian.ring.hm');
  assert.equal(app.bundleName.endsWith('.dev'),false);
  const module=JSON.parse(readFileSync(new URL('../entry/src/main/module.json5',import.meta.url),'utf8')).module;
  assert.equal(module.srcEntry,'./ets/abilitystage/EntryAbilityStage.ets');
  assert.equal(module.metadata.find(item=>item.name==='client_id'),undefined);
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
  const page=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const ability=readFileSync(new URL('../entry/src/main/ets/entryability/EntryAbility.ets',import.meta.url),'utf8');
  const router=readFileSync(new URL('../entry/src/main/ets/services/HarmonyPaymentService.ets',import.meta.url),'utf8');
  const startPayment=page.slice(page.indexOf('private async startPayment()'),page.indexOf('private money('));
  assert.equal(page.includes("import { harmonyPayment } from '../services/HarmonyPaymentService'"),false);
  assert.equal(ability.includes("import { handleHarmonyPaymentCallback } from '../services/HarmonyPaymentService'"),false);
  assert.ok(startPayment.includes('canStartHarmonyPayment(this.selectedProvider)'));
  assert.ok(startPayment.indexOf('canStartHarmonyPayment(this.selectedProvider)') <
    startPayment.indexOf('saydianApi.harmonyPayment'));
  assert.equal(router.includes("from '@kit.PaymentKit'"), false);
  assert.ok(router.indexOf("canIUse('SystemCapability.Payment.ThirdPaymentService')") <
    router.indexOf("await import('./ThirdPaymentService')"));
  assert.ok(ability.includes("await import('../services/HarmonyPaymentService')"));
});

test('payment flow times out safely and always rechecks the server order',()=>{
  const page=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const service=readFileSync(new URL('../entry/src/main/ets/services/ThirdPaymentService.ets',import.meta.url),'utf8');
  const startPayment=page.slice(page.indexOf('private async startPayment()'),page.indexOf('private money('));
  const back=page.slice(page.indexOf('private back()'),page.indexOf('onBackPress()'));
  const heading=page.slice(page.indexOf('Heading()'),page.indexOf('private careHeading()'));
  assert.ok(startPayment.includes('const orderId = this.selectedOrder.id'));
  assert.ok(startPayment.includes('await saydianApi.shopOrder(orderId)'));
  assert.ok(startPayment.includes('订单状态暂未核实'));
  assert.ok(service.includes('await withPaymentTimeout(client.pay(request.payInfo))'));
  assert.ok(service.includes('finally'));
  assert.ok(back.includes('this.careBusy || this.paymentBusy'));
  assert.ok(heading.includes('!this.deviceSettingsWriting &&'));
  assert.ok(heading.includes('!this.deviceFeatureWriting && !this.sportActionBusy'));
  const provider=page.slice(page.indexOf('private selectPaymentProvider('),page.indexOf('private async startPayment()'));
  assert.ok(provider.includes("this.paymentMessage = ''"));
  assert.ok(page.includes("this.selectPaymentProvider('wechat')"));
  assert.ok(page.includes("this.selectPaymentProvider('alipay')"));
});

test('foreground notification changes trigger the whitelisted route consumer',()=>{
  const page=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  assert.ok(page.includes("@Watch('pendingNotificationChanged')"));
  assert.ok(page.includes('private pendingNotificationChanged(): void { this.consumeNotificationRoute(); }'));
});

test('care session invalidation clears profile loading before presenting login again',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const handler=source.slice(source.indexOf('private careFailure('),source.indexOf('private async openCare('));
  for(const reset of ['this.profileLoading = false','this.profileError = \'\'','this.busy = false','this.restoring = false'])assert.ok(handler.includes(reset));
});
test('failed or remotely handled invitation refreshes actionable list rather than retaining old buttons',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const handler=source.slice(source.indexOf('private async respondInvitation('),source.indexOf('private async openCareSettings('));
  const failure=handler.slice(handler.indexOf('catch (error)'));
  assert.ok(failure.includes('this.careInvitations = []'));
  assert.ok(failure.includes('await this.readCareInvitations(epoch)'));
});

test('care member and sharing cards preserve readable member details',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const member=source.slice(source.indexOf('ForEach(this.careMembers'),source.indexOf("Button('刷新关爱列表')"));
  assert.ok(member.includes('Text(member.name)'));
  assert.ok(member.includes("Text(member.mobile || '查看已授权的健康记录')"));
  assert.ok(member.includes('.constraintSize({ minHeight: 78 })'));
  const sharing=source.slice(source.indexOf('ForEach(this.sharingTargets'),source.indexOf("} else if (this.screen === 'care-settings')"));
  assert.ok(sharing.includes('.labelStyle({ maxLines: 8 })'));
  assert.ok(sharing.includes('.constraintSize({ minHeight: 76 })'));
});

test('visual system uses the current iOS Saydian palette and consistent surfaces',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  for(const token of [
    "const RED: string = '#D20B27'",
    "const INK: string = '#171B2B'",
    "const BG: string = '#F5F7FA'",
    "const RED_SOFT: string = '#FFE8EC'",
    "const GOLD_SOFT: string = '#FFF6DE'",
    "const BLUE_SOFT: string = '#EAF1FF'",
    "const LINE: string = '#DDE3EC'",
    'const CARD_SHADOW:'
  ]) assert.ok(source.includes(token),`Missing design token: ${token}`);
  assert.ok((source.match(/type\(ButtonType\.Normal\)/g)||[]).length>=24,
    'Primary and card actions should use predictable rectangular touch surfaces');
  assert.ok((source.match(/border\(\{ width: 1, color:/g)||[]).length>=20,
    'Cards and controls should keep visible boundaries on the light canvas');
});

test('polished UI avoids text glyphs as fake icons and keeps minimum button targets',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  assert.equal(/Text\(['"`][^'"`]*[›◷✓][^'"`]*['"`]\)/.test(source),false);
  for(const match of source.matchAll(/Button\([^\n]*?\.height\((\d+)\)/g)) {
    assert.ok(Number(match[1])>=44,`Button height ${match[1]} is below the compact iOS-aligned touch target`);
  }
});

test('shop thumbnails preserve product artwork instead of cropping it',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const productImage=source.slice(source.indexOf('Image(product.picture)'),source.indexOf('.accessibilityText(product.name)'));
  assert.ok(productImage.includes('objectFit(ImageFit.Contain)'));
  assert.ok(productImage.includes('backgroundColor(SURFACE_ALT)'));
});

test('device and mine pages follow the iOS information hierarchy without dropping actions',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const device=source.slice(source.indexOf('DeviceHome()'),source.indexOf('MineHome()'));
  const homeStart=source.indexOf('\n  Home() {',source.indexOf('MineHome()'));
  const mine=source.slice(source.indexOf('MineHome()'),homeStart);
  const home=source.slice(homeStart,source.indexOf('HealthAllContent()',homeStart));
  for(const marker of ['device-current-card','设备功能','表盘与个性化','关于设备','连接说明']) {
    assert.ok(device.includes(marker),`Missing iOS-aligned device section: ${marker}`);
  }
  assert.equal(device.includes("Text('手动测量')"),false,'Manual measurement belongs to health metric pages');
  for(const marker of ['mine-profile-card','profile_stat_device','profile_stat_health','profile_stat_care',
    'mine-orders-card','mine-quick-card','mine-services-card']) {
    assert.ok(mine.includes(marker),`Missing iOS-aligned mine section: ${marker}`);
  }
  assert.ok(home.includes("Text(this.tab === 1 ? '设备' : '我的')"));
  assert.ok(home.includes(".id('section-titlebar')"));
  assert.equal(home.includes('.backgroundColor(this.tab === index ? RED_SOFT : SURFACE)'),false,
    'Bottom navigation should not use the oversized selected pill removed from the iOS layout');
  assert.match(mine,/mine-profile-card[\s\S]*openProfileEditor\(\)|openProfileEditor\(\)[\s\S]*mine-profile-card/,
    'The main profile card must open the editable profile rather than a static feature page');
});

test('care summary refresh and member page use the same list while all metric states stay visible',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  assert.match(source,/startAuthenticatedServices\(\)[\s\S]*refreshCareSummary\(true\)/);
  assert.match(source,/if \(index === 2\) this\.refreshCareSummary\(\)/);
  const careStart=source.lastIndexOf("} else if (this.screen === 'care-member') {");
  const care=source.slice(careStart,source.indexOf("} else if (this.screen === 'care-metric') {",careStart));
  assert.match(care,/ForEach\(this\.careOverview,/);
  assert.doesNotMatch(care,/ForEach\(this\.careOverview\.filter/);
  for(const label of ['当日暂无记录','对方未授权此项目','服务暂不可用'])assert.ok(care.includes(label));
});

test('launcher identity uses the requested name and a high-resolution brand icon',()=>{
  const app=JSON.parse(readFileSync(new URL('../AppScope/app.json5',import.meta.url),'utf8')).app;
  const strings=JSON.parse(readFileSync(new URL('../AppScope/resources/base/element/string.json',import.meta.url),'utf8')).string;
  assert.equal(strings.find(item=>item.name==='app_name')?.value,'Say Ring');
  assert.equal(app.icon,'$media:app_icon_v3');
  const module=JSON.parse(readFileSync(new URL('../entry/src/main/module.json5',import.meta.url),'utf8')).module;
  assert.equal(module.abilities[0].icon,'$media:app_icon_v3');
  assert.equal(module.abilities[0].startWindowIcon,'$media:app_icon_v3');
  const icon=readFileSync(new URL('../AppScope/resources/base/media/app_icon_v3.png',import.meta.url));
  assert.equal(icon.subarray(1,4).toString(),'PNG');
  assert.equal(icon.readUInt32BE(16),1024);
  assert.equal(icon.readUInt32BE(20),1024);
  const iosMaster=readFileSync(new URL('../../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',import.meta.url));
  assert.deepEqual(icon,iosMaster,'Harmony must keep the approved iOS master geometry and original red');
});

test('login offers registration and WeChat authorization instead of guest browsing',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  for(const marker of ['微信授权登录','注册账户','register_submit','register_send_code'])assert.ok(source.includes(marker));
  assert.equal(source.includes('先浏览首页'),false);
  const manifest=JSON.parse(readFileSync(new URL('../entry/src/main/module.json5',import.meta.url),'utf8')).module;
  assert.deepEqual(manifest.querySchemes,['weixin','wxopensdk','https']);
  assert.ok(manifest.abilities[0].skills[0].actions.includes('wxentity.action.open'));
});

test('disconnected health cards do not repeat the same empty-state line',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const cards=source.slice(source.indexOf('HealthHome()'),source.indexOf('DeviceHome()'));
  assert.ok(cards.includes('if (this.visibleWearableMetrics().length === 0)'));
  assert.ok(cards.includes("'connectWatchForData'"));
  assert.ok(cards.includes('ForEach(this.visibleWearableMetrics()'));
  assert.equal(cards.includes("this.wearableSnapshot.connected ? '当前手表不支持' : '暂无记录'"),false);
  assert.equal(cards.includes("已记录' : '暂无数据"),false,
    'An empty metric must have one clear empty state instead of a second status badge');
});

test('home tabs reset the shared scroll position and connected metadata stays readable',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const selector=source.slice(source.indexOf('private selectHomeTab('),source.indexOf('private signalText('));
  assert.ok(source.includes('private homeScroller: Scroller = new Scroller()'));
  assert.ok(source.includes('Scroll(this.homeScroller)'));
  assert.ok(selector.includes('this.homeScroller.scrollEdge(Edge.Top)'));
  assert.ok(source.includes('this.selectHomeTab(index);'));
  const device=source.slice(source.indexOf('DeviceHome()'),source.indexOf('DeviceSearchContent()'));
  assert.ok(device.includes("Text('connected')"));
  assert.ok(device.includes('Text(this.wearableSyncTime())'));
  assert.equal(device.includes('`已连接 · ${this.wearableSyncTime()}`'),false);
});

test('notification settings expose the actual service state without implementation copy',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const permissions=source.slice(source.indexOf('PermissionContent()'),source.indexOf('MessageContent()'));
  assert.ok(permissions.includes('Text(this.pushStatus)'));
  assert.ok(permissions.includes("id('check_push_service')"));
  assert.ok(permissions.includes('this.connectPush(true)'));
  assert.doesNotMatch(permissions,/Server key|Push Kit|registration[_ ]?id|AppKey/);
});

test('payment order number owns a full row instead of orphan-wrapping its final digits',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const payment=source.slice(source.indexOf('PaymentContent()'),source.indexOf('WearableMetricContent()'));
  assert.match(payment,/Text\(this\.selectedOrder\.number\)[\s\S]*?\.width\('100%'\)[\s\S]*?\.maxLines\(1\)/);
  assert.ok(payment.includes('.copyOption(CopyOptions.InApp)'));
});

test('login and primary surfaces exclude decorative or internal helper copy',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const login=source.slice(source.indexOf('  Login() {'),source.indexOf('  Registration() {'));
  const wechat=login.slice(login.indexOf("Button(this.busy ? '正在打开微信…'"),login.indexOf('  Registration()'));
  assert.ok(wechat.includes(".width(this.singleColumn() ? '100%' : '60%')"));
  assert.ok(login.includes("}.width('100%').justifyContent(FlexAlign.Center)"));
  for(const copy of [
    '欢迎来到赛电',
    '日常健康疑问，随时向我提问。',
    '优先展示手表支持的真实记录',
    '更多购买方式即将开放',
    '记录日常健康趋势，连接家人与设备，让健康管理更简单。',
    '只读取和切换手表内已安装表盘；不猜测缩略图，不执行 OTA。',
    '此配图地址暂不支持安全加载'
  ]) assert.equal(source.includes(copy),false,`Redundant UI copy remains: ${copy}`);
  assert.ok(source.includes('今天也要保持好状态'),'The Harmony home should retain the iOS greeting subtitle');
  for(const requiredCopy of [
    '测量结果仅供健康管理参考',
    '健康预警仅作健康管理提醒',
    '请先阅读并同意用户协议与隐私政策'
  ]) assert.ok(source.includes(requiredCopy),`Required user-safety copy missing: ${requiredCopy}`);
});

test('device search and profile shortcuts match the iOS navigation hierarchy',()=>{
  const source=readUiSource(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  const search=source.slice(source.indexOf('DeviceSearchContent()'),source.indexOf('MineHome()'));
  for(const marker of ['已发现设备','searchNearbyWatch','device_search_refresh','device_search_shop']) {
    assert.ok(source.includes(marker),`Missing device search contract: ${marker}`);
  }
  assert.ok(search.includes('wearableIdentifierText(device)'));
  assert.equal(search.includes("device.provider === 'Yuc' ? 'W8' : 'Vep'"),false,
    'vendor and legacy watch badges must not be shown in Say Ring scan rows');
  assert.equal(search.includes('${device.provider}，${this.signalText(device.rssi)}'),false,
    'provider routing must stay internal and out of accessibility labels');
  assert.ok(search.includes("Text('连接')"));
  assert.equal(search.includes("Text('暂不支持')"),false,'Both W8 and W9 discovery rows must be connectable');
  const mineStart=source.indexOf('MineHome()');
  const mine=source.slice(mineStart,source.indexOf('\n  Home() {',mineStart));
  for(const marker of ['AI提问','单位设置','mine_account','mine_units']) assert.ok(mine.includes(marker));
  assert.equal(mine.includes("Text('个人资料').fontSize(17)"),false,'Profile should not be duplicated in the quick card');
  assert.equal(mine.includes("Text('消息与推送').fontSize(17)"),false,'Messages stay in the health header like iOS');
});
