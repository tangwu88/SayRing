//
//  QCCentralManager.m
//  QCBandSDKDemo
//
//  Created by steve on 2023/2/28.
//
//  Demo BLE central: scan, connect, bind UUID locally, auto-reconnect.
//  演示用蓝牙中心：扫描、连接、本地保存绑定 UUID、自动重连。
//

#import "QCCentralManager.h"
#import <QCBandSDK/QCSDKManager.h>

/// UserDefaults key for the last bound peripheral UUID. 上次绑定设备 UUID 的本地存储 key
static NSString *const QCLastConnectedIdentifier = @"QCLastConnectedIdentifier";
/// Default scan timeout (seconds). 默认扫描超时（秒）
static NSInteger const QCBleDefaultTimeout = 15;
/// Default connect timeout (seconds). 默认连接超时（秒）
static NSInteger const QCBleDefaultConnectTimeout = 6;
@implementation QCBlePeripheral


@end

@interface QCCentralManager()<CBCentralManagerDelegate>

/// System BLE central. 系统蓝牙中心（App 作为 Central）
@property (strong, nonatomic) CBCentralManager *centerManager;

/// Current scan results. 当前扫描结果列表
@property (strong, nonatomic) NSMutableArray<QCBlePeripheral *> *peripherals;

@property (strong, nonatomic) CBPeripheral *connectedPeripheral;

@property (nonatomic,copy) void(^connectCompletedHandle)(BOOL);

/// Shared timer: scan timeout or connect retry. 共用定时器：扫描超时或连接重试
@property (nonatomic,strong)NSTimer *reconTimer;

@property (assign,nonatomic)QCDeviceType deviceType;

@property (nonatomic,assign)QCState deviceState;

@property (nonatomic,assign)QCBluetoothState bleState;

@property (nonatomic,assign) NSInteger scanTimeout;

@property (nonatomic,assign) NSInteger connectTimeout;

/// YES after `disconnect` / `remove` until the next explicit connect. 主动断开/解绑后为 YES，直到下次主动连接
@property (nonatomic, assign) BOOL suppressAutoReconnect;
@property (nonatomic, assign, readwrite) BOOL isScanning;
@end

@implementation QCCentralManager

+ (instancetype)shared {
    static QCCentralManager * instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[QCCentralManager alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 // Alert when Bluetooth is off. 蓝牙未开启时弹出系统提示
                                 [NSNumber numberWithBool:YES],CBCentralManagerOptionShowPowerAlertKey,
                                 [NSNumber numberWithBool:YES],CBConnectPeripheralOptionNotifyOnConnectionKey,
                                 // Restore identifier after app relaunch. App 被系统杀掉后用于恢复中心管理器
                                 @"QCWXBluetoothRestore",CBCentralManagerOptionRestoreIdentifierKey,
                                 nil];

        _centerManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:options];
        _peripherals = [[NSMutableArray alloc] init];
        _scanTimeout = QCBleDefaultTimeout;
        _connectTimeout = QCBleDefaultTimeout;
    }
    return self;
}

#pragma mark - Params
- (void)setScanTimeout:(NSInteger)scanTimeout {
    if(scanTimeout >= 0) {
        _scanTimeout = scanTimeout;
    }
    else {
        _scanTimeout = QCBleDefaultTimeout;
    }
}

- (void)setConnectTimeout:(NSInteger)connectTimeout {
    if(connectTimeout >= 0) {
        _connectTimeout = connectTimeout;
    }
    else {
        _connectTimeout = QCBleDefaultConnectTimeout;
    }
}

- (void)setDeviceState:(QCState)deviceState {
    _deviceState = deviceState;
    // Forward to UI. 同步给界面
    if(self.delegate && [self.delegate respondsToSelector:@selector(didState:)]) {
        [self.delegate didState:self.deviceState];
    }
}

#pragma mark - Public

- (void)scan; {
    [self scanWithTimeout:QCBleDefaultTimeout];
}

