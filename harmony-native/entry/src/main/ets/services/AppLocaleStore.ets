import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { normalizeAppLocale, setAppLocale } from '../model/GlobalLocale';

export class AppLocaleStore {
  private store: preferences.Preferences | undefined = undefined;
  async read(context: common.UIAbilityContext): Promise<string> {
    this.store = await preferences.getPreferences(context, { name: 'saydian_global_preferences' });
    const locale = normalizeAppLocale(await this.store.get('locale', 'en') as string);
    setAppLocale(locale);
    return locale;
  }
  async save(locale: string): Promise<void> {
    if (!this.store) throw new Error('Settings are not ready. Please retry.');
    const normalized = normalizeAppLocale(locale);
    await this.store.put('locale', normalized);
    await this.store.flush();
    setAppLocale(normalized);
  }
}
export const appLocaleStore: AppLocaleStore = new AppLocaleStore();
