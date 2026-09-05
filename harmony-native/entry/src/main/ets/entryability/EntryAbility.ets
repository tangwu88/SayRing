import { UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { captureJPushClick } from '../services/HarmonyPushService';
import { captureNotificationRoute, initializeNotificationNavigation } from '../services/NotificationNavigation';
import { isPaymentCallbackExpected, setPaymentCallbackExpected } from '../services/PaymentLaunchState';
import { LogLevel, VPBleSDK } from '@veepoo/vpble-sdk';
import { vepWearable } from '../services/VepWearableService';
import { initializeWechatAuthState, wechatAuth } from '../services/WechatAuthService';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want): void {
    initializeNotificationNavigation();
    initializeWechatAuthState();
    wechatAuth.attachContext(this.context);
    wechatAuth.handleWant(want);
    captureJPushClick(want, this.context.getApplicationContext());
    captureNotificationRoute(want);
  }

  onNewWant(want: Want): void {
    wechatAuth.handleWant(want);
    captureJPushClick(want, this.context.getApplicationContext());
    captureNotificationRoute(want);
    this.handlePaymentWant(want);
  }

  private async handlePaymentWant(want: Want): Promise<void> {
    if (!isPaymentCallbackExpected()) return;
    try {
      const paymentModule = await import('../services/HarmonyPaymentService');
      paymentModule.handleHarmonyPaymentCallback(want);
    } catch {
      setPaymentCallbackExpected(false);
    }
  }

  onWindowStageCreate(stage: window.WindowStage): void {
    wechatAuth.attachContext(this.context);
    VPBleSDK.getInstance().init({
      context: this.context,
      debugMode: false,
      logging: { enable: true, level: LogLevel.INFO, consoleOutput: false }
    });
    vepWearable.attachContext(this.context);
    stage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(0x0100, 'SaydianHarmony', 'Page load failed: %{public}d', error.code);
      } else {
        hilog.info(0x0100, 'SaydianHarmony', 'Native login and home ready');
      }
    });
  }

  onWindowStageDestroy(): void {
    vepWearable.shutdown();
  }
}
