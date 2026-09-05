import { AbilityStage } from '@kit.AbilityKit';
import { prepareJPush } from '../services/HarmonyPushService';

export default class EntryAbilityStage extends AbilityStage {
  onCreate(): void {
    prepareJPush(this.context);
  }
}
