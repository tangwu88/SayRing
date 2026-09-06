import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { ble, connection, hid } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  AlarmClockItem, BatteryInfo, BleDevice, BloodComponentsResult, BloodPressureResult, BloodSugarResult,
  BodyCompPushEvent, BodyCompPushEventKind, BodyCompositionMeasurement, BodyTempMeasurement,
  ConnectionState, DailyFiveData, DeviceDialFile, DeviceSwitchConfig, EcgDiagnosis, EcgHistoryData,
  EcgInstruction, EcgPushEvent,
  EcgPushEventKind, EcgSecondMeasurement, EcgWaveformData, HealthData, HealthQueryDay,
  HeartRateBrightness, HeartRateMeasurement, MsgSwitchConfig, SDKEventType, SpO2Result, SportDataSlot,
  VPBleSDK
} from '@veepoo/vpble-sdk';
import {
  BatteryState, HealthRecord, HealthValue, MeasurementState, WearableCapabilities,
  WearableConnectionPhase, WearableDevice, WearableDeviceSettings, WearableDial, WearableMetricKey, WearableSnapshot,
  WEARABLE_AUTO_SYNC_DELAY_MS, WEARABLE_CONNECT_TIMEOUT_MS, WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS,
  WEARABLE_RECONNECT_DELAYS_MS, WEARABLE_SCAN_TIMEOUT_MS,
  capabilitiesFromFeatureList,
  boundedHealthValue, createWearableDevice, emptyBattery, emptyDeviceSettings, emptyMeasurement,
  emptyWearableSnapshot, healthValue, activityDistanceKilometers, sportDistanceKilometers,
  isCurrentConnectionGeneration, isOneShotMeasurementMetric, mergeWearableDevices, normalizeLegacyDistanceRecord, normalizeMac,
  retainedMeasurementValues,
  wearableProviderForName
} from '../model/WearableContracts';
import { StoredWearableBinding, wearableHealthStore } from './WearableHealthStore';
import { DiscoveryPacketCache, knownWearableName } from '../model/WearableDiscovery';

interface ConnectionEvent {
  oldState: ConnectionState;
  newState: ConnectionState;
}

interface BodyCompositionProgressData {
  progress: number;
  lead: number;
}

export interface WearableServiceListener {
  onDevices?: (devices: WearableDevice[]) => void;
  onPhase?: (phase: WearableConnectionPhase, message: string) => void;
  onSnapshot?: (snapshot: WearableSnapshot) => void;
  onMeasurement?: (measurement: MeasurementState) => void;
}

export class VepWearableService {
  private context: common.UIAbilityContext | null = null;
  private listener: WearableServiceListener | null = null;
  private devices: WearableDevice[] = [];
  private vepDevices: Map<string, BleDevice> = new Map();
  private scanPackets: DiscoveryPacketCache = new DiscoveryPacketCache();
  private scanObserved: number = 0;
  private scanObservedIds: Set<string> = new Set();
  private scanning: boolean = false;
  private scanTimer: number = -1;
  private systemConnectedTimer: number = -1;
  private hidProfile: hid.HidHostProfile = hid.createHidHostProfile();
  private scanGeneration: number = 0;
  private reconnectTimer: number = -1;
  private reconnectAttempt: number = 0;
  private connectionGeneration: number = 0;
  private connectedKey: string = '';
  private lastDevice: BleDevice | null = null;
  private userDisconnect: boolean = false;
  private eventsAttached: boolean = false;
  private busyOperation: string = '';
  private snapshot: WearableSnapshot = emptyWearableSnapshot();
  private measurement: MeasurementState = emptyMeasurement();
  private measurementStopping: boolean = false;
  private lastValidMeasurementValues: HealthValue[] = [];
  private sdk: VPBleSDK = VPBleSDK.getInstance();
  private lastBinding: StoredWearableBinding | undefined = undefined;
  private storageReady: boolean = false;
  private restoreConnectPending: boolean = false;
  private dialFiles: Map<string, DeviceDialFile> = new Map();
  private originalDial: DeviceDialFile | null = null;

  attachContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.attachEvents();
    this.initializeStorage();
  }

  setListener(listener: WearableServiceListener): void {
    this.listener = listener;
    this.emitDevices();
    this.emitSnapshot();
    this.emitMeasurement();
    this.emitPhase(this.snapshot.connected ? 'connected' : 'idle',
      this.snapshot.connected ? `已连接 ${this.snapshot.deviceName}` : '尚未连接手表');
  }

  clearListener(): void {
    this.listener = null;
  }

  isScanning(): boolean {
    return this.scanning;
  }

  isConnected(): boolean {
    return this.snapshot.connected;
  }

  currentSnapshot(): WearableSnapshot {
    return this.copySnapshot();
  }

  currentMeasurement(): MeasurementState {
    return this.copyMeasurement();
  }

  async startScan(): Promise<boolean> {
    if (this.busyOperation && this.busyOperation !== 'scan') {
      if (this.busyOperation !== '连接手表') {
        this.emitPhase('error', `正在${this.busyOperation}，请稍后再扫描`);
        return false;
      }
      // Scanning is also the user's escape hatch from a pending reconnect.
      ++this.connectionGeneration;
      this.cancelReconnect();
      this.userDisconnect = true;
      try { this.sdk.disconnect(); } catch {}
      this.busyOperation = '';
      await this.delay(500);
      this.userDisconnect = false;
    }
    if (!await this.requestPermissions()) {
      this.emitPhase('permission', '需要蓝牙和附近设备权限才能扫描手表');
      return false;
    }
    this.stopScan();
    const scanGeneration = ++this.scanGeneration;
    this.devices = [];
    this.vepDevices.clear();
    this.scanPackets.clear();
    this.scanObserved = 0; this.scanObservedIds.clear();
    this.emitDevices();
    try {
      ble.on('BLEDeviceFind', this.onScanResults);
      const options: ble.ScanOptions = {
        interval: 100,
        dutyMode: ble.ScanDuty.SCAN_MODE_LOW_LATENCY,
        matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
      };
      try {
        // The official SDK demo uses its service UUIDs. The final generic
        // filter keeps W8/Yuc visible without classifying unrelated devices.
        const filters: ble.ScanFilter[] = this.sdk.getScanFilterUUIDs()
          .map((uuid: string): ble.ScanFilter => ({ serviceUuid: uuid }));
        filters.push({});
        ble.startBLEScan(filters, options);
      } catch {
        // Some Harmony builds reject a generic filter. Vep discovery must still remain available.
        ble.startBLEScan([{ manufactureId: 0xF8F8 }, { name: 'ET488' },
          { name: 'SD-Watch-W9' }, { name: 'SD-Watch-W9S' }, { name: 'SD-WATCH-W9S' }], options);
      }
      this.scanning = true;
      this.busyOperation = 'scan';
      this.startSystemConnectedCheck();
      this.emitPhase('scanning', '正在扫描附近手表…');
      this.scanTimer = setTimeout(() => {
        if (scanGeneration !== this.scanGeneration || !this.scanning) return;
        // Do not clear the timer that is currently executing. The generation
        // guard prevents a late timeout from stopping a newer scan.
        this.scanTimer = -1;
        this.stopScan(this.devices.length ? '扫描已完成' : '未收到手表配对信号，请打开手表配对页后重试');
      }, WEARABLE_SCAN_TIMEOUT_MS);
      return true;
    } catch (error) {
      this.scanning = false;
      this.busyOperation = '';
      this.emitPhase('error', this.bluetoothError(error as Error, '启动扫描失败'));
      return false;
    }
  }

  stopScan(message: string = ''): void {
    ++this.scanGeneration;
    this.stopSystemConnectedCheck();
    if (this.scanTimer !== -1) {
      clearTimeout(this.scanTimer);
      this.scanTimer = -1;
    }
    if (this.scanning) {
      // Aggregate only: no nearby device identifiers or private advertisement bytes.
      console.info(`[Saydian BLE] scan callbacks=${this.scanObserved}, nearby=${this.scanObservedIds.size}, watches=${this.devices.length}`);
      try { ble.off('BLEDeviceFind', this.onScanResults); } catch {}
      try { ble.stopBLEScan(); } catch {}
    }
    this.scanning = false;
    if (this.busyOperation === 'scan') this.busyOperation = '';
    if (message) this.emitPhase(this.snapshot.connected ? 'connected' : 'idle', message);
  }

  async connect(deviceKey: string, isRetry: boolean = false): Promise<boolean> {
    const descriptor = this.devices.find((item: WearableDevice) => item.key === deviceKey);
    if (!descriptor) {
      this.emitPhase('error', '该设备已离开扫描范围，请重新扫描');
      return false;
    }
    if (descriptor.provider === 'Yuc') {
      this.emitPhase('error', '当前 W8 系列暂不支持连接');
      return false;
    }
    const target = this.vepDevices.get(deviceKey);
    if (!target) {
      this.emitPhase('error', '该 Vep 设备的连接信息已失效，请重新扫描');
      return false;
    }
    if (this.busyOperation && this.busyOperation !== 'scan') {
      const replacesPendingConnection = !isRetry && this.busyOperation === '连接手表' &&
        !!this.connectedKey && this.connectedKey !== deviceKey;
      if (!replacesPendingConnection) {
        this.emitPhase('error', `正在${this.busyOperation}，请稍后再连接`);
        return false;
      }
      // A direct user choice always supersedes a pending automatic reconnect.
      // Invalidate the old promise before releasing its BLE client.
      ++this.connectionGeneration;
      this.cancelReconnect();
      this.userDisconnect = true;
      try { this.sdk.disconnect(); } catch {}
      this.busyOperation = '';
      await this.delay(500);
    }
    this.stopScan();
    this.cancelReconnect();
    if (!isRetry) this.reconnectAttempt = 0;
    this.busyOperation = '连接手表';
    this.userDisconnect = false;
    const generation = ++this.connectionGeneration;
    if (this.snapshot.connected && this.connectedKey !== deviceKey) {
      this.userDisconnect = true;
      try { this.sdk.disconnect(); } catch {}
      await this.delay(300);
      this.userDisconnect = false;
    }
    this.connectedKey = deviceKey;
    this.lastDevice = target;
    this.emitPhase('connecting', `正在连接 ${descriptor.name}…`);
    try {
      this.emitPhase('authenticating', '正在建立蓝牙通道并完成设备认证…');
      // JL-based W9 devices can need over 20 seconds to finish their secondary
      // authenticated channel. Do not tear down a valid late handshake early.
      const result = await this.withTimeout(this.sdk.connectDevice(target), WEARABLE_CONNECT_TIMEOUT_MS, '连接超时');
      console.info(`[SaydianWearable] SDK connection resolved generation=${generation} success=${result.success}`);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return false;
      if (!result.success) throw new Error(result.error?.message ?? '设备认证失败');
      this.reconnectAttempt = 0;
      console.info(`[SaydianWearable] refreshing device generation=${generation}`);
      // Device metadata and feature flags are available locally. Battery is a
      // separate BLE command and must not make a valid connection fail.
      await this.refreshConnectedDeviceInternal(generation, descriptor, false);
      await this.loadStoredRecords(this.connectedKey);
      const mac = normalizeMac(this.snapshot.mac);
      if (mac) {
        this.lastBinding = { provider: 'Vep', name: this.snapshot.deviceName, mac: mac, updatedAt: Date.now() };
        await wearableHealthStore.saveBinding(this.lastBinding);
      }
      this.emitPhase('connected', `已连接 ${this.snapshot.deviceName}`);
      this.emitSnapshot();
      // Avoid colliding with the SDK's JL directory/watchface initialization.
      setTimeout(() => this.postConnectInitialize(generation), WEARABLE_AUTO_SYNC_DELAY_MS);
      return true;
    } catch (error) {
      if (isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
        try { this.sdk.disconnect(); } catch {}
        this.snapshot = emptyWearableSnapshot();
        this.snapshot.message = this.bluetoothError(error as Error, '连接失败');
        this.emitSnapshot();
        this.emitPhase('error', this.snapshot.message);
        if (!this.userDisconnect) this.scheduleReconnect();
      }
      return false;
    } finally {
      if (isCurrentConnectionGeneration(generation, this.connectionGeneration)) this.busyOperation = '';
    }
  }

  async disconnect(): Promise<void> {
    this.userDisconnect = true;
    this.cancelReconnect();
    this.stopScan();
    ++this.connectionGeneration;
    this.busyOperation = '断开连接';
    this.emitPhase('disconnecting', '正在断开手表…');
    await this.cancelMeasurement(true);
    try { this.sdk.disconnect(); } catch {}
    this.connectedKey = '';
    this.snapshot = emptyWearableSnapshot();
    this.busyOperation = '';
    this.emitSnapshot();
    this.emitPhase('idle', '已断开手表');
  }

  async refresh(): Promise<boolean> {
    if (!this.ensureConnected() || !this.beginOperation('刷新设备')) return false;
    const generation = this.connectionGeneration;
    try {
      await this.refreshConnectedDeviceInternal(generation);
      this.emitPhase('connected', '设备信息已刷新');
      return true;
    } catch (error) {
      this.emitPhase('error', this.bluetoothError(error as Error, '刷新设备失败'));
      return false;
    } finally { this.endOperation(); }
  }

  async syncHistory(): Promise<boolean> {
    if (!this.ensureConnected() || !this.beginOperation('同步健康数据')) return false;
    const generation = this.connectionGeneration;
    this.emitPhase('syncing', '正在同步近三天手表数据…');
    try {
      await this.syncHistoryInternal(generation, [HealthQueryDay.TODAY,
        HealthQueryDay.YESTERDAY, HealthQueryDay.DAY_BEFORE_YESTERDAY]);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return false;
      this.snapshot.syncedAt = Date.now();
      this.snapshot.message = '手表历史数据已同步';
      await wearableHealthStore.saveRecords(this.snapshot.records);
      this.emitSnapshot();
      this.emitPhase('connected', '同步完成');
      return true;
    } catch (error) {
      this.snapshot.message = this.bluetoothError(error as Error, '同步失败');
      this.emitSnapshot();
      this.emitPhase('error', this.snapshot.message);
      return false;
    } finally { this.endOperation(); }
  }

  async findDevice(): Promise<boolean> {
    if (!this.ensureConnected() || !this.snapshot.capabilities.findDevice || !this.beginOperation('查找设备')) return false;
    try {
      const result = await this.sdk.deviceControlService.findDevice(true);
      const ok = result.success;
      this.emitPhase(ok ? 'connected' : 'error', ok ? '已向手表发送查找提示' :
        (result.errorMessage ?? '手表不支持查找设备'));
      return ok;
    } catch (error) {
      this.emitPhase('error', this.bluetoothError(error as Error, '查找设备失败'));
      return false;
    } finally { this.endOperation(); }
  }

  async syncTime(): Promise<boolean> {
    if (!this.ensureConnected() || !this.beginOperation('同步时间')) return false;
    try {
      const result = await this.sdk.deviceControlService.syncTimeNow(new Date());
      this.emitPhase(result.success ? 'connected' : 'error', result.success ? '手表时间已同步' :
        (result.errorMessage ?? '时间同步失败'));
      return result.success;
    } catch (error) {
      this.emitPhase('error', this.bluetoothError(error as Error, '时间同步失败'));
      return false;
    } finally { this.endOperation(); }
  }

  async readDeviceConfiguration(): Promise<boolean> {
    if (!this.ensureConnected() || !this.beginOperation('读取设备设置')) return false;
    const generation = this.connectionGeneration;
    const settings = emptyDeviceSettings();
    let successes = 0;
    try {
      try {
        const result = await this.sdk.configService.getSwitchConfig();
        if (result.success && result.data) {
          settings.unitSystem = result.data.unitSystem === 1 ? '公制' : result.data.unitSystem === 2 ? '英制' : '未返回';
          settings.timeFormat = result.data.timeFormat === 1 ? '24 小时' : result.data.timeFormat === 2 ? '12 小时' : '未返回';
          settings.automaticHealth = this.automaticHealthText(result.data);
          ++successes;
        }
      } catch {}
      if (this.snapshot.capabilities.notification) {
        try {
          const result = await this.sdk.configService.getMsgSwitchConfig();
          if (result.success && result.data) {
            settings.messageReminder = this.messageReminderText(result.data);
            ++successes;
          }
        } catch {}
      } else { settings.messageReminder = '设备不支持'; }
      if (this.snapshot.capabilities.sedentaryReminder) {
        try {
          const result = await this.sdk.reminderService.getSedentaryReminder();
          if (result.success && result.data) {
            settings.sedentaryReminder = result.data.enabled ?
              `已开启 · ${result.data.startTime}-${result.data.endTime} · ${result.data.intervalMinutes} 分钟` : '已关闭';
            ++successes;
          }
        } catch {}
      } else { settings.sedentaryReminder = '设备不支持'; }
      if (this.snapshot.capabilities.alarm) {
        try {
          const result = await this.sdk.alarmClockService.readAll();
          if (result.success && result.data) {
            settings.alarms = result.data.map((item: AlarmClockItem) =>
              `${item.enabled ? '开' : '关'} · ${item.time}${item.labels ? ` · ${item.labels}` : ''}`);
            ++successes;
          }
        } catch {}
      }
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return false;
      settings.loadedAt = successes > 0 ? Date.now() : 0;
      this.snapshot.settings = settings;
      this.snapshot.message = successes > 0 ? '已读取手表实际设置' : '手表未返回可读取的设置';
      this.emitSnapshot();
      this.emitPhase(successes > 0 ? 'connected' : 'error', this.snapshot.message);
      return successes > 0;
    } finally { this.endOperation(); }
  }

  async readDials(): Promise<boolean> {
    if (!this.ensureConnected() || !this.snapshot.capabilities.dial || !this.beginOperation('读取表盘')) return false;
    const generation = this.connectionGeneration;
    try {
      const listResult = await this.sdk.dialService.getDialFileList();
      const currentResult = await this.sdk.dialService.getCurrentDial();
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return false;
      if (!listResult.success || !listResult.list) {
        this.emitPhase('error', listResult.errorMessage ?? '手表未返回可用表盘');
        return false;
      }
      this.dialFiles.clear();
      const currentKey = currentResult.success && currentResult.dial ? this.dialKey(currentResult.dial) : '';
      const dials: WearableDial[] = [];
      listResult.list.forEach((dial: DeviceDialFile) => {
        const key = this.dialKey(dial);
        if (!key || this.dialFiles.has(key)) return;
        this.dialFiles.set(key, dial);
        dials.push({ key: key, path: dial.path, fileName: dial.fileName || '未命名表盘',
          uuid: dial.uuid, selected: key === currentKey || dial.select === true });
      });
      if (currentResult.success && currentResult.dial && currentKey && !this.dialFiles.has(currentKey)) {
        this.dialFiles.set(currentKey, currentResult.dial);
        dials.unshift({ key: currentKey, path: currentResult.dial.path,
          fileName: currentResult.dial.fileName || '当前表盘', uuid: currentResult.dial.uuid, selected: true });
      }
      if (!this.originalDial && currentResult.success && currentResult.dial) this.originalDial = currentResult.dial;
      this.snapshot.dials = dials;
      this.snapshot.currentDialKey = currentKey;
      this.snapshot.originalDialKey = this.originalDial ? this.dialKey(this.originalDial) : '';
      this.snapshot.message = dials.length > 0 ? `已读取 ${dials.length} 个手表内表盘` : '手表未返回表盘文件';
      this.emitSnapshot();
      this.emitPhase(dials.length > 0 ? 'connected' : 'error', this.snapshot.message);
      return dials.length > 0;
    } catch (error) {
      this.emitPhase('error', this.bluetoothError(error as Error, '读取表盘失败'));
      return false;
    } finally { this.endOperation(); }
  }

  async setExistingDial(dialKey: string): Promise<boolean> {
    if (!this.ensureConnected() || !this.snapshot.capabilities.dial || !this.beginOperation('切换表盘')) return false;
    const generation = this.connectionGeneration;
    const dial = this.dialFiles.get(dialKey);
    if (!dial) {
      this.endOperation();
      this.emitPhase('error', '表盘列表已过期，请重新读取');
      return false;
    }
    try {
      const setOk = await this.sdk.dialService.setUsingDial(dial);
      if (!setOk || !isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
        this.emitPhase('error', '手表未确认表盘切换');
        return false;
      }
      const current = await this.sdk.dialService.getCurrentDial();
      const confirmed = current.success && current.dial && this.dialKey(current.dial) === dialKey;
      if (!confirmed) {
        this.emitPhase('error', '表盘已发送，但重读未确认生效');
        return false;
      }
      this.snapshot.currentDialKey = dialKey;
      this.snapshot.dials = this.snapshot.dials.map((item: WearableDial) =>
        this.copyDial(item, item.key === dialKey));
      this.snapshot.message = `已切换并确认表盘：${dial.fileName || '未命名表盘'}`;
      this.emitSnapshot();
      this.emitPhase('connected', this.snapshot.message);
      return true;
    } catch (error) {
      this.emitPhase('error', this.bluetoothError(error as Error, '表盘切换失败'));
      return false;
    } finally { this.endOperation(); }
  }

  async restoreOriginalDial(): Promise<boolean> {
    if (!this.originalDial) {
      this.emitPhase('error', '尚未读取原表盘，请先读取表盘');
      return false;
    }
    return this.setExistingDial(this.dialKey(this.originalDial));
  }

  async startMeasurement(metric: WearableMetricKey): Promise<boolean> {
    if (!this.ensureConnected() || !this.supportsMetric(metric)) {
      this.emitPhase('error', '当前手表不支持该测量项目');
      return false;
    }
    if (metric === 'hrv' || metric === 'activity' || metric === 'sleep' || metric === 'sport') {
      this.emitPhase('error', '该项目仅支持同步历史数据');
      return false;
    }
    if (!this.beginOperation('手动测量')) return false;
    this.measurement = emptyMeasurement();
    this.measurement.metric = metric;
    this.measurement.running = true;
    this.measurementStopping = false;
    this.lastValidMeasurementValues = [];
    this.measurement.status = `正在测量${this.metricName(metric)}…`;
    this.emitMeasurement();
    try {
      let success = false;
      let errorMessage = '';
      if (metric === 'heart') {
        const r = await this.sdk.heartRateService.startMeasurement(HeartRateBrightness.HIGH);
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onHeartRate(r.data);
      } else if (metric === 'pressure') {
        const r = await this.sdk.bloodPressureService.startMeasurement(false);
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onBloodPressure(r);
      } else if (metric === 'oxygen') {
        const r = await this.sdk.bloodOxygenService.startMeasurement();
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onOxygen(r);
        // The official Harmony SDK exposes blood oxygen as a one-shot read.
        // A successful response without a valid value must still release the
        // command queue instead of leaving the page in an endless measuring state.
        if (success && isOneShotMeasurementMetric(metric) && this.measurement.running &&
          this.measurement.metric === metric) {
          this.measurement.running = false;
          this.measurement.status = '本次未收到有效血氧读数，请正确佩戴后重试';
          this.endOperation();
        }
      } else if (metric === 'temperature') {
        const r = await this.sdk.bodyTemperatureService.startMeasurement();
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onBodyTemperature(r.data);
      } else if (metric === 'glucose') {
        const r = await this.sdk.bloodSugarService.startMeasurement(false);
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onBloodSugar(r);
      } else if (metric === 'bloodComponents') {
        const r = await this.sdk.bloodComponentsService.startMeasurement(false);
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onBloodComponents(r);
      } else if (metric === 'bodyComposition') {
        const r = await this.sdk.bodyCompositionService.startMeasurement();
        success = r.success; errorMessage = r.errorMessage ?? '';
      } else if (metric === 'ecg') {
        const r = await this.sdk.ecgService.startMeasurement();
        success = r.success; errorMessage = r.errorMessage ?? '';
      }
      if (!this.measurement.running && this.measurement.metric === metric) {
        this.emitMeasurement();
        return success;
      }
      if (!success) {
        this.measurement.running = false;
        this.measurement.status = errorMessage || '手表未接受测量指令';
        this.endOperation();
      }
      this.emitMeasurement();
      return success;
    } catch (error) {
      // A bounded user stop may settle before the vendor start promise. Ignore
      // that late rejection so it cannot overwrite the already-finished UI.
      if (!this.measurement.running || this.measurement.metric !== metric) return false;
      this.measurement.running = false;
      this.measurement.status = this.bluetoothError(error as Error, '启动测量失败');
      this.endOperation();
      this.emitMeasurement();
      return false;
    }
  }

  async stopMeasurement(): Promise<void> {
    await this.cancelMeasurement(false);
  }

  shutdown(): void {
    this.stopScan();
    this.cancelReconnect();
    this.userDisconnect = true;
    ++this.connectionGeneration;
    try { this.sdk.disconnect(); } catch {}
    this.detachEvents();
    this.listener = null;
  }

  private onScanResults = (results: Array<ble.ScanResult>): void => {
    if (!this.scanning) return;
    this.scanObserved += results.length;
    results.forEach((result: ble.ScanResult) => this.scanObservedIds.add(result.deviceId));
    const incoming: WearableDevice[] = [];
    const normalized: ble.ScanResult[] = results.map((result: ble.ScanResult): ble.ScanResult => {
      const packet = this.scanPackets.observe({ id: result.deviceId, name: result.deviceName ?? '',
        rssi: result.rssi, connectable: result.connectable,
        data: Array.from(new Uint8Array(result.data)) }, Date.now());
      return { deviceId: result.deviceId, deviceName: packet.name, rssi: packet.rssi,
        connectable: packet.connectable, data: new Uint8Array(packet.data).buffer };
    });
    let vepResults: BleDevice[] = [];
    try {
      // Keep the official SDK's input contract intact. ScanResult may contain
      // platform fields that are lost when a new object is reconstructed.
      vepResults = this.sdk.processScanResults(results);
    } catch { /* An unrecognized advertisement must not discard the rest of the batch. */ }
    try {
      // Some watches split their name and manufacturer payload across packets.
      // The merged packet is only a second chance and never replaces a result
      // that the official parser already recognized from the original input.
      this.sdk.processScanResults(normalized).forEach((device: BleDevice) => {
        if (!vepResults.some((item: BleDevice) => item.deviceId === device.deviceId)) vepResults.push(device);
      });
    } catch {}
    vepResults.forEach((device: BleDevice) => {
      if (wearableProviderForName(device.deviceName) === 'Yuc') return;
      const descriptor = createWearableDevice('Vep', device.deviceName, device.deviceId,
        device.mac, device.rssi, device.connectable);
      if (descriptor) {
        incoming.push(descriptor);
        this.vepDevices.set(descriptor.key, device);
      }
    });
    normalized.forEach((result: ble.ScanResult) => {
      const provider = knownWearableName(result.deviceName);
      if (!provider || vepResults.some((device: BleDevice) =>
        device.deviceId === result.deviceId && provider === 'Vep')) return;
      const descriptor = createWearableDevice(provider, result.deviceName, result.deviceId,
        '', result.rssi, result.connectable);
      if (!descriptor) return;
      incoming.push(descriptor);
      if (provider === 'Vep') {
        // Official demo also connects a BleDevice with an empty mac. Never copy
        // the Harmony transport address into the hardware MAC field.
        this.vepDevices.set(descriptor.key, { deviceId: result.deviceId,
          deviceName: result.deviceName, mac: '', rssi: result.rssi, connectable: result.connectable });
      }
    });
    if (incoming.length > 0) {
      this.devices = mergeWearableDevices(this.devices, incoming);
      this.emitDevices();
      this.tryRestoreConnection();
    }
  };

  private startSystemConnectedCheck(): void {
    this.stopSystemConnectedCheck();
    this.mergeSystemConnectedDevices();
    this.systemConnectedTimer = setInterval(() => this.mergeSystemConnectedDevices(), 500);
  }

  private stopSystemConnectedCheck(): void {
    if (this.systemConnectedTimer === -1) return;
    clearInterval(this.systemConnectedTimer);
    this.systemConnectedTimer = -1;
  }

  private mergeSystemConnectedDevices(): void {
    try {
      const connected = [...this.hidProfile.getConnectedDevices(), ...ble.getConnectedBLEDevices()];
      const seen: Set<string> = new Set();
      const incoming: WearableDevice[] = [];
      connected.forEach((deviceId: string) => {
        if (seen.has(deviceId)) return;
        seen.add(deviceId);
        try {
          const name = connection.getRemoteDeviceName(deviceId);
          const provider = knownWearableName(name);
          if (!provider) return;
          const descriptor = createWearableDevice(provider, name, deviceId, '', 0, true);
          if (!descriptor) return;
          incoming.push(descriptor);
          if (provider === 'Vep') {
            this.vepDevices.set(descriptor.key, { deviceId: deviceId, deviceName: name,
              mac: '', rssi: 0, connectable: true });
          }
        } catch {}
      });
      if (incoming.length > 0) {
        this.devices = mergeWearableDevices(this.devices, incoming);
        this.emitDevices();
        this.tryRestoreConnection();
      }
    } catch {}
  }

  private async requestPermissions(): Promise<boolean> {
    if (!this.context) return false;
    const permissions: Permissions[] = [
      'ohos.permission.ACCESS_BLUETOOTH',
      'ohos.permission.APPROXIMATELY_LOCATION',
      'ohos.permission.LOCATION'
    ];
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.context, permissions);
      return result.authResults.every((value: number) => value === 0);
    } catch { return false; }
  }

  private attachEvents(): void {
    if (this.eventsAttached) return;
    this.eventsAttached = true;
    this.sdk.on(SDKEventType.CONNECTION_STATE_CHANGED, this.onConnectionState);
    this.sdk.heartRateService.onHeartRatePush(this.onHeartRate);
    this.sdk.bloodPressureService.onBloodPressurePush(this.onBloodPressure);
    this.sdk.bloodOxygenService.onSpO2Push(this.onOxygen);
    this.sdk.bodyTemperatureService.onBodyTempPush(this.onBodyTemperature);
    this.sdk.bloodSugarService.onBloodSugarPush(this.onBloodSugar);
    this.sdk.bloodComponentsService.onBloodComponentsPush(this.onBloodComponents);
    this.sdk.bodyCompositionService.onBodyCompPush(this.onBodyComposition);
    this.sdk.ecgService.onEcgPush(this.onEcg);
  }

  private detachEvents(): void {
    if (!this.eventsAttached) return;
    this.eventsAttached = false;
    this.sdk.off(SDKEventType.CONNECTION_STATE_CHANGED, this.onConnectionState);
    this.sdk.heartRateService.offHeartRatePush(this.onHeartRate);
    this.sdk.bloodPressureService.offBloodPressurePush(this.onBloodPressure);
    this.sdk.bloodOxygenService.offSpO2Push(this.onOxygen);
    this.sdk.bodyTemperatureService.offBodyTempPush(this.onBodyTemperature);
    this.sdk.bloodSugarService.offBloodSugarPush(this.onBloodSugar);
    this.sdk.bloodComponentsService.offBloodComponentsPush(this.onBloodComponents);
    this.sdk.bodyCompositionService.offBodyCompPush(this.onBodyComposition);
    this.sdk.ecgService.offEcgPush(this.onEcg);
  }

  private onConnectionState = (payload: ESObject): void => {
    const event = payload as ConnectionEvent;
    if (event.newState === ConnectionState.DISCONNECTED && !this.userDisconnect && this.lastDevice) {
      if (this.measurement.running) {
        const metric = this.measurement.metric;
        this.measurement.running = false;
        this.measurement.values = [];
        this.measurement.samples = [];
        this.measurement.sampleFrequency = 0;
        this.measurement.status = metric === 'ecg' ? '心电测量因蓝牙中断已取消，未保存未完成波形' :
          '测量因蓝牙中断已取消，未保存不完整结果';
        this.emitMeasurement();
      }
      this.busyOperation = '';
      this.snapshot.connected = false;
      this.snapshot.battery = emptyBattery();
      this.snapshot.message = '手表连接已中断';
      this.emitSnapshot();
      this.scheduleReconnect();
    }
  };

  private scheduleReconnect(): void {
    if (this.reconnectTimer !== -1 || this.userDisconnect) return;
    if (!this.lastDevice || this.reconnectAttempt >= WEARABLE_RECONNECT_DELAYS_MS.length) {
      this.emitPhase('error', '自动重连未成功，请确认手表未被其他手机占用后手动重连');
      return;
    }
    const delayMs = WEARABLE_RECONNECT_DELAYS_MS[this.reconnectAttempt];
    ++this.reconnectAttempt;
    this.emitPhase('connecting', `连接中断，${delayMs / 1000} 秒后第 ${this.reconnectAttempt} 次重连`);
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1;
      const key = this.connectedKey;
      if (key) this.connect(key, true);
    }, delayMs);
  }

  private cancelReconnect(): void {
    if (this.reconnectTimer !== -1) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = -1;
  }

  private async refreshConnectedDeviceInternal(generation: number, fallback?: WearableDevice,
    includeBattery: boolean = true): Promise<void> {
    const device = this.sdk.getConnectedDevice();
    if (!device || !isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
      throw new Error('设备连接状态已变化');
    }
    const capabilities: WearableCapabilities = capabilitiesFromFeatureList(device.featureList ?? undefined);
    const sameDevice = this.snapshot.deviceKey === this.connectedKey;
    if (!sameDevice) {
      this.dialFiles.clear();
      this.originalDial = null;
    }
    this.snapshot = {
      connected: true,
      deviceKey: this.connectedKey,
      deviceName: device.deviceName || fallback?.name || '赛电手表',
      mac: normalizeMac(device.mac || fallback?.mac || ''),
      model: device.modelName || device.deviceFullVersion || '',
      firmware: device.firmwareVersion || device.deviceVersion || '',
      capabilities: capabilities,
      battery: emptyBattery(),
      records: sameDevice ? this.snapshot.records : [],
      settings: sameDevice ? this.snapshot.settings : emptyDeviceSettings(),
      dials: sameDevice ? this.snapshot.dials : [],
      currentDialKey: sameDevice ? this.snapshot.currentDialKey : '',
      originalDialKey: sameDevice ? this.snapshot.originalDialKey : '',
      syncedAt: sameDevice ? this.snapshot.syncedAt : 0,
      message: '设备已认证'
    };
    if (includeBattery) {
      try {
        const battery = await this.sdk.deviceService.getBatteryInfo();
        if (battery.success && battery.data && isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
          this.snapshot.battery = this.toBatteryState(battery.data);
        }
      } catch (error) {
        // Battery support varies by firmware. Never tear down the connection
        // because this optional read timed out or returned an unsupported code.
        console.warn(`[SaydianWearable] battery read skipped: ${(error as Error).message}`);
      }
    }
    this.emitSnapshot();
  }

  private async syncHistoryInternal(generation: number, days: HealthQueryDay[], includeAdvanced: boolean = true): Promise<void> {
    for (const day of days) {
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      const health = await this.sdk.healthService.getHealthData(day, 1);
      if (health.success && health.data) this.addDailyHealth(day, health.data);
      const sleep = await this.sdk.healthService.getSleepData(day);
      if (sleep.success && sleep.data) {
        sleep.data.forEach((segment) => {
          const values: HealthValue[] = [];
          this.pushValue(values, healthValue('总睡眠', segment.sleepDuration, '分钟'));
          this.pushValue(values, healthValue('深睡', segment.deepDuration, '分钟'));
          this.pushValue(values, healthValue('浅睡', segment.lightDuration, '分钟'));
          this.pushValue(values, healthValue('清醒', segment.getUpDuration, '分钟'));
          if (values.length > 0) {
            const parsed = Date.parse(segment.sleepTime.replace(' ', 'T'));
            this.addRecord(this.makeRecord('sleep', Number.isFinite(parsed) ? parsed : this.dayStart(day), values));
          }
        });
      }
    }
    if (includeAdvanced) await this.syncAdvancedHistory(generation);
    this.snapshot.records = this.snapshot.records.slice().sort((a: HealthRecord, b: HealthRecord) => b.timestamp - a.timestamp);
    this.emitSnapshot();
  }

  private addDailyHealth(day: HealthQueryDay, data: HealthData): void {
    const activityValues: HealthValue[] = [];
    this.pushValue(activityValues, healthValue('步数', data.sportSummary.totalSteps, '步'));
    this.pushValue(activityValues, healthValue('距离',
      activityDistanceKilometers(data.sportSummary.totalDistance, data.sportSummary.totalSteps), 'km'));
    this.pushValue(activityValues, healthValue('热量', data.sportSummary.totalCalories, 'kcal'));
    if (activityValues.length > 0) this.addRecord(this.makeRecord('activity', this.dayStart(day) + 86399000, activityValues));

    data.fiveMinuteData.forEach((slot: DailyFiveData) => {
      if (slot.time < 0 || slot.time > 1435 || slot.time === 0xFFFF) return;
      const timestamp = this.dayStart(day) + slot.time * 60000;
      const heart = this.averageInRange(slot.ecgs, 20, 240);
      if (heart > 0) this.addMetricRecord('heart', timestamp,
        [boundedHealthValue('心率', heart, 'BPM', 20, 240)]);
      if (slot.systolicBP > 0 && slot.diastolicBP > 0) this.addMetricRecord('pressure', timestamp,
        [boundedHealthValue('收缩压', slot.systolicBP, 'mmHg', 20, 300),
          boundedHealthValue('舒张压', slot.diastolicBP, 'mmHg', 20, 220)]);
      const oxygen = this.averageInRange(slot.spO2Values, 50, 100);
      if (oxygen > 0) this.addMetricRecord('oxygen', timestamp,
        [boundedHealthValue('血氧', oxygen, '%', 50, 100)]);
      if (slot.bodyTemp > 0) this.addMetricRecord('temperature', timestamp,
        [boundedHealthValue('体温', slot.bodyTemp, '°C', 20, 50)]);
      if (slot.bloodGlucose > 0) this.addMetricRecord('glucose', timestamp,
        [boundedHealthValue('血糖', slot.bloodGlucose, 'mmol/L', 0.1, 50)]);
      const hrv = this.averageInRange(slot.hrvs, 1, 1000);
      if (hrv > 0) this.addMetricRecord('hrv', timestamp, [boundedHealthValue('HRV', hrv, 'ms', 1, 1000)]);
      const components: Array<HealthValue | undefined> = [
        healthValue('尿酸', slot.uricAcid, 'μmol/L'),
        healthValue('总胆固醇', slot.totalCholesterol, 'mmol/L'),
        healthValue('甘油三酯', slot.triglyceride, 'mmol/L'),
        healthValue('高密度脂蛋白', slot.highDensityLipoprotein, 'mmol/L'),
        healthValue('低密度脂蛋白', slot.lowDensityLipoprotein, 'mmol/L')
      ];
      this.addMetricRecord('bloodComponents', timestamp, components);
    });
  }

  private async syncAdvancedHistory(generation: number): Promise<void> {
    if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
    if (this.snapshot.capabilities.ecg) {
      const idResult = await this.sdk.ecgService.getSavedId();
      if (idResult.success && idResult.id && idResult.id > 0) {
        const history = await this.sdk.ecgService.getHistory(idResult.id);
        if (history.success && history.data) this.addEcgHistory(history.data);
      }
    }
    if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
    if (this.snapshot.capabilities.bodyComposition) {
      const ids = await this.sdk.bodyCompositionService.getSavedIds();
      if (ids.success && ids.data) {
        for (const item of ids.data) {
          const history = await this.sdk.bodyCompositionService.getHistory(item.id);
          if (history.success && history.data) {
            const values = this.bodyCompositionValues(history.data.data);
            const timestamp = Date.parse(history.data.dateTime.replace(' ', 'T'));
            if (values.length > 0) this.addRecord(this.makeRecord('bodyComposition',
              Number.isFinite(timestamp) ? timestamp : Date.now(), values));
          }
        }
      }
    }
    if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
    if (this.snapshot.capabilities.sport) {
      const crcResult = await this.sdk.sportService.readModeCrc();
      const crc = crcResult.data;
      if (crcResult.success && crc) {
        const slots: SportDataSlot[] = [];
        if (crc.crc0 > 0) slots.push(SportDataSlot.CRC0);
        if (crc.crc1 > 0) slots.push(SportDataSlot.CRC1);
        if (crc.crc2 > 0) slots.push(SportDataSlot.CRC2);
        for (const slot of slots) {
          const result = await this.sdk.sportService.readData(slot);
          if (result.success && result.data) {
            const values: HealthValue[] = [];
            this.pushValue(values, healthValue('步数', result.data.allStep, '步'));
            this.pushValue(values, healthValue('距离', sportDistanceKilometers(result.data.allDistance), 'km'));
            this.pushValue(values, healthValue('热量', result.data.allCalorie, 'kcal'));
            const timestamp = Date.parse(result.data.startTime.replace(' ', 'T'));
            if (values.length > 0) this.addRecord(this.makeRecord('sport',
              Number.isFinite(timestamp) ? timestamp : Date.now(), values));
          } else if (result.success && result.dataA704?.motionData) {
            const motion = result.dataA704.motionData;
            const values: HealthValue[] = [];
            this.pushValue(values, healthValue('步数', motion.allStep, '步'));
            this.pushValue(values, healthValue('距离', sportDistanceKilometers(motion.allDistance), 'km'));
            this.pushValue(values, healthValue('热量', motion.allCalorie, 'kcal'));
            const timestamp = Date.parse(motion.startTime.replace(' ', 'T'));
            if (values.length > 0) this.addRecord(this.makeRecord('sport',
              Number.isFinite(timestamp) ? timestamp : Date.now(), values));
          }
        }
      }
    }
  }

  private addEcgHistory(data: EcgHistoryData): void {
    const values: HealthValue[] = [];
    this.pushValue(values, boundedHealthValue('平均心率', data.meanHeartRate, 'BPM', 20, 240));
    this.pushValue(values, boundedHealthValue('HRV', data.averageHRV, 'ms', 1, 1000));
    this.pushValue(values, boundedHealthValue('QT', data.averageQTInterval, 'ms', 1, 2000));
    this.pushValue(values, boundedHealthValue('SDNN', data.diseaseSDNN, 'ms', 1, 2000));
    this.pushValue(values, boundedHealthValue('RMSSD', data.diseaseRMSSD, 'ms', 1, 2000));
    const samples: number[] = [];
    data.waveformArray.forEach((second) => samples.push(...second.waveform));
    const timestamp = Date.parse(data.dateTime.replace(' ', 'T'));
    const record = this.makeRecord('ecg', Number.isFinite(timestamp) ? timestamp : Date.now(), values);
    record.samples = samples;
    record.sampleFrequency = data.sampleFrequency;
    this.addRecord(record);
  }

  private onHeartRate = (data: HeartRateMeasurement): void => {
    if (this.measurement.metric !== 'heart' || !this.measurement.running) return;
    const value = boundedHealthValue('心率', data.heartRate, 'BPM', 20, 240);
    if (!value) {
      this.measurement.values = [];
      this.measurement.status = '等待手表获得有效心率，请正确佩戴并保持静止';
      this.emitMeasurement();
      return;
    }
    this.measurement.values = [value];
    this.measurement.status = '已收到手表实时心率';
    this.emitMeasurement();
  };

  private onBloodPressure = (result: BloodPressureResult): void => {
    const data = result.data;
    if (this.measurement.metric !== 'pressure' || !this.measurement.running || !data) return;
    this.measurement.progress = Math.max(0, Math.min(100, data.progress));
    this.measurement.values = this.validValues([
      boundedHealthValue('收缩压', data.systolic, 'mmHg', 20, 300),
      boundedHealthValue('舒张压', data.diastolic, 'mmHg', 20, 220)]);
    this.measurement.status = `血压测量 ${this.measurement.progress}%`;
    if (data.progress >= 100 && this.measurement.values.length === 2) this.completeMeasurement();
    else this.emitMeasurement();
  };

  private onOxygen = (result: SpO2Result): void => {
    const value = result.data?.spO2 ?? 0;
    if (this.measurement.metric !== 'oxygen' || !this.measurement.running || value <= 0) return;
    this.measurement.values = this.validValues([boundedHealthValue('血氧', value, '%', 50, 100)]);
    if (this.measurement.values.length === 0) {
      this.measurement.status = '等待手表获得有效血氧，请正确佩戴并保持静止';
      this.emitMeasurement();
      return;
    }
    this.measurement.progress = 100;
    this.completeMeasurement();
  };

  private onBodyTemperature = (data: BodyTempMeasurement): void => {
    if (this.measurement.metric !== 'temperature' || !this.measurement.running) return;
    this.measurement.progress = Math.max(0, Math.min(100, data.progress));
    this.measurement.values = this.validValues([
      boundedHealthValue('体温', data.bodyTemp, '°C', 20, 50),
      boundedHealthValue('体表温度', data.surfaceTemp, '°C', 15, 50)]);
    this.measurement.status = `体温测量 ${this.measurement.progress}%`;
    if (data.progress >= 100 && this.measurement.values.length > 0) this.completeMeasurement();
    else this.emitMeasurement();
  };

  private onBloodSugar = (result: BloodSugarResult): void => {
    const data = result.data;
    if (this.measurement.metric !== 'glucose' || !this.measurement.running || !data) return;
    this.measurement.progress = Math.max(0, Math.min(100, data.progress));
    this.measurement.values = this.validValues([
      boundedHealthValue('血糖', data.bloodSugar, 'mmol/L', 0.1, 50)]);
    this.measurement.status = `血糖测量 ${this.measurement.progress}%`;
    if (data.progress >= 100 && this.measurement.values.length > 0) this.completeMeasurement();
    else this.emitMeasurement();
  };

  private onBloodComponents = (result: BloodComponentsResult): void => {
    const data = result.data;
    if (this.measurement.metric !== 'bloodComponents' || !this.measurement.running || !data) return;
    this.measurement.progress = Math.max(0, Math.min(100, data.progress));
    this.measurement.values = this.validValues([
      healthValue('尿酸', data.uricAcid, 'μmol/L'), healthValue('总胆固醇', data.cholesterol, 'mmol/L'),
      healthValue('甘油三酯', data.triglyceride, 'mmol/L'), healthValue('高密度脂蛋白', data.highDensity, 'mmol/L'),
      healthValue('低密度脂蛋白', data.lowDensity, 'mmol/L')]);
    this.measurement.status = `血液成分测量 ${this.measurement.progress}%`;
    if (data.progress >= 100 && this.measurement.values.length > 0) this.completeMeasurement();
    else this.emitMeasurement();
  };

  private onBodyComposition = (event: BodyCompPushEvent): void => {
    if (this.measurement.metric !== 'bodyComposition' || !this.measurement.running) return;
    if (event.kind === BodyCompPushEventKind.PROGRESS) {
      const data = event.data as BodyCompositionProgressData;
      this.measurement.progress = Math.max(0, Math.min(100, data.progress));
      this.measurement.status = `身体成分测量 ${this.measurement.progress}%`;
      this.emitMeasurement();
    } else {
      this.measurement.values = this.bodyCompositionValues(event.data as BodyCompositionMeasurement);
      this.measurement.progress = 100;
      this.completeMeasurement();
    }
  };

  private onEcg = (event: EcgPushEvent): void => {
    if (this.measurement.metric !== 'ecg' || !this.measurement.running) return;
    if (event.kind === EcgPushEventKind.INSTRUCTION) {
      const data = event.data as EcgInstruction;
      this.measurement.sampleFrequency = data.samplingFreq;
      this.measurement.status = `心电电极已连接，采样率 ${data.samplingFreq} Hz`;
    } else if (event.kind === EcgPushEventKind.WAVEFORM) {
      const data = event.data as EcgWaveformData;
      this.measurement.samples = this.measurement.samples.concat(data.samples).slice(-60000);
      this.measurement.status = `已收到 ${this.measurement.samples.length} 个真实心电采样点`;
    } else if (event.kind === EcgPushEventKind.PROGRESS) {
      const data = event.data as EcgSecondMeasurement;
      this.measurement.progress = Math.max(0, Math.min(100, data.progress));
      this.measurement.values = this.validValues([
        healthValue('心率', data.hrPerMinute, 'BPM'), healthValue('HRV', data.hrv, 'ms'), healthValue('QT', data.qtc, 'ms')]);
      this.measurement.status = `心电测量 ${this.measurement.progress}% · ${this.measurement.samples.length} 点`;
    } else if (event.kind === EcgPushEventKind.RESULT) {
      const data = event.data as EcgDiagnosis;
      this.measurement.values = this.validValues([
        healthValue('心率', data.heartRate, 'BPM'), healthValue('HRV', data.hrv, 'ms'),
        healthValue('QT', data.qtc, 'ms'), healthValue('SDNN', data.sdnn, 'ms'), healthValue('RMSSD', data.rmssd, 'ms')]);
      this.measurement.progress = 100;
      this.completeMeasurement();
      return;
    }
    this.emitMeasurement();
  };

  private async cancelMeasurement(shutdown: boolean): Promise<void> {
    if (!this.measurement.running || !this.measurement.metric) {
      if (this.busyOperation === '手动测量') this.endOperation();
      return;
    }
    if (this.measurementStopping) return;
    this.measurementStopping = true;
    const metric = this.measurement.metric;
    const values = retainedMeasurementValues(this.measurement.values, this.lastValidMeasurementValues);
    if (!shutdown) {
      this.measurement.status = '正在结束测量…';
      this.emitMeasurement();
    }
    try {
      await this.withTimeout(this.requestMeasurementStop(metric), WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS, '结束测量超时');
    } catch {}
    this.measurement.running = false;
    if (metric === 'ecg') {
      this.measurement.values = [];
      this.measurement.samples = [];
      this.measurement.sampleFrequency = 0;
      this.measurement.status = shutdown ? '' : '已取消心电测量，未保存未完成波形';
    } else if (values.length > 0 && !shutdown) {
      this.measurement.values = values;
      this.measurement.status = '测量已结束，已保留手表实时读数';
      this.addMeasurementRecord();
    } else {
      this.measurement.status = shutdown ? '' : '已取消测量，未收到有效读数';
    }
    this.measurementStopping = false;
    this.endOperation();
    this.emitMeasurement();
  }

  private async requestMeasurementStop(metric: WearableMetricKey): Promise<void> {
    if (metric === 'heart') await this.sdk.heartRateService.stopMeasurement();
    else if (metric === 'pressure') await this.sdk.bloodPressureService.stopMeasurement();
    else if (metric === 'oxygen') await this.sdk.bloodOxygenService.stopMeasurement();
    else if (metric === 'temperature') await this.sdk.bodyTemperatureService.stopMeasurement();
    else if (metric === 'glucose') await this.sdk.bloodSugarService.stopMeasurement();
    else if (metric === 'bloodComponents') await this.sdk.bloodComponentsService.stopMeasurement();
    else if (metric === 'bodyComposition') await this.sdk.bodyCompositionService.stopMeasurement();
    else if (metric === 'ecg') await this.sdk.ecgService.stopMeasurement();
  }

  private completeMeasurement(): void {
    if (!this.measurement.running || !this.measurement.metric) return;
    this.measurement.running = false;
    this.measurement.progress = 100;
    this.measurement.status = `${this.metricName(this.measurement.metric)}测量完成`;
    this.addMeasurementRecord();
    this.endOperation();
    this.emitMeasurement();
  }

  private addMeasurementRecord(): void {
    if (!this.measurement.metric || (this.measurement.values.length === 0 &&
      !(this.measurement.metric === 'ecg' && this.measurement.samples.length > 1))) return;
    const record = this.makeRecord(this.measurement.metric, Date.now(), this.measurement.values, 'app_measurement');
    record.samples = this.measurement.samples.slice();
    record.sampleFrequency = this.measurement.sampleFrequency;
    this.addRecord(record);
    this.persistRecords([record]);
    this.snapshot.syncedAt = Date.now();
    this.emitSnapshot();
  }

  private bodyCompositionValues(data: BodyCompositionMeasurement): HealthValue[] {
    return this.validValues([
      healthValue('BMI', data.bmi, ''), healthValue('体脂率', data.bodyFatPercentage, '%'),
      healthValue('脂肪量', data.fatMass, 'kg'), healthValue('肌肉量', data.muscleMass, 'kg'),
      healthValue('水分率', data.bodyMoisture, '%'), healthValue('骨量', data.boneMass, 'kg'),
      healthValue('基础代谢', data.basalMetabolicRate, 'kcal')]);
  }

  private supportsMetric(metric: WearableMetricKey): boolean {
    const caps = this.snapshot.capabilities;
    if (metric === 'activity') return caps.activity;
    if (metric === 'sleep') return caps.sleep;
    if (metric === 'heart') return caps.heart;
    if (metric === 'pressure') return caps.pressure;
    if (metric === 'oxygen') return caps.oxygen;
    if (metric === 'temperature') return caps.temperature;
    if (metric === 'glucose') return caps.glucose;
    if (metric === 'hrv') return caps.hrv;
    if (metric === 'ecg') return caps.ecg;
    if (metric === 'bodyComposition') return caps.bodyComposition;
    if (metric === 'bloodComponents') return caps.bloodComponents;
    return caps.sport;
  }

  private metricName(metric: WearableMetricKey): string {
    if (metric === 'heart') return '心率';
    if (metric === 'pressure') return '血压';
    if (metric === 'oxygen') return '血氧';
    if (metric === 'temperature') return '体温';
    if (metric === 'glucose') return '血糖';
    if (metric === 'hrv') return 'HRV';
    if (metric === 'ecg') return '心电';
    if (metric === 'bodyComposition') return '身体成分';
    if (metric === 'bloodComponents') return '血液成分';
    if (metric === 'sleep') return '睡眠';
    if (metric === 'sport') return '运动';
    return '活动';
  }

  private toBatteryState(data: BatteryInfo): BatteryState {
    return {
      available: true,
      hasPercentage: data.hasPercentage,
      level: data.level,
      levelGrade: data.levelGrade,
      charging: data.powerMode === 1 || data.powerMode === 3,
      lowBattery: data.lowBattery || data.powerMode === 2,
      updatedAt: Date.now()
    };
  }

  private addMetricRecord(metric: WearableMetricKey, timestamp: number,
    values: Array<HealthValue | undefined>): void {
    const valid = this.validValues(values);
    if (valid.length > 0) this.addRecord(this.makeRecord(metric, timestamp, valid));
  }

  private makeRecord(metric: WearableMetricKey, timestamp: number, values: HealthValue[],
    source: 'watch_history' | 'app_measurement' = 'watch_history'): HealthRecord {
    const time = Number.isFinite(timestamp) && timestamp > 0 ? Math.round(timestamp) : Date.now();
    return {
      id: `${this.connectedKey}|${metric}|${time}|${source}`,
      deviceKey: this.connectedKey,
      metric: metric,
      timestamp: time,
      source: source,
      values: values.slice(),
      samples: [],
      sampleFrequency: 0
    };
  }

  private addRecord(record: HealthRecord): void {
    const map: Map<string, HealthRecord> = new Map();
    this.snapshot.records.forEach((item: HealthRecord) => map.set(item.id, item));
    map.set(record.id, record);
    this.snapshot.records = Array.from(map.values());
  }

  private initializeStorage(): void {
    if (!this.context || this.storageReady) return;
    this.storageReady = true;
    wearableHealthStore.open(this.context).then(async () => {
      this.lastBinding = await wearableHealthStore.loadBinding();
      if (this.lastBinding?.provider === 'Vep' && !this.snapshot.connected && !this.scanning && !this.busyOperation) {
        setTimeout(() => {
          if (!this.snapshot.connected && !this.scanning && !this.busyOperation) this.startScan();
        }, 800);
      }
    }).catch(() => {
      this.storageReady = false;
      this.snapshot.message = '本机加密健康数据库暂不可用，本次数据仅保留到 App 关闭前';
      this.emitSnapshot();
    });
  }

  private async loadStoredRecords(deviceKey: string): Promise<void> {
    try {
      const stored = await wearableHealthStore.loadRecent(deviceKey);
      const records: Map<string, HealthRecord> = new Map();
      const repaired: HealthRecord[] = [];
      this.snapshot.records.forEach((item: HealthRecord) => records.set(item.id, item));
      stored.forEach((item: HealthRecord) => {
        const normalized = normalizeLegacyDistanceRecord(item);
        if (normalized !== item) repaired.push(normalized);
        records.set(normalized.id, normalized);
      });
      this.snapshot.records = Array.from(records.values())
        .sort((a: HealthRecord, b: HealthRecord) => b.timestamp - a.timestamp);
      if (repaired.length > 0) await wearableHealthStore.saveRecords(repaired);
      this.emitSnapshot();
    } catch {}
  }

  async healthRange(deviceKey: string, metric: WearableMetricKey, start: number, end: number): Promise<HealthRecord[]> {
    if (!deviceKey || deviceKey !== this.snapshot.deviceKey || !Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
      throw new Error('设备或日期已变更，请重新选择');
    }
    const generation = this.connectionGeneration;
    const records = await wearableHealthStore.loadRange(deviceKey, metric, start, end - 1);
    if (generation !== this.connectionGeneration || deviceKey !== this.snapshot.deviceKey) throw new Error('设备已变更，请重新选择');
    const result: Map<string, HealthRecord> = new Map();
    records.forEach((record: HealthRecord) => result.set(record.id, record));
    this.snapshot.records.filter((record: HealthRecord) => record.deviceKey === deviceKey && record.metric === metric &&
      record.timestamp >= start && record.timestamp < end).forEach((record: HealthRecord) => result.set(record.id, record));
    return Array.from(result.values());
  }

  private persistRecords(records: HealthRecord[]): void {
    wearableHealthStore.saveRecords(records).catch(() => {
      this.snapshot.message = '测量完成，但本机加密保存失败';
      this.emitSnapshot();
    });
  }

  private tryRestoreConnection(): void {
    if (!this.lastBinding || this.lastBinding.provider !== 'Vep' || this.restoreConnectPending ||
      this.snapshot.connected || this.busyOperation !== 'scan') return;
    const match = this.devices.find((item: WearableDevice) =>
      item.provider === 'Vep' && !!item.mac && item.mac === this.lastBinding?.mac);
    if (!match) return;
    this.restoreConnectPending = true;
    setTimeout(() => {
      this.connect(match.key).finally(() => { this.restoreConnectPending = false; });
    }, 200);
  }

  private async postConnectInitialize(generation: number): Promise<void> {
    if (!isCurrentConnectionGeneration(generation, this.connectionGeneration) || !this.snapshot.connected ||
      this.busyOperation || this.measurement.running) return;
    this.busyOperation = '连接后初始化';
    this.emitPhase('syncing', '正在读取电量并同步今日手表数据…');
    console.info(`[SaydianWearable] delayed post-connect initialization started generation=${generation}`);
    try {
      await this.refreshConnectedDeviceInternal(generation);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      // Automatic sync is intentionally limited to stable daily/sleep data.
      // ECG/body composition/sports history remain available via manual sync.
      await this.syncHistoryInternal(generation, [HealthQueryDay.TODAY], false);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      this.snapshot.syncedAt = Date.now();
      this.snapshot.message = '今日手表数据已自动同步';
      await wearableHealthStore.saveRecords(this.snapshot.records);
      this.emitSnapshot();
      this.emitPhase('connected', '今日数据同步完成');
    } catch (error) {
      if (isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
        // Post-connect reads are optional. A failed read must not disconnect a
        // device that has already authenticated successfully.
        this.snapshot.message = this.bluetoothError(error as Error, '已连接，自动读取失败，可手动重试');
        this.emitSnapshot();
        this.emitPhase('connected', this.snapshot.message);
      }
    } finally { this.endOperation(); }
  }

  private automaticHealthText(config: DeviceSwitchConfig): string {
    const enabled: string[] = [];
    if (config.heartRateAutoDetect === 1) enabled.push('心率');
    if (config.bloodPressureAutoDetect === 1) enabled.push('血压');
    if (config.hrvAutoDetect === 1) enabled.push('HRV');
    if (config.tempAutoMonitor === 1) enabled.push('体温');
    if (config.bloodGlucoseSwitch === 1) enabled.push('血糖');
    return enabled.length > 0 ? `已开启：${enabled.join('、')}` : '均未开启或设备未返回';
  }

  private messageReminderText(config: MsgSwitchConfig): string {
    const values: number[] = [config.call, config.sms, config.wechat, config.qq, config.sina,
      config.facebook, config.x, config.linkedIn, config.whatsapp, config.line, config.instagram,
      config.gmail, config.dingTalk, config.wechatWork, config.other, config.tiktok, config.telegram];
    const supported = values.filter((value: number) => value === 1 || value === 2).length;
    const enabled = values.filter((value: number) => value === 1).length;
    return supported > 0 ? `已开启 ${enabled}/${supported} 项` : '设备未返回支持项';
  }

  private dialKey(dial: DeviceDialFile): string {
    const value = dial.path || dial.uuid || dial.fileName;
    return typeof value === 'string' ? value.trim().slice(0, 240) : '';
  }

  private copyDial(dial: WearableDial, selected: boolean = dial.selected): WearableDial {
    const copy: WearableDial = {
      key: dial.key,
      path: dial.path,
      fileName: dial.fileName,
      uuid: dial.uuid,
      selected: selected
    };
    return copy;
  }

  private validValues(values: Array<HealthValue | undefined>): HealthValue[] {
    const valid: HealthValue[] = [];
    values.forEach((value: HealthValue | undefined) => {
      if (value !== undefined) valid.push(value);
    });
    return valid;
  }

  private pushValue(values: HealthValue[], value?: HealthValue): void {
    if (value) values.push(value);
  }

  private averageInRange(values: number[], minimum: number, maximum: number): number {
    let total = 0;
    let count = 0;
    values.forEach((value: number) => {
      if (Number.isFinite(value) && value >= minimum && value <= maximum) { total += value; ++count; }
    });
    return count > 0 ? Math.round((total / count) * 10) / 10 : 0;
  }

  private dayStart(day: HealthQueryDay): number {
    const date = new Date();
    date.setHours(0, 0, 0, 0);
    date.setDate(date.getDate() - Number(day));
    return date.getTime();
  }

  private beginOperation(name: string): boolean {
    if (this.busyOperation) {
      this.emitPhase('error', `正在${this.busyOperation}，请完成后再操作`);
      return false;
    }
    this.busyOperation = name;
    return true;
  }

  private endOperation(): void {
    if (this.busyOperation !== 'scan') this.busyOperation = '';
  }

  private ensureConnected(): boolean {
    if (!this.snapshot.connected || this.sdk.getState() !== ConnectionState.CONNECTED) {
      this.emitPhase('error', '请先连接 Vep 手表');
      return false;
    }
    return true;
  }

  private emitDevices(): void {
    this.listener?.onDevices?.(this.devices.slice());
  }

  private emitPhase(phase: WearableConnectionPhase, message: string): void {
    this.listener?.onPhase?.(phase, message);
  }

  private emitSnapshot(): void {
    this.listener?.onSnapshot?.(this.copySnapshot());
  }

  private emitMeasurement(): void {
    if (this.measurement.running && this.measurement.values.length > 0) {
      this.lastValidMeasurementValues = this.measurement.values.slice();
    }
    this.listener?.onMeasurement?.(this.copyMeasurement());
  }

  private copySnapshot(): WearableSnapshot {
    return {
      connected: this.snapshot.connected,
      deviceKey: this.snapshot.deviceKey,
      deviceName: this.snapshot.deviceName,
      mac: this.snapshot.mac,
      model: this.snapshot.model,
      firmware: this.snapshot.firmware,
      capabilities: this.snapshot.capabilities,
      battery: this.snapshot.battery,
      records: this.snapshot.records.slice(),
      settings: {
        loadedAt: this.snapshot.settings.loadedAt,
        unitSystem: this.snapshot.settings.unitSystem,
        timeFormat: this.snapshot.settings.timeFormat,
        automaticHealth: this.snapshot.settings.automaticHealth,
        sedentaryReminder: this.snapshot.settings.sedentaryReminder,
        messageReminder: this.snapshot.settings.messageReminder,
        alarms: this.snapshot.settings.alarms.slice()
      },
      dials: this.snapshot.dials.map((item: WearableDial) => this.copyDial(item)),
      currentDialKey: this.snapshot.currentDialKey,
      originalDialKey: this.snapshot.originalDialKey,
      syncedAt: this.snapshot.syncedAt,
      message: this.snapshot.message
    };
  }

  private copyMeasurement(): MeasurementState {
    return {
      metric: this.measurement.metric,
      running: this.measurement.running,
      progress: this.measurement.progress,
      status: this.measurement.status,
      values: this.measurement.values.slice(),
      samples: this.measurement.samples.slice(),
      sampleFrequency: this.measurement.sampleFrequency
    };
  }

  private bluetoothError(error: Error, fallback: string): string {
    const code = (error as BusinessError).code;
    if (code === 201) return '蓝牙或附近设备权限未开启';
    if (code === 2900003) return '手机蓝牙已关闭';
    if (code === 2900001) return '系统蓝牙服务暂不可用';
    if (/JL RCSP service not available/i.test(error.message)) {
      return `${fallback}：当前手表暂不支持表盘读取`;
    }
    if (/timeout|超时/i.test(error.message)) return `${fallback}：连接超时，请确认手表未被其他手机占用`;
    return error.message && error.message.length <= 120 ? `${fallback}：${error.message}` : fallback;
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => setTimeout(resolve, milliseconds));
  }

  private withTimeout<T>(operation: Promise<T>, milliseconds: number, message: string): Promise<T> {
    return new Promise<T>((resolve: (value: T) => void, reject: (reason?: Error) => void) => {
      const timer = setTimeout(() => reject(new Error(message)), milliseconds);
      operation.then((value: T) => { clearTimeout(timer); resolve(value); })
        .catch((error: Error) => { clearTimeout(timer); reject(error); });
    });
  }
}

export const vepWearable: VepWearableService = new VepWearableService();
