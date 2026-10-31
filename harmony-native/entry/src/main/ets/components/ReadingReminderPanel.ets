import { common } from '@kit.AbilityKit';
import { RING_THEME } from '../model/RingParity';
import { WearableSnapshot, emptyWearableSnapshot } from '../model/WearableContracts';
import { ReadingRule, ReadingSettings, PersonalReadingEvent, ReadingNotice, defaultReadingSettings,
  readingRuleTitle, readingRuleEnabled, setReadingRule, readingNumber, setReadingNumber,
  readingSettingsError, supportedReadingRules, setReadingSound, setReadingMotion } from '../model/ReadingReminders';
import { readingReminderStore } from '../services/ReadingReminderStore';
import { personalReadingReminders } from '../services/PersonalReadingReminders';

@Component
export struct ReadingReminderPanel {
  @Prop @Watch('contextChanged') owner: string = '';
  @Prop @Watch('contextChanged') snapshot: WearableSnapshot = emptyWearableSnapshot();
  @Prop activityOnly: boolean = false;
  onDailySettings: () => void = () => {};
  @State private settings: ReadingSettings = defaultReadingSettings();
  @State private events: PersonalReadingEvent[] = [];
  @State private message: string = '';
  @State private busy: boolean = true;
  @State private details: boolean = false;
  @State private help: boolean = false;
  @State private helpPhone: string = '';
  private generation: number = 0;
  private identity: string = '';
  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { ++this.generation; }
  private context(): common.UIAbilityContext { return this.getUIContext().getHostContext() as common.UIAbilityContext; }
  private contextChanged(): void {
    if (this.identity !== `${this.owner}|${this.snapshot.deviceKey}|${this.snapshot.firmware}`) this.load();
  }
  private async load(): Promise<void> {
    const generation = ++this.generation, owner = this.owner;
    this.identity = `${owner}|${this.snapshot.deviceKey}|${this.snapshot.firmware}`;
    this.busy = true; this.message = ''; this.events = []; this.helpPhone = '';
    personalReadingReminders.configure(owner, this.context(), this.snapshot);
    try {
      const settings = await readingReminderStore.read(owner);
      const events = await readingReminderStore.events(owner);
      if (generation !== this.generation || owner !== this.owner) return;
      this.settings = settings; this.events = events;
    } catch { if (generation === this.generation) this.message = '提醒设置暂未读取，请解锁后重新进入'; }
    finally { if (generation === this.generation) this.busy = false; }
  }
  private matches(rule: ReadingRule): boolean {
    if (rule === 'hrv') return !!this.snapshot.firmware && this.settings.hrvDevice === this.snapshot.deviceKey && this.settings.hrvFirmware === this.snapshot.firmware;
    if (rule === 'temperature') return !!this.snapshot.firmware && this.settings.skinDevice === this.snapshot.deviceKey && this.settings.skinFirmware === this.snapshot.firmware;
    return true;
  }
  private numberChanged(field: string, value: string): void {
    const next = setReadingNumber(this.settings, field, value);
    if (field === 'hrvReference') { next.hrvDevice = this.snapshot.deviceKey; next.hrvFirmware = this.snapshot.firmware; }
    if (field === 'skinReference') { next.skinDevice = this.snapshot.deviceKey; next.skinFirmware = this.snapshot.firmware; }
    this.settings = next;
  }
  private async save(): Promise<void> {
    if (this.busy) return;
    this.message = readingSettingsError(this.settings);
    if (this.message) return;
    this.busy = true;
    const owner = this.owner, generation = this.generation, device = this.snapshot.deviceKey, firmware = this.snapshot.firmware;
    try {
      await personalReadingReminders.save(owner, this.settings, device, firmware);
      if (owner === this.owner && generation === this.generation) this.message = '已保存';
    } catch (error) { if (generation === this.generation) this.message = (error as Error).message || '设置未保存，请重试'; }
    finally { if (generation === this.generation) this.busy = false; }
  }
  private async openDialler(): Promise<void> {
    const phone = this.helpPhone.trim();
    if (!/^\+?[0-9]{3,20}$/.test(phone)) { this.message = '请填写所在地的急救电话'; return; }
    try { await this.context().startAbility({ action: 'ohos.want.action.dial', uri: `tel:${phone}` }); }
    catch { this.message = '无法打开拨号页面，请使用手机拨号'; }
  }
  @Builder
  NumberField(label: string, field: string, empty: boolean = false) {
    Row({ space: 8 }) {
      Text(label).fontSize(14).fontColor(RING_THEME.muted).layoutWeight(1)
      TextInput({ text: empty ? '' : readingNumber(this.settings, field), placeholder: '请输入' })
        .width(112).height(44).fontSize(16).maxLength(8).enabled(!this.busy)
        .onChange((value: string) => this.numberChanged(field, value)).id(`reading-number-${field}`)
    }.width('100%')
  }
  @Builder
  RuleRow(rule: ReadingRule) {
    Column({ space: 5 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(18).fontColor([RING_THEME.primary])
        Text(readingRuleTitle(rule)).fontSize(16).fontWeight(FontWeight.Medium).fontColor(RING_THEME.ink).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: readingRuleEnabled(this.settings, rule) && this.matches(rule) })
          .selectedColor(RING_THEME.primary).enabled(!this.busy && this.matches(rule))
          .onChange((enabled: boolean) => this.settings = setReadingRule(this.settings, rule, enabled)).id(`reading-toggle-${rule}`)
      }.width('100%').constraintSize({ minHeight: 48 })
      if (rule === 'high' || rule === 'low') this.NumberField(rule === 'high' ? '高于此值提醒（次/分）' : '低于此值提醒（次/分）', rule)
      else if (rule === 'oxygen') this.NumberField('低于此值提醒（%）', 'oxygen')
      else if (rule === 'hrv') {
        this.NumberField('个人参考值（ms）', 'hrvReference', !this.matches(rule))
        this.NumberField('相对下降幅度（%）', 'hrvDropPercent')
      } else {
        this.NumberField('个人皮温参考（℃）', 'skinReference', !this.matches(rule))
        this.NumberField('相对上升幅度（℃）', 'skinRise')
      }
      if (!this.matches(rule)) Text('请先为当前戒指设置个人参考值').fontSize(12).fontColor(RING_THEME.muted).width('100%')
    }.width('100%').padding({ top: 8, bottom: 8 })
  }
  build() {
    Column({ space: 12 }) {
      if (!this.activityOnly) {
        Button('紧急求助').width('100%').constraintSize({ minHeight: 48 }).fontColor(RING_THEME.danger)
          .backgroundColor('#FCEDEE').onClick(() => this.help = !this.help).id('reading-urgent-help')
        if (this.help) {
          Text('如有明显不适，请及时联系当地急救服务，不要等待戒指测量结果。').fontSize(14).fontColor(RING_THEME.ink)
          TextInput({ text: this.helpPhone, placeholder: '所在地急救电话' }).maxLength(21).onChange((value: string) => this.helpPhone = value)
          Button('打开拨号页面').width('100%').onClick(() => this.openDialler())
        }
        Text('个人读数提醒').fontSize(18).fontWeight(FontWeight.Bold).fontColor(RING_THEME.ink).width('100%')
        if (!supportedReadingRules(this.snapshot).length) {
          Text('连接受支持的戒指后，可设置对应的读数提醒。').fontSize(14).fontColor(RING_THEME.muted).width('100%')
        } else {
          Column() {
            ForEach(supportedReadingRules(this.snapshot), (rule: ReadingRule) => {
              this.RuleRow(rule)
              Divider().color(RING_THEME.line)
            }, (rule: ReadingRule) => rule)
          }.width('100%').padding(12).backgroundColor(Color.White).borderRadius(18)
        }
        Column() {
          Row() {
            Text('手机提示音').fontSize(16).fontColor(RING_THEME.ink).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.settings.phoneSound }).selectedColor(RING_THEME.primary).enabled(!this.busy)
              .onChange((enabled: boolean) => this.settings = setReadingSound(this.settings, enabled))
          }.width('100%').constraintSize({ minHeight: 52 })
          Row() {
            Text('减少动态效果').fontSize(16).fontColor(RING_THEME.ink).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.settings.reduceMotion }).selectedColor(RING_THEME.primary).enabled(!this.busy)
              .onChange((enabled: boolean) => this.settings = setReadingMotion(this.settings, enabled))
          }.width('100%').constraintSize({ minHeight: 52 })
        }.width('100%').padding(12).backgroundColor(Color.White).borderRadius(18)
        Button('预览提醒效果').width('100%').height(52).backgroundColor(RING_THEME.primary).enabled(!this.busy)
          .onClick(() => personalReadingReminders.preview(this.settings.phoneSound, this.settings.reduceMotion)).id('reading-preview')
        if (this.snapshot.connected && this.snapshot.capabilities.healthReminder) {
          Button('久坐与日常提醒').width('100%').height(48).fontColor(RING_THEME.primary).backgroundColor(Color.White)
            .onClick(() => this.onDailySettings())
        }
        Button(this.details ? '收起说明' : '查看提醒说明').fontColor(RING_THEME.primary).backgroundColor(Color.Transparent).onClick(() => this.details = !this.details)
        if (this.details) {
          Text('默认关闭。起始参考仅用于设置示例，不是医疗判断标准，请按个人情况调整；仅比较本次完成且有效的测量，不代表连续监测。历史同步、预览和未知数据不会产生真实提醒。HRV与皮温使用同一戒指的个人参考变化，不代表疲劳诊断或发热诊断。确认提醒仅表示已知晓，不表示读数恢复。如有不适请联系医疗服务，不要等待提醒。').fontSize(13).fontColor(RING_THEME.muted)
          Text('提示音遵循手机静音及通知音量设置，预览不会创建健康记录。').fontSize(13).fontColor(RING_THEME.muted)
        }
      }
      Text('活动目标').fontSize(18).fontWeight(FontWeight.Bold).fontColor(RING_THEME.ink).width('100%')
      Column() {
        this.NumberField('步数（步）', 'stepGoal')
        this.NumberField('距离（公里）', 'distanceGoal')
        this.NumberField('热量（千卡）', 'calorieGoal')
      }.width('100%').padding(12).backgroundColor(Color.White).borderRadius(18)
      if (this.message) Text(this.message).fontSize(14).fontColor(RING_THEME.primary).width('100%')
      Button(this.busy ? '请稍候…' : '保存设置').width('100%').height(52).backgroundColor(RING_THEME.primary).enabled(!this.busy)
        .onClick(() => this.save()).id('reading-save')
      if (!this.activityOnly && this.events.length) {
        Text('个人提醒记录').fontSize(18).fontWeight(FontWeight.Bold).fontColor(RING_THEME.ink).width('100%')
        ForEach(this.events, (event: PersonalReadingEvent) => {
          Column({ space: 5 }) {
            Text(readingRuleTitle(event.rule)).fontSize(16).fontWeight(FontWeight.Medium)
            Text(`${event.value} ${event.unit}`).fontSize(18).fontColor(RING_THEME.primary)
            Text(new Date(event.measuredAt).toLocaleString()).fontSize(12).fontColor(RING_THEME.muted)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(Color.White).borderRadius(14)
        }, (event: PersonalReadingEvent) => event.id)
      }
    }.width('100%').padding({ top: 8, bottom: 24 })
  }
}

