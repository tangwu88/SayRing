import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
registerHooks({resolve(specifier,context,next){
  return next(specifier.startsWith('.')&&context.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(specifier)?specifier+'.ts':specifier,context);
}});
const {parseCareInvitations,careInvitationNeedsConfirmation}=await import('../entry/src/main/ets/model/CareContracts.ts');
const {pageLayout,controlHeight}=await import('../entry/src/main/ets/model/PagePresentation.ts');
const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
const card=source.slice(source.indexOf('      ForEach(this.pendingInvitations()'),source.indexOf("      Button('刷新邀请状态')"));
const invitation=(id=69,inviter=102)=>({id,member_id:inviter,to_member_id:103,examine_status:0});

test('production parser keeps invitation and inviter IDs distinct and displays a real-ID fallback',()=>{
  const value=parseCareInvitations([invitation()], '103')[0];
  assert.deepEqual(value,{id:69,inviterId:102,name:'邀请人 #102',mobile:'',state:'pending'});
  assert.equal(careInvitationNeedsConfirmation(value),true);
  const others=parseCareInvitations([invitation(70,108),invitation(71,109)],'103');
  assert.deepEqual(others.map(row=>row.name),['邀请人 #108','邀请人 #109']);
});

test('recipient nested as member cannot supply its own name/mobile; correctly matched public inviter can',()=>{
  const raw={...invitation(),member:{id:103,nickname:'当前收件人',mobile:'10000000003'}};
  const safe=parseCareInvitations([raw],'103')[0];
  assert.equal(safe.name,'邀请人 #102');assert.equal(safe.mobile,'');assert.equal(careInvitationNeedsConfirmation(safe),true);
  const real=parseCareInvitations([{...raw,inviter:{id:102,nickname:'合成家人',mobile:'10000000002'}}],'103')[0];
  assert.equal(real.name,'合成家人');assert.equal(real.mobile,'10000000002');assert.equal(careInvitationNeedsConfirmation(real),false);
});

test('nickname absent but verified phone present keeps the real phone without showing a false missing-identity warning',()=>{
  const row=parseCareInvitations([{...invitation(),inviter:{id:102,mobile:'10000000002'}}],'103')[0];
  assert.equal(row.name,'邀请人 #102');assert.equal(row.mobile,'10000000002');assert.equal(careInvitationNeedsConfirmation(row),false);
});

test('production invitation card uses wrapping text, large-type single-column actions, readable labels and mutable render key',()=>{
  assert.match(card,/Text\(invite.name\).*fontSize\(17\)/);
  assert.match(card,/careInvitationNeedsConfirmation\(invite\)/);
  assert.match(card,/Text\(careInvitationFallback\(invite.inviterId\)\)/);
  assert.match(card,/请确认邀请人后再接受/);
  assert.match(card,/FlexDirection.Column : FlexDirection.Row/);
  assert.equal((card.match(/minHeight: this.controlHeight\(48\)/g)??[]).length,2);
  assert.match(card,/care_invitation_reject_\$\{invite.id\}/);assert.match(card,/care_invitation_accept_\$\{invite.id\}/);
  assert.match(card,/JSON.stringify\(invite\)/);
  assert.doesNotMatch(card,/maxLines\(|textOverflow|ellipsis|FittedBox|服务器|接口|SDK/);
  for(const width of [320,361,390,430,600,840])for(const scale of [1,1.3,1.5,2]){
    const layout=pageLayout(width,scale);
    assert.equal(layout.singleColumn,width<360||scale>1.3);
    assert.ok(controlHeight(48,scale)>=48);assert.ok(controlHeight(48,scale)>=24*scale+24);
  }
});
