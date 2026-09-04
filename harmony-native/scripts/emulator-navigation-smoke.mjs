// Explicit opt-in UI smoke. Requires the official tools and a running Saydian app.
// Never submits a login, accepts agreements, logs out a user, changes their profile, or accesses watches.
import assert from 'node:assert/strict';
import {EmulatorUI} from './emulator-ui.mjs';
const instance=process.argv[2];
const ui=new EmulatorUI(instance);
ui.waitFor('健康数据');ui.expect('健康数据','health home');
for(const [button,heading,body] of [
  ['消息','消息','尚未接入'],
  ['查看适配进度','原生适配进度','待接入']
]){
  ui.tap(button);ui.expectHeading(heading);ui.expect(body,`${heading} honest availability`);ui.back();
}
ui.tap('远程关爱');ui.expectHeading('远程关爱');
if(ui.has('前往登录'))ui.expect('请先登录','guest care route');
else {
  ui.expect('默认不共享','care privacy notice');
  // Only read list state; never send, accept, reject, or save sharing in this smoke.
  ui.expect('刷新关爱列表','care list retry entry');
}
ui.back();
ui.tap('手表连接功能适配中');ui.expect('我的设备','blue device notice route');
ui.expect('Yucheng（名称包含 W8 的系列）','device SDK labels');
ui.tap('返回健康首页');ui.expect('健康数据','device return');
for(const metric of ['心率','血压','血氧','血糖','体温','睡眠','HRV','心电','身体成分','血液成分']) {
  ui.metric(metric);ui.expectHeading(`${metric}记录`);ui.expect(`没有${metric}记录`,`${metric} empty state`);ui.back();
}
ui.tap('健康百科');ui.expectHeading('健康百科');
for(const title of ['了解血氧','睡眠呼吸暂停综合症常识','了解血压','新闻1']) {
  ui.tap(title);ui.expectHeading(title);
  if(title==='新闻1'){
    let state=ui.read();
    for(let i=0;i<8&&state.includes('正在加载配图');i++)state=ui.read();
    assert.equal((state.match(/- Image /g)||[]).length,2);
    assert.equal(state.includes('配图加载失败'),false);
    console.log('PASS two real public article images');
  }
  ui.back();ui.expectHeading('健康百科');
}
ui.back();ui.tap('我的');
const signedIn=ui.has('刷新个人资料');
if(signedIn){
  ui.tap('刷新个人资料');ui.expect('最近读取','profile refresh completed');
  ui.expect('退出本机登录','signed in state retained; no logout executed');
}else ui.expect('暂未登录','guest profile state');
for(const title of ['用户协议','隐私政策']) {
  ui.tap(title);ui.expectHeading(title==='隐私政策'?/^隐私(协议|政策)$/:title);
  const before=ui.line('‹ 返回').row;
  const scroll=ui.state.match(/- Scroll \[id:(\d+)\]/);
  assert.ok(scroll,'Long legal content must scroll');
  ui.command('-slide',`${scroll[1]} up`);
  const after=ui.line('‹ 返回').row;
  assert.equal(before.match(/top: (\d+)/)?.[1],after.match(/top: (\d+)/)?.[1]);
  console.log(`PASS ${title} persistent back button`);ui.back();
}
ui.tap('健康');ui.expect('健康数据','returned to home');
console.log(`PASS navigation smoke complete: ${instance}; signedIn=${signedIn}`);
