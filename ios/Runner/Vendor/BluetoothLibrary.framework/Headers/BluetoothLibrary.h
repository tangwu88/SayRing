//
//  BluetoothLibrary.h
//  BluetoothLibrary
//
//  Created by coolwear0808 on 2025/7/24.
//

#import <Foundation/Foundation.h>

//! Project version number for BluetoothLibrary.
FOUNDATION_EXPORT double BluetoothLibraryVersionNumber;

//! Project version string for BluetoothLibrary.
FOUNDATION_EXPORT const unsigned char BluetoothLibraryVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <BluetoothLibrary/PublicHeader.h>



#import <BluetoothLibrary/FuncType.h>
#import <BluetoothLibrary/SearchPeripheral.h>
#import <BluetoothLibrary/CEProduct.h>
#import <BluetoothLibrary/CEProductK6.h>

/** Command */

#import <BluetoothLibrary/CE_SyncPairOKCmd.h>
#import <BluetoothLibrary/CE_SystemPairCmd.h>
#import <BluetoothLibrary/CE_SensorCmd.h>
#import <BluetoothLibrary/CE_AppExitCmd.h>
#import <BluetoothLibrary/CE_RequestSystemPairStatusCmd.h>
#import <BluetoothLibrary/CE_RequestOTAStatusCmd.h>
#import <BluetoothLibrary/CE_RequestUserInfo.h>
#import <BluetoothLibrary/CE_RequestDevInfoCmd.h>
#import <BluetoothLibrary/CE_RequestBatteryCmd.h>
#import <BluetoothLibrary/CE_RequestAlarmInfoCmd.h>
#import <BluetoothLibrary/CE_RequestAllInfoCmd.h>
#import <BluetoothLibrary/CE_RequestSettingButtonFunCmd.h>
#import <BluetoothLibrary/CE_RequestLongSitCmd.h>
#import <BluetoothLibrary/CE_RequestDisturbCmd.h>
#import <BluetoothLibrary/CE_RequestGoalCmd.h>
#import <BluetoothLibrary/CE_RequestBloodPresureCmd.h>
#import <BluetoothLibrary/CE_RequestExerciseStatusCmd.h>
#import <BluetoothLibrary/CE_SyncUserInfoCmd.h>
#import <BluetoothLibrary/CE_SyncSettingK6Cmd.h>
#import <BluetoothLibrary/CE_SyncAlarmK6Cmd.h>
#import <BluetoothLibrary/CE_SyncTimeCmd.h>
#import <BluetoothLibrary/CE_UnitSettingCmd.h>
#import <BluetoothLibrary/CE_SyncWeatherCmd.h>
#import <BluetoothLibrary/CE_SyncHybridCmd.h>
#import <BluetoothLibrary/CE_SendPhotoCmd.h>
#import <BluetoothLibrary/CE_SyncGoalCmd.h>
#import <BluetoothLibrary/CE_SyncWatchMenuCmd.h>
#import <BluetoothLibrary/CE_SendOtaDataCmd.h>
#import <BluetoothLibrary/CE_SendMotionCmd.h>
#import <BluetoothLibrary/CE_SyncMusicInfoCmd.h>
#import <BluetoothLibrary/CE_SyncGpsArgumentCmd.h>
#import <BluetoothLibrary/CE_SyncLongSitRemindCmd.h>
#import <BluetoothLibrary/CE_SyncPhoneControlCmd.h>
#import <BluetoothLibrary/CE_SyncDisturbCmd.h>
#import <BluetoothLibrary/YD_SyncSMSAlarmCmd.h>
#import <BluetoothLibrary/YD_SyncCallAlarmCmd.h>
#import <BluetoothLibrary/YD_SyncFinishGoalCmd.h>
#import <BluetoothLibrary/YD_SyncDrinkAlarmCmd.h>
#import <BluetoothLibrary/YD_SyncUpBrightCmd.h>
#import <BluetoothLibrary/YD_SyncAutoHeartCmd.h>
#import <BluetoothLibrary/YD_SyncFindDevCmd.h>
#import <BluetoothLibrary/YD_SyncLanguageCmd.h>
#import <BluetoothLibrary/CE_SyncHeartO2Cmd.h>
#import <BluetoothLibrary/CE_SyncECGCmd.h>
#import <BluetoothLibrary/CE_SyncBloodPressureCmd.h>
#import <BluetoothLibrary/CE_SyncUserInfoCmd.h>
#import <BluetoothLibrary/CE_SyncGoalCmd.h>

#import <BluetoothLibrary/CE_SyncWeatherCmd518.h>
#import <BluetoothLibrary/CE_SyncSwimPoolLenCmd.h>
#import <BluetoothLibrary/CE_SyncWatchFaceCmd.h>
#import <BluetoothLibrary/CE_SendGPSDataCmd.h>
#import <BluetoothLibrary/YD_SyncSportCmd.h>
#import <BluetoothLibrary/CE_SyncHeartRatePPGCmd.h>
#import <BluetoothLibrary/CE_SyncGsensorRawCmd.h>
#import <BluetoothLibrary/CE_SyncResetCmd.h>
#import <BluetoothLibrary/CE_SyncExerciseCmd.h>
#import <BluetoothLibrary/CE_SyncMenstrualCycleCmd.h>
#import <BluetoothLibrary/CE_SyncWearControlCmd.h>

#import <BluetoothLibrary/CE_SyncWatchFaceStartCmd.h>
#import <BluetoothLibrary/CE_SyncSystemFaceDataCmd.h>

#import <BluetoothLibrary/CE_SyncContactCmd.h>
#import <BluetoothLibrary/CE_SyncHeartRateCmd.h>
#import <BluetoothLibrary/CE_RequestEdrInfoCmd.h>
#import <BluetoothLibrary/CE_SyncQRCmd.h>
#import <BluetoothLibrary/CE_SyncPhotoDialCmd.h>
#import <BluetoothLibrary/CE_DeleteImageCmd.h>
#import <BluetoothLibrary/CE_SyncOnoffScreenCmd.h>
#import <BluetoothLibrary/CE_SyncAlipayData.h>
#import <BluetoothLibrary/CE_SyncHRVCmd.h>
#import <BluetoothLibrary/CE_SyncRRIHRVCmd.h>
#import <BluetoothLibrary/CE_ClearDataCmd.h>
#import <BluetoothLibrary/CE_CloseCmd.h>
#import <BluetoothLibrary/AppleHealthCenter.h>
#import <BluetoothLibrary/CE_ProductProtocol.h>
#import <BluetoothLibrary/CE_ExternWeatherCmd.h>
#import <BluetoothLibrary/CE_GestureCmd.h>
#import <BluetoothLibrary/CE_K6Protocol.h>
#import <BluetoothLibrary/CE_LocationInfoCdm.h>
#import <BluetoothLibrary/CE_RemovePhotoAlbumImageCmd.h>
#import <BluetoothLibrary/CECharacteristicManager.h>
#import <BluetoothLibrary/CEDataParser.h>
#import <BluetoothLibrary/CEReceiveObj.h>
#import <BluetoothLibrary/CESendObj.h>
#import <BluetoothLibrary/ContactParser.h>
#import <BluetoothLibrary/DataStruct.h>
#import <BluetoothLibrary/Filter.h>
#import <BluetoothLibrary/ImageColorConvertHelper.h>
#import <BluetoothLibrary/YD_RequestCleanData.h>
