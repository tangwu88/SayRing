// Opt-in developer helper. Invoke only after the user authorizes official emulator UI control.
// Does not save widget text, account fields, screenshots, or credentials to the repository.
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';

const executable = '/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator';
const allowed = ['Saydian_HarmonyOS7_Phone', 'Saydian_QA_API26_Narrow'];
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export class EmulatorUI {
  constructor(instance) {
    assert.ok(allowed.includes(instance), 'Only the two isolated Saydian test emulators are allowed');
    this.instance = instance;
  }
  command(...args) {
    const out = execFileSync(executable, ['-instance', this.instance, ...args], {encoding:'utf8',timeout:20000,maxBuffer:2*1024*1024});
    assert.ok(!/simulation failed|performed failed/i.test(out), 'Official emulator command failed');
    return out;
  }
  read() { this.state = this.command('-uiLayout', '-a'); return this.state; }
  has(text) { return this.read().includes(text); }
  waitFor(text, timeout=20000) {
    const deadline=Date.now()+timeout;
    do { if(this.has(text))return; } while(Date.now()<deadline);
    throw Error('Expected page was not ready within the bounded startup wait');
  }
  expect(text, label = text) { assert.ok(this.has(text), `Missing expected page: ${label}`); console.log(`PASS ${label}`); }
  expectHeading(title) {
    const state=this.read();
    const match=state.match(/- Button ‹ 返回[^\n]*\n[ ]*- Text (.*?) \[id:/);
    if(title instanceof RegExp) assert.match(match?.[1]??'',title, 'Heading must match the current server article title');
    else assert.equal(match?.[1],title, 'Heading must follow the current article or feature');
    console.log(`PASS heading: ${title}`);
  }
  line(text, kind = 'Button') {
    const state = this.read();
    const match = state.match(new RegExp(`^([ ]*)- ${kind} ${escape(text)} \\[id:(\\d+)\\]([^\\n]*)$`, 'm'));
    assert.ok(match, `Missing ${kind}: ${text}`);
    return { id:match[2], row:match[0] };
  }
  visible(text, kind = 'Button') {
    for (let attempt=0; attempt<12; attempt++) {
      const node=this.line(text,kind);
      const bounds=node.row.match(/top: (-?\d+).*height: (\d+)/);
      const parents=[];
      for(const row of this.state.split('\n')) {
        const item=row.match(/^([ ]*)- /);if(!item)continue;
        while(parents.length && parents.at(-1).indent>=item[1].length) parents.pop();
        if(row===node.row)break;
        parents.push({indent:item[1].length,row});
      }
      const scroll=parents.map(item=>item.row).reverse().find(row=>row.includes('- Scroll [id:'))
        ?.match(/- Scroll \[id:(\d+)\] \[top: (-?\d+).*height: (\d+)/);
      if(!scroll || !bounds) return node;
      const top=Number(bounds[1]), bottom=top+Number(bounds[2]);
      const start=Number(scroll[2]), end=start+Number(scroll[3]);
      if(top>=start && bottom<=end) return node;
      this.command('-slide',`${scroll[1]} ${top<start?'down':'up'}`);
    }
    throw Error(`Could not bring ${text} on screen`);
  }
  tap(text) { const node=this.visible(text); this.command('-click',node.id); return this.read(); }
  metric(text) {
    // The label can be visible while its card's center is below the viewport.
    // Hit the freshly observed visible label; ArkUI bubbles this to the card.
    const node=this.visible(text,'Text');
    this.command('-click',node.id);return this.read();
  }
  back() { return this.tap('‹ 返回'); }
}