- (void)scanWithTimeout:(NSInteger)timeout {
    self.scanTimeout = timeout;

    [self stopScan];
    [self.peripherals removeAllObjects];
    self.isScanning = YES;

    // Include devices already connected at the system layer. 先带上系统层已连接的设备
    NSArray <CBUUID*>*uuids = @[[CBUUID UUIDWithString:QCBANDSDKSERVERUUID1],[CBUUID UUIDWithString:QCBANDSDKSERVERUUID2]];
    NSArray *connectedP = [self retrieveConnectPeripheral:uuids];
    NSMutableArray * tempAray = [[NSMutableArray alloc] init];
    for (CBPeripheral *per in connectedP) {
        QCBlePeripheral *qcPer = [[QCBlePeripheral alloc] init];
        qcPer.peripheral = per;
        // System-paired devices do not expose MAC in ads; read it via SDK after connect.
        // 系统已配对设备无法从广播读 MAC，连接成功后再发指令读取。
        qcPer.mac = @"";
        qcPer.isPaired = YES;
        [tempAray addObject:qcPer];
    }

    [self.peripherals addObjectsFromArray:tempAray];

    if([connectedP count] > 0) {
        [self.peripherals sortUsingComparator:^NSComparisonResult(QCBlePeripheral *obj1, QCBlePeripheral *obj2) {
            return NSOrderedSame;
        }];
        if(self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripherals:)]) {
            [self.delegate didScanPeripherals:self.peripherals];
        }
    }

    NSDictionary *option = @{CBCentralManagerScanOptionAllowDuplicatesKey : [NSNumber numberWithBool:NO]};
    [_centerManager scanForPeripheralsWithServices:nil options:option];

    [self stopTimer];
    self.reconTimer = [NSTimer scheduledTimerWithTimeInterval:self.scanTimeout target:self selector:@selector(stopScanFinishTimer:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop]addTimer:self.reconTimer forMode: NSRunLoopCommonModes];
}

- (void)stopScan {

    if (!_centerManager) {
        return;
    }
    [_centerManager stopScan];
    self.isScanning = NO;
}

- (void)connect:(CBPeripheral *)peripheral {
    [self connect:peripheral deviceType:QCDeviceTypeRing];
}

- (void)connect:(CBPeripheral *)peripheral deviceType:(QCDeviceType)deviceType {
    [self connect:peripheral timeout:QCBleDefaultConnectTimeout deviceType:deviceType];
}

- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout {
    [self connect:peripheral timeout:timeout deviceType:QCDeviceTypeRing];
}

- (void)connect:(CBPeripheral *)peripheral timeout:(NSInteger)timeout deviceType:(QCDeviceType)deviceType {
    if (!peripheral) {
        return;
    }

    [self stopScan];
    [self stopTimer];
    self.connectTimeout = timeout;
    self.suppressAutoReconnect = NO;
    self.deviceType = deviceType;
    self.connectedPeripheral = peripheral;
    [[QCSDKManager shareInstance] removeAllPeripheral];
    self.deviceState = QCStateConnecting;

    // Already connected at CoreBluetooth layer: just register with QCSDK.
    // 系统层已连接：只需向 QCSDK 注册外设。
    if (peripheral.state == CBPeripheralStateConnected) {
        [self registerConnectedPeripheral:peripheral];
        return;
    }

    // Connecting: wait / retry via timer. 正在连接：用定时器等待或重试
    if (peripheral.state == CBPeripheralStateConnecting) {
        [self scheduleConnectRetryTimer];
        return;
    }

    [self connectCurrentPeripheral];
    [self scheduleConnectRetryTimer];
}

/// Reconnect the UUID saved in UserDefaults. 用本地保存的 UUID 重连上次绑定设备
- (void)reconnectLastDevice {
    if (![self isBindDevice]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
            [self.delegate didFailConnected:nil error:[NSError errorWithDomain:@"QCCentralManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No bound device"}]];
        }
        return;
    }

    CBPeripheral *peripheral = [self lastPeripheral];
    if (!peripheral) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
            [self.delegate didFailConnected:nil error:[NSError errorWithDomain:@"QCCentralManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Bound device not found, please scan"}]];
        }
        return;
    }

    [self connect:peripheral];
}

