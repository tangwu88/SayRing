import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { HomeCardLayout, parseHomeCardLayout } from '../model/RingParity';

export class HomeCardPreferenceStore {
  private store: preferences.Preferences | undefined = undefined;
  async read(context: common.UIAbilityContext, owner: string): Promise<HomeCardLayout> {
    this.store = await preferences.getPreferences(context, { name: 'say_ring_home_cards_v1' });
    const raw = await this.store.get(`cards.${encodeURIComponent(owner || 'guest')}`, '{}') as string;
    try { return parseHomeCardLayout(JSON.parse(raw) as Object); } catch { return { order: [], hidden: [] }; }
  }
  async save(owner: string, value: HomeCardLayout): Promise<void> {
    if (!this.store) throw new Error('卡片设置尚未读取，请重试');
    await this.store.put(`cards.${encodeURIComponent(owner || 'guest')}`, JSON.stringify(parseHomeCardLayout(value)));
    await this.store.flush();
  }
}
export const homeCardPreferenceStore: HomeCardPreferenceStore = new HomeCardPreferenceStore();
