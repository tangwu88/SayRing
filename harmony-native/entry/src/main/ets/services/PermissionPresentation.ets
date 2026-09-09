import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { deviceInfo } from '@kit.BasicServicesKit';

export interface PermissionRow { key: string; title: string; status: string; enabled: boolean; }

export async function readPermissionRows(): Promise<PermissionRow[]> {
  const manager = abilityAccessCtrl.createAtManager();
  const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
  const tokenId = info.appInfo.accessTokenId;
  const bluetooth = manager.checkAccessTokenSync(tokenId, 'ohos.permission.ACCESS_BLUETOOTH') === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  const location = manager.checkAccessTokenSync(tokenId, 'ohos.permission.APPROXIMATELY_LOCATION') === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  const camera = manager.checkAccessTokenSync(tokenId, 'ohos.permission.CAMERA') === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  const notifications = await notificationManager.isNotificationEnabled();
  return [
    { key: 'bluetooth', title: '蓝牙', status: bluetooth ? '已允许' : '未允许', enabled: bluetooth },
    { key: 'location', title: '位置', status: location ? '已允许' : '未允许', enabled: location },
    { key: 'camera', title: '相机', status: camera ? '已允许' : '按需使用', enabled: camera },
    { key: 'notifications', title: '通知', status: notifications ? '已允许' : '未允许', enabled: notifications }
  ];
}

export async function openPermissionSetting(context: common.UIAbilityContext, key: string): Promise<void> {
  if (key === 'notifications') {
    if (deviceInfo.sdkApiVersion >= 13) {
      try { await notificationManager.openNotificationSettings(context); return; } catch {}
    }
    try {
      await context.startAbility({
        action: 'action.settings.app.info',
        parameters: { settingsParamBundleName: context.applicationInfo.name }
      });
    } catch {
      throw new Error('请在系统设置中打开赛电的通知权限');
    }
    return;
  }
  const permissions: Permissions[] = key === 'bluetooth' ? ['ohos.permission.ACCESS_BLUETOOTH'] :
    key === 'camera' ? ['ohos.permission.CAMERA'] : ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
  const manager = abilityAccessCtrl.createAtManager();
  const result = await manager.requestPermissionsFromUser(context, permissions);
  if (result.authResults.some((state: number) => state !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED)) {
    await manager.requestPermissionOnSetting(context, permissions);
  }
}