/// Issue CoreBluetooth `connectPeripheral`. 向系统发起 `connectPeripheral`
- (void)connectCurrentPeripheral {

    CBPeripheral *lastPer = [self lastPeripheral];
    if (!lastPer) {
        return;
    }
    NSLog(@"connect device:%@",lastPer);
    NSDictionary *options = [NSMutableDictionary new];
    [options setValue:@(YES) forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey];
    if (@available(iOS 13.0, *)) {
        [options setValue:@(YES) forKey:CBConnectPeripheralOptionEnableTransportBridgingKey];
        if (self.deviceType != QCDeviceTypeRing) {
            // Watch/band needs ANCS; without this the App cannot observe ANCS status.
            // 手表/手环需要 ANCS；不设此项 App 无法监听 ANCS 准确状态。
            [options setValue:@(YES) forKey:CBConnectPeripheralOptionRequiresANCS];
        }
    }

    [_centerManager connectPeripheral:lastPer options:options];
}

/// Unbind: drop saved UUID and cancel the BLE connection. 解绑：清除本地 UUID 并取消 BLE 连接
- (void)remove {
    [self stopScan];
    [self stopTimer];
    self.suppressAutoReconnect = YES;

    [[QCSDKManager shareInstance] removeAllPeripheral];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:QCLastConnectedIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];

    CBPeripheral *peripheral = self.connectedPeripheral ?: [self lastPeripheral];
    self.connectedPeripheral = nil;

    if (peripheral.state == CBPeripheralStateConnected || peripheral.state == CBPeripheralStateConnecting) {
        @try {
            [_centerManager cancelPeripheralConnection:peripheral];
        } @catch (NSException *e) {
            NSLog(@"warn: 取消设备(%@)连接时出现异常", peripheral.name);
        }
        self.deviceState = QCStateDisconnecting;
    } else {
        self.suppressAutoReconnect = NO;
        self.deviceState = QCStateUnbind;
    }
}

/// Disconnect but keep the bound UUID. 仅断开连接，保留绑定 UUID
- (void)disconnect {
    [self stopScan];
    [self stopTimer];
    self.suppressAutoReconnect = YES;
    [[QCSDKManager shareInstance] removeAllPeripheral];

    CBPeripheral *peripheral = self.connectedPeripheral ?: [self lastPeripheral];
    if (peripheral.state == CBPeripheralStateConnected || peripheral.state == CBPeripheralStateConnecting) {
        @try {
            [_centerManager cancelPeripheralConnection:peripheral];
        } @catch (NSException *e) {
            NSLog(@"warn: 断开设备(%@)连接时出现异常", peripheral.name);
        }
        self.deviceState = QCStateDisconnecting;
    } else {
        self.suppressAutoReconnect = NO;
        self.deviceState = QCStateDisconnected;
    }
}


/// Auto-reconnect when Bluetooth is on and a bound UUID exists. 蓝牙开启且已绑定 UUID 时自动重连
- (void)startToReconnect{

    if (self.bleState != QCBluetoothStatePoweredOn) {
        if(self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
            [self.delegate didFailConnected:self.connectedPeripheral error:[NSError errorWithDomain:@"Bluetooth powered off" code:-1 userInfo:@{@"message":@"Bluetooth powered off"}]];
        }
        return;
    }

    CBPeripheral *lastPer = [self lastPeripheral];
    if(lastPer) {
        [self connect:lastPer];
    }
    else {
        if(self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
            [self.delegate didFailConnected:self.connectedPeripheral error:[NSError errorWithDomain:@"CBPeripheral not exist" code:-1 userInfo:@{@"message":@"CBPeripheral not exist"}]];
        }
    }
}

/// Current peripheral, or the one restored from the saved UUID. 当前外设；没有则用本地 UUID 还原
- (CBPeripheral*)lastPeripheral {

    if(self.connectedPeripheral) {
        return self.connectedPeripheral;
    }

    NSString *uuidStr = [[NSUserDefaults standardUserDefaults] objectForKey:QCLastConnectedIdentifier];

    if(uuidStr && uuidStr.length > 0) {
        return [self periperalWithUUID:uuidStr];
    }

    return nil;
}

