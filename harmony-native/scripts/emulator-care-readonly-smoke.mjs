// Opt-in native UI check. Read-only business operations: never sends/responds to an invitation,
// changes a sharing toggle, saves settings, logs out, or prints private member/health values.
import assert from 'node:assert/strict';
import {EmulatorUI} from './emulator-ui.mjs';
const ui=new EmulatorUI(process.argv[2]);
function settled(){
  const deadline=Date.now()+45000;
  do { const state=ui.read(); if(!state.includes('- LoadingProgress'))return state; } while(Date.now()<deadline);
  throw Error('Native page loading exceeded 45 seconds');
}
function buttons(){return [...settled().matchAll(/- Button ([\s\S]*?) \[id:(\d+)\]/g)].map(match=>({label:match[1],id:match[2]}));}
ui.waitFor('健康数据');ui.expect('健康数据','care smoke starts on home');ui.tap('远程关爱');settled();ui.expectHeading('远程关爱');
if(ui.has('前往登录'))throw Error('This read-only smoke requires the user to have logged in manually');
const initial=buttons();
const inviteButton=initial.find(item=>item.label.startsWith('关爱邀请'));
assert.ok(inviteButton);const count=Number(inviteButton.label.match(/(\d+) 条待处理/)?.[1]??0);
ui.tap(inviteButton.label);settled();ui.expectHeading('关爱邀请');
const actions=buttons().filter(item=>item.label==='同意邀请').length;
assert.equal(actions,count,'Pending count and actual actionable list must match');
console.log(`PASS invitation count/list consistency: count=${count}; no response performed`);
ui.back();ui.tap('添加关爱成员');ui.expectHeading('添加关爱成员');
ui.expect('发送关爱邀请','explicit invitation submit exists; not invoked');ui.back();
ui.tap('共享管理');settled();ui.expectHeading('共享管理');
const targets=buttons().filter(item=>item.label.includes('设置允许对方查看的项目'));
if(targets.length){
  ui.tap(targets[0].label);const state=settled();ui.expectHeading('共享数据管理');
  assert.equal((state.match(/- Toggle /g)||[]).length,13,'All confirmed sharing options are present');
  ui.expect('重新读取共享设置','sharing retry exists');
  console.log(`PASS sharing detail read; targetCount=${targets.length}; no toggle/save performed`);ui.back();
}else console.log('PASS sharing empty/unavailable state; no accepted target available for detail UI');
ui.back();
const members=buttons().filter(item=>item.label.includes('查看已授权的健康记录'));
if(members.length){
  ui.tap(members[0].label);settled();ui.expectHeading('成员健康数据');
  ui.expect('来源：远程成员授权共享','remote data origin displayed');
  for(const title of ['心率','血压','血氧','血糖','体温','HRV','睡眠','心电','身体成分','血液成分']){
    ui.tap(title);const state=settled();ui.expectHeading('成员健康数据');
    assert.ok(state.includes(`${title} ·`)||state.includes('读取失败')||state.includes('暂不可用')||state.includes('格式异常'));
    const result=state.includes('条共享记录')?'records':state.includes('尚未授权')?'unauthorized':state.includes('没有可共享')?'empty':'unavailable';
    console.log(`PASS ${title} native query and state: ${result}; private values omitted`);
  }
  ui.tap('前一天');settled();ui.expect('查询日期','previous-day request');
  ui.tap('后一天');settled();ui.expect('查询日期','return-day request');
  ui.back();ui.waitFor('刷新关爱列表');ui.expectHeading('远程关爱');
}else console.log('PASS member empty/unavailable state; no member available for detail UI');
ui.back();ui.expect('健康数据','care smoke returned to home');
console.log(`PASS care read-only native smoke: ${ui.instance}`);
