import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DisplayUnits, parseDisplayUnits } from '../model/DisplayPreferences';

// Display preferences only. Original health records and watch units are never rewritten.
export class DisplayPreferenceStore {
  private store: preferences.Preferences | undefined = undefined;
  private pending: Promise<void> = Promise.resolve();

  async read(context: common.UIAbilityContext): Promise<DisplayUnits> {
    this.store = await preferences.getPreferences(context, { name: 'saydian_display_units' });
    const distance = await this.store.get('distance', 'km') as string;
    const temperature = await this.store.get('temperature', 'c') as string;
    return parseDisplayUnits(distance, temperature);
  }

  async save(value: DisplayUnits): Promise<void> {
    const store = this.store;
    if (!store) throw new Error('设置尚未读取，请稍后再试');
    const operation = this.pending.catch(() => {}).then(async () => {
      await store.put('distance', value.distance);
      await store.put('temperature', value.temperature);
      await store.flush();
    });
    this.pending = operation;
    await operation;
  }
}

export const displayPreferenceStore: DisplayPreferenceStore = new DisplayPreferenceStore();