/// Bound if a peripheral UUID is stored in UserDefaults. 本地存有 UUID 即视为已绑定
- (BOOL)isBindDevice {
    NSString *uuidStr = [[NSUserDefaults standardUserDefaults] objectForKey:QCLastConnectedIdentifier];
    return uuidStr.length > 0;
}

#pragma mark - Private

/// Register the peripheral with QCSDK and persist the UUID on success. 向 QCSDK 注册外设，成功后写入本地 UUID
- (void)registerConnectedPeripheral:(CBPeripheral *)peripheral {
    [[QCSDKManager shareInstance] removePeripheral:peripheral];
    [[QCSDKManager shareInstance] addPeripheral:peripheral finished:^(BOOL success) {
        [self stopTimer];
        if (success) {
            [[NSUserDefaults standardUserDefaults] setValue:peripheral.identifier.UUIDString forKey:QCLastConnectedIdentifier];
            [[NSUserDefaults standardUserDefaults] synchronize];
            self.connectedPeripheral = peripheral;
            self.deviceState = QCStateConnected;
        } else if (self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
            self.deviceState = QCStateDisconnected;
            [self.delegate didFailConnected:peripheral error:[NSError errorWithDomain:@"Connect fail" code:-1 userInfo:@{@"message":@"Connect fail"}]];
        }
    }];
}

/// Retry `connectPeripheral` every `connectTimeout` seconds. 每隔 `connectTimeout` 秒重试一次连接
- (void)scheduleConnectRetryTimer {
    self.reconTimer = [NSTimer scheduledTimerWithTimeInterval:self.connectTimeout target:self selector:@selector(connectCurrentPeripheral) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.reconTimer forMode:NSRunLoopCommonModes];
}

