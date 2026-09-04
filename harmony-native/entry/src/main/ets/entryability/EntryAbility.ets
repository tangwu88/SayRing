import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    stage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(0x0100, 'SaydianHarmony', 'Page load failed: %{public}d', error.code);
      } else {
        hilog.info(0x0100, 'SaydianHarmony', 'Native login and home ready');
      }
    });
  }
}
