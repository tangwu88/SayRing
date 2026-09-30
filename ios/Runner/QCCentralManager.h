//
//  QCCentralManager.h
//  QCBandSDKDemo
//
//  Created by steve on 2023/2/28.
//
//  Demo BLE central wrapper: scan / connect / bind / reconnect.
//  演示用蓝牙中心封装：扫描、连接、绑定、重连。
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

/// Device category used when connecting (ANCS option differs for rings).
/// 连接时的设备类型（戒指与手表的 ANCS 参数不同）。
typedef NS_ENUM(NSInteger, QCDeviceType) {
    QCDeviceTypeUnkown = 0, ///< Unknown. 未知
    QCDeviceTypeWatch,      ///< Watch / band. 手表 / 手环
    QCDeviceTypeRing        ///< Ring. 戒指
};

/// Connection / bind state reported to the UI.
/// 上报给界面的连接与绑定状态。
typedef NS_ENUM(NSInteger, QCState) {
    QCStateUnkown = 0,      ///< Unknown. 未知
    QCStateUnbind,          ///< No locally bound device. 本地未绑定设备
    QCStateConnecting,      ///< Connecting or auto-reconnecting. 正在连接或自动重连
    QCStateConnected,       ///< Connected and registered with the SDK. 已连接并完成 SDK 注册
    QCStateDisconnecting,   ///< Disconnect / unbind in progress. 正在断开或解绑
    QCStateDisconnected,    ///< Bound but currently disconnected. 已绑定但当前断开
};

/// System Bluetooth adapter state.
/// 系统蓝牙适配器状态。
typedef NS_ENUM(NSInteger, QCBluetoothState) {
    QCBluetoothStateUnkown = 0,         ///< Unknown. 未知
    QCBluetoothStateResetting,          ///< Resetting. 重置中
    QCBluetoothStateUnsupported,        ///< BLE unsupported. 不支持蓝牙
    QCBluetoothStateUnauthorized,       ///< No permission. 无权限
    QCBluetoothStatePoweredOff,         ///< Bluetooth off. 蓝牙关闭
    QCBluetoothStatePoweredOn,          ///< Bluetooth on. 蓝牙开启
};

/// One scanned (or already-paired) peripheral for the scan list.
/// 扫描列表中的一台设备（含系统已配对设备）。
@interface QCBlePeripheral : NSObject

@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, copy) NSString *mac; ///< MAC from advertisement when available. 广播里能解析到的 MAC
@property (nonatomic, strong) NSDictionary<NSString *,id> *advertisementData;
@property (nonatomic, strong) NSNumber *RSSI;
@property (nonatomic, assign) BOOL isPaired; ///< Already connected at system level. 系统层已连接/已配对

@end

@protocol QCCentralManagerDelegate <NSObject>

@optional

/// Device bind/connect state changed. 设备绑定/连接状态变化
- (void)didState:(QCState)state;

/// System Bluetooth state changed. 系统蓝牙开关状态变化
- (void)didBluetoothState:(QCBluetoothState)state;

/// Scan list updated (sorted by RSSI, strongest first). 扫描列表更新（按信号从强到弱）
- (void)didScanPeripherals:(NSArray <QCBlePeripheral*>*)peripheralArr;

/// Scan timeout finished. 扫描超时结束
- (void)scanPeripheralFinish;

/// Connect failed or timed out. 连接失败或超时
- (void)didFailConnected:(CBPeripheral *)peripheral error:(nullable NSError*)error;

@end

@interface QCCentralManager : NSObject

@property (nonatomic, weak) id<QCCentralManagerDelegate> delegate;

/// The host owns environment-scoped identity and recovery. Do not adopt the
/// demo's installation-wide saved UUID or independently reconnect it.
@property (nonatomic, assign) BOOL appManagedConnections;

@property (strong, nonatomic, readonly) CBCentralManager *centerManager;

@property (strong, nonatomic, readonly) CBPeripheral *connectedPeripheral;

@property (nonatomic, assign, readonly) QCState deviceState;

@property (nonatomic, assign, readonly) QCBluetoothState bleState;

/// Whether a scan session is currently active. 当前是否正在扫描
@property (nonatomic, assign, readonly) BOOL isScanning;

+ (instancetype)shared;

/// Scan devices. Default timeout 30s. 扫描设备，默认超时 30 秒
- (void)scan;

/// Scan devices with a custom timeout.
/// 按指定超时扫描设备。
/// @param timeout Seconds; `<= 0` falls back to 30s. 秒；`<= 0` 时回退为 30 秒
- (void)scanWithTimeout:(NSInteger)timeout;

/// Stop scanning. 停止扫描
- (void)stopScan;

/// Connect as a ring (timeout 6s). 按戒指类型连接（超时 6 秒）
/// @param peripheral Target peripheral. 目标设备
- (void)connect:(CBPeripheral *)peripheral;

/// Connect with an explicit device type (timeout 6s). 指定设备类型连接（超时 6 秒）
/// @param peripheral Target peripheral. 目标设备
/// @param deviceType Watch vs ring (ANCS). 手表/戒指（影响 ANCS）
- (void)connect:(CBPeripheral *)peripheral deviceType:(QCDeviceType)deviceType;

/// Connect as a ring with a custom timeout. 按戒指类型连接，可指定超时
/// @param peripheral Target peripheral. 目标设备
/// @param timeout Seconds; `<= 0` falls back to 6s. 秒；`<= 0` 时回退为 6 秒
- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout;

/// Connect with timeout and device type. 指定超时与设备类型连接
/// @param peripheral Target peripheral. 目标设备
/// @param timeout Seconds; `<= 0` falls back to 6s. 秒；`<= 0` 时回退为 6 秒
/// @param deviceType Default is `QCDeviceTypeRing`. 默认按戒指处理
- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout deviceType:(QCDeviceType)deviceType;

/// Unbind: clear local UUID and disconnect. 解绑：清除本地 UUID 并断开
- (void)remove;

/// Disconnect without unbinding. Auto-reconnect stays off until `connect:` / `reconnectLastDevice`.
/// 仅断开、不解绑。在再次 `connect:` / `reconnectLastDevice` 前不会自动重连。
- (void)disconnect;

/// Reconnect the last bound device without scanning. 不扫描，重连上次绑定的设备
- (void)reconnectLastDevice;

/// Whether a device UUID is saved locally. 本地是否已保存绑定设备 UUID
- (BOOL)isBindDevice;

@end

NS_ASSUME_NONNULL_END