/// Connect failed: update state and notify the delegate. 连接失败：更新状态并回调代理
- (void)notifyConnectFailed:(CBPeripheral *)peripheral error:(NSError *)error {
    [self stopTimer];
    if (self.suppressAutoReconnect) {
        self.deviceState = [self isBindDevice] ? QCStateDisconnected : QCStateUnbind;
        self.suppressAutoReconnect = NO;
    } else if ([self isBindDevice]) {
        self.deviceState = QCStateDisconnected;
    } else {
        self.deviceState = QCStateUnbind;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
        [self.delegate didFailConnected:peripheral error:error];
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"centralManagerDidUpdateState:%ld",[central state]);
    QCBluetoothState bleState = QCBluetoothStateUnkown;

    switch([central state]) {
        case CBManagerStateUnknown:
            bleState = QCBluetoothStateUnkown;
            break;
        case CBManagerStateResetting:
            bleState = QCBluetoothStateResetting;
            break;
        case CBManagerStateUnsupported:
            bleState = QCBluetoothStateUnsupported;
            break;
        case CBManagerStatePoweredOff:
            bleState = QCBluetoothStatePoweredOff;
            break;
        case CBManagerStatePoweredOn:
            bleState = QCBluetoothStatePoweredOn;
            break;
        default:break;
    }

    self.bleState = bleState;

    if (self.delegate && [self.delegate respondsToSelector:@selector(didBluetoothState:)]) {
        [self.delegate didBluetoothState:bleState];
    }

    // User asked to disconnect: do not kick off reconnect from a Bluetooth-state callback.
    // 用户主动断开中：蓝牙状态回调里不要再触发重连。
    if (self.deviceState == QCStateDisconnecting || self.deviceState == QCStateDisconnected) {
        return;
    }

    if([self isBindDevice]) {
        self.deviceState = QCStateConnecting;
    }
    else {
        self.deviceState = QCStateUnbind;
    }

    if (bleState == QCBluetoothStatePoweredOn && self.deviceState == QCStateConnecting && !self.suppressAutoReconnect) {
        [self startToReconnect];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {

//    if(![peripheral.name.lowercaseString hasPrefix:@"o_"]) {
//        return;
//    }
    // Skip nameless ads. 忽略无名称广播
    if(peripheral.name.length == 0) return;
    NSString *mac = [self macFromAdvertisementData:advertisementData];

    NSLog(@"Devices found:%@,mac:%@,id:%@",peripheral.name,mac,peripheral.identifier.UUIDString);
    BOOL isExist = false;
    BOOL shouldNotify = NO;
    for (QCBlePeripheral *per in self.peripherals) {
        if([per.peripheral.identifier.UUIDString isEqual:peripheral.identifier.UUIDString]) {
            BOOL macUpdated = (per.mac.length == 0 && mac.length > 0);
            per.peripheral = peripheral;
            per.mac = mac.length > 0 ? mac : per.mac;
            per.advertisementData = advertisementData;
            per.RSSI = RSSI;
            isExist = true;
            shouldNotify = macUpdated;
            break;
        }
    }

    if(!isExist) {
        QCBlePeripheral *per = [[QCBlePeripheral alloc] init];
        per.peripheral = peripheral;
        per.mac = mac;
        per.advertisementData = advertisementData;
        per.RSSI = RSSI;
        [self.peripherals addObject:per];
        shouldNotify = YES;
    }

    // Only refresh UI for a new device or when MAC first becomes available.
    // 新设备，或原先没有 MAC、这次才解析到时，才刷新列表。
    if (!shouldNotify) {
        return;
    }

    // Sort by RSSI, strongest first. 按信号强度从强到弱排序
    [self.peripherals sortUsingComparator:^NSComparisonResult(QCBlePeripheral *obj1, QCBlePeripheral *obj2) {
        NSNumber *rssi1 = obj1.RSSI ?: @(-100);
        NSNumber *rssi2 = obj2.RSSI ?: @(-100);
        return [rssi2 compare:rssi1];
    }];

    if(self.delegate && [self.delegate respondsToSelector:@selector(didScanPeripherals:)]) {
        [self.delegate didScanPeripherals:self.peripherals];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connection to device (%@) succeeded", peripheral.name);
    self.connectedPeripheral = peripheral;
    [self registerConnectedPeripheral:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Connection to device (%@) failed: %@", peripheral.name, error);
    [self notifyConnectFailed:peripheral error:error];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"Device(%@)didDisconnect，err: %@", peripheral.name, error);
    [[QCSDKManager shareInstance] removeAllPeripheral];

    // Intentional disconnect / unbind: stop here, no auto-reconnect.
    // 主动断开或解绑：到此结束，不自动重连。
    if(self.deviceState == QCStateDisconnecting) {
        if ([self isBindDevice]) {
            self.deviceState = QCStateDisconnected;
        } else {
            self.connectedPeripheral = nil;
            self.deviceState = QCStateUnbind;
        }
        self.suppressAutoReconnect = NO;
        return;
    }

    if (self.suppressAutoReconnect) {
        self.suppressAutoReconnect = NO;
        self.deviceState = [self isBindDevice] ? QCStateDisconnected : QCStateUnbind;
        return;
    }

    // Unexpected drop: reconnect if still bound. 意外断开：仍绑定则自动重连
    if ([self isBindDevice]) {
        self.deviceState = QCStateConnecting;
        [self startToReconnect];
    } else {
        self.connectedPeripheral = nil;
        self.deviceState = QCStateUnbind;
    }
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict {
    NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
    if (peripherals.count > 0) {
        // Restore the last bound peripheral after the system relaunches the App.
        // 系统恢复 App 后，还原上次绑定的外设。
        NSString *uuidStr = [[NSUserDefaults standardUserDefaults] objectForKey:QCLastConnectedIdentifier];
        if (uuidStr.length > 0) {
            for (CBPeripheral* pr in peripherals) {
                if ([uuidStr isEqualToString:pr.identifier.UUIDString]) {
                    self.connectedPeripheral = pr;
                }
            }
        }
    }
}

#pragma mark - Helpers

/// Peripherals already connected at the system level for the given services.
/// 系统层已连接、且包含指定服务的外设。
- (NSArray *)retrieveConnectPeripheral:(NSArray<CBUUID *> *)uuidArray
{
    NSArray *connectedDevice = [_centerManager retrieveConnectedPeripheralsWithServices:uuidArray];
    NSMutableArray *connectedPeripheral = [NSMutableArray arrayWithCapacity:connectedDevice.count];
    [connectedDevice enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![obj isKindOfClass:[CBPeripheral class]]) {
            return;
        }
        [connectedPeripheral addObject:obj];
    }];

    return [connectedPeripheral copy];
}

/// Look up a peripheral by identifier UUID string. 按 identifier UUID 字符串查找外设
- (CBPeripheral *)periperalWithUUID:(NSString *)uuid {

    if (!uuid) {
        return nil;
    }

    NSArray *periperals = nil;
    NSUUID *UUID = [[NSUUID alloc] initWithUUIDString:uuid];
    if(!UUID){
        NSLog(@"NSUUID(%@)合法，但无法创建UUID，原因不明", uuid);
        return nil;
    }
    periperals = [_centerManager retrievePeripheralsWithIdentifiers:@[UUID]];
    if (periperals.count > 0) {
        return [periperals objectAtIndex:0];
    } else {
        return nil;
    }
}

/// Parse MAC from manufacturer or service advertisement data. 从厂商数据或服务广播里解析 MAC
- (NSString *)macFromAdvertisementData:(NSDictionary *)advertisementData {
    NSString *mac = @"";
    NSData *manufacturerData = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
    mac = [self macFromData:manufacturerData];

    if (mac.length == 0) {
        NSDictionary *serviceData = [advertisementData objectForKey:@"kCBAdvDataServiceData"];
        if ([serviceData isKindOfClass:[NSDictionary class]]) {
            NSArray *allValues = [serviceData allValues];
            if (allValues.count > 0) {
                for (NSData *dataValue in allValues) {
                    if ([dataValue isKindOfClass:[NSData class]]) {
                        mac = [self macFromData:dataValue];
                    }
                }
            }
        }
    }
    return mac;
}

/// Extract a 6-byte MAC from common advertisement payload lengths. 从常见广播长度中取出 6 字节 MAC
- (NSString*)macFromData:(NSData*)macData {
    NSString *mac = @"";
    if ([macData isKindOfClass:[NSData class]] && macData.length > 0) {
        NSData *data = macData;
        if (data.length >= 10) {
            data = [data subdataWithRange:NSMakeRange(4, 6)];
            Byte *bytes = (Byte *)data.bytes;
            mac = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
        } else if (data.length == 8) {
            data = [data subdataWithRange:NSMakeRange(2, 6)];
            Byte *bytes = (Byte *)data.bytes;
            mac = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
        } else if (data.length == 6) {
           data = [data subdataWithRange:NSMakeRange(0, 6)];
           Byte *bytes = (Byte *)data.bytes;
           mac = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                       bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
       }
    }

    return mac;
}

/// Invalidate the shared scan/connect timer. 停止扫描超时或连接重试定时器
- (void)stopTimer
{
    if ([self.reconTimer isValid]) {
        [self.reconTimer invalidate];
        self.reconTimer = nil;
    }
}

/// Unused leftover: connect timeout used to fire this. 旧逻辑残留，连接超时曾走这里
- (void)stopConnectFinishTimer:(NSTimer *)timer {

    if(self.delegate && [self.delegate respondsToSelector:@selector(didFailConnected:error:)]) {
        [self.delegate didFailConnected:self.connectedPeripheral error:[NSError errorWithDomain:@"timeout" code:-1 userInfo:@{@"message":@"connect timeout"}]];
    }
}

/// Scan timeout: stop scan and tell the delegate. 扫描超时：停止扫描并通知代理
- (void)stopScanFinishTimer:(NSTimer *)timer
{
    [self stopScan];
    if (self.delegate && [self.delegate respondsToSelector:@selector(scanPeripheralFinish)]) {
        [self.delegate scanPeripheralFinish];
    }
}
@end