@Component
export struct PersonalReadingOverlay {
  @Prop notice: ReadingNotice = { token: 0, preview: true, reduceMotion: true, phoneSound: false };
  @State private beat: number = 1;
  @State private muted: boolean = false;
  private timer: number = -1;
  aboutToAppear(): void {
    if (!this.notice.reduceMotion) this.timer = setInterval(() => this.beat = this.beat === 1 ? 1.12 : 1, 550);
  }
  aboutToDisappear(): void { if (this.timer !== -1) clearInterval(this.timer); this.timer = -1; personalReadingReminders.mute(this.notice.token); }
  build() {
    Column({ space: 18 }) {
      Text(this.notice.preview ? '效果预览' : '个人读数提醒').fontSize(23).fontWeight(FontWeight.Bold).fontColor(Color.White)
      Blank()
      SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(100).fontColor([Color.White]).scale({ x: this.beat, y: this.beat })
        .animation({ duration: this.notice.reduceMotion ? 0 : 450, curve: Curve.EaseInOut })
      Text(this.notice.preview ? '这里展示提醒的声音与动画效果' : readingRuleTitle(this.notice.event?.rule ?? 'high'))
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White).textAlign(TextAlign.Center)
      if (this.notice.event) Text(`${this.notice.event.value} ${this.notice.event.unit}`).fontSize(40).fontWeight(FontWeight.Bold).fontColor(Color.White)
      Text(this.notice.preview ? '不会产生真实健康提醒或健康记录' : '请适当休息并重新测量。如有不适，请及时联系医疗服务。')
        .fontSize(15).fontColor('#F6DEE0').textAlign(TextAlign.Center)
      Blank()
      Button(this.muted ? '已静音' : '本次静音').width('100%').height(50).fontColor(Color.White).backgroundColor('#6F1521')
        .onClick(() => { this.muted = true; personalReadingReminders.mute(this.notice.token); })
      Button(this.notice.preview ? '结束预览' : '我已知晓').width('100%').height(52).fontColor('#8F1D2C').backgroundColor(Color.White)
        .onClick(() => personalReadingReminders.dismiss(this.notice.token)).id('reading-dismiss')
    }.width('100%').height('100%').padding(26).backgroundColor('#8F1D2C').alignItems(HorizontalAlign.Center)
      .onVisibleAreaChange([0.5], (visible: boolean) => { if (visible) personalReadingReminders.noticeVisible(this.notice.token); else personalReadingReminders.mute(this.notice.token); })
  }
}
