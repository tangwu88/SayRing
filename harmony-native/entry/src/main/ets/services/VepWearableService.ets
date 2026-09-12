import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { ble, connection, hid } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { geoLocationManager } from '@kit.LocationKit';
import {
  AlarmClockItem, BatteryInfo, BleDevice, BloodComponentsResult, BloodPressureResult, BloodSugarResult,
  BodyCompPushEvent, BodyCompPushEventKind, BodyCompositionMeasurement, BodyTempMeasurement,
  ConnectionState, DailyFiveData, DeviceDialFile, DeviceSwitchConfig, EcgDiagnosis, EcgHistoryData,
  EcgInstruction, EcgPushEvent,
  EcgPushEventKind, EcgSecondMeasurement, EcgWaveformData, HealthData, HealthQueryDay,
  HeartRateBrightness, HeartRateMeasurement, MsgSwitchConfig, SDKEventType, SpO2Result,
  SportControlCode, SportControlPushEvent, SportControlRecord, SportDataSlot,
  SportModeControl, SportModePushEvent, SportModePushKind,
  VPBleSDK
} from '@veepoo/vpble-sdk';
import {
  BatteryState, HealthRecord, HealthValue, MeasurementState, SportRoutePoint, SportSessionState, WearableCapabilities,
  WearableConnectionPhase, WearableDevice, WearableDeviceSettings, WearableDial, WearableMetricKey, WearableProvider,
  WearableSnapshot, WearableSportMode,
  WEARABLE_AUTO_SYNC_DELAY_MS, WEARABLE_CONNECT_TIMEOUT_MS, WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS,
  WEARABLE_RECONNECT_DELAYS_MS, WEARABLE_SCAN_TIMEOUT_MS,
  capabilitiesFromFeatureList,
  appendSportRoutePoint, boundedHealthValue, createWearableDevice, emptyBattery, emptyDeviceSettings, emptyMeasurement,
  emptySportSession, emptyWearableSnapshot, healthValue, activityDistanceKilometers, routeDistanceKilometers,
  sportCapabilityFromFeatureList, sportDistanceKilometers, sportModeFromProtocolValue, sportModeLabel, sportModeProtocolValue,
  isCurrentConnectionGeneration, isOneShotMeasurementMetric, mergeWearableDevices, normalizeLegacyDistanceRecord, normalizeMac,
  retainedMeasurementValues,
  wearableProviderForName
} from '../model/WearableContracts';
import { StoredWearableBinding, wearableHealthStore } from './WearableHealthStore';
import { DiscoveryPacketCache, knownWearableName } from '../model/WearableDiscovery';
import { HealthOwnerSession, HealthSyncResult, recordWithinOwnership, sameHealthSession, validHealthOwner } from '../model/HealthUpload';
import { HealthUploadService } from './HealthUploadService';
import { saydianApi } from './SaydianApi';
import { YucSportTelemetry, YucWearableAdapter } from './YucWearableAdapter';
import { YucRealtimeHealth, yucCapabilitiesFromFlags, yucSportCapabilityFromFlags } from '../model/YucWearableContracts';

interface ConnectionEvent {
  oldState: ConnectionState;
  newState: ConnectionState;
}

interface BodyCompositionProgressData {
  progress: number;
  lead: number;
}

interface MeasurementSession {
  owner: HealthOwnerSession;
  connection: number;
  generation: number;
  ecgWearConfirmed: boolean;
}

interface MeasurementListeners {
  heart: (data: HeartRateMeasurement) => void;
  pressure: (data: BloodPressureResult) => void;
  oxygen: (data: SpO2Result) => void;
  temperature: (data: BodyTempMeasurement) => void;
  glucose: (data: BloodSugarResult) => void;
  blood: (data: BloodComponentsResult) => void;
  body: (data: BodyCompPushEvent) => void;
  ecg: (data: EcgPushEvent) => void;
}

export interface WearableServiceListener {
  onDevices?: (devices: WearableDevice[]) => void;
  onPhase?: (phase: WearableConnectionPhase, message: string) => void;
  onSnapshot?: (snapshot: WearableSnapshot) => void;
  onMeasurement?: (measurement: MeasurementState) => void;
  onSportSession?: (session: SportSessionState) => void;
  onCloudSync?: (result: HealthSyncResult) => void;
}

export class VepWearableService {
  private context: common.UIAbilityContext | null = null;
  private listener: WearableServiceListener | null = null;
  private devices: WearableDevice[] = [];
  private vepDevices: Map<string, BleDevice> = new Map();
  private yucDevices: Map<string, ble.ScanResult> = new Map();
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
  private activeProvider: WearableProvider | '' = '';
  private lastDevice: BleDevice | null = null;
  private userDisconnect: boolean = false;
  private eventsAttached: boolean = false;
  private busyOperation: string = '';
  private operationGeneration: number = 0;
  private snapshot: WearableSnapshot = emptyWearableSnapshot();
  private measurement: MeasurementState = emptyMeasurement();
  private measurementStopping: boolean = false;
  private measurementGeneration: number = 0;
  private measurementSession: MeasurementSession | undefined = undefined;
  private measurementListeners: MeasurementListeners | undefined = undefined;
  private measurementStartInFlight: Promise<boolean> | undefined = undefined;
  private measurementStopInFlight: Promise<void> | undefined = undefined;
  private sportSession: SportSessionState = emptySportSession();
  private sportCommandInFlight: Promise<void> | undefined = undefined;
  private sportSessionGeneration: number = 0;
  private sportSaved: boolean = false;
  private locationListener: ((location: geoLocationManager.Location) => void) | undefined = undefined;
  private deviceCommandInFlight: Promise<void> | undefined = undefined;
  private accountTeardown: Promise<void> = Promise.resolve();
  private accountTeardownPending: boolean = false;
  private accountTeardownFailed: boolean = false;
  private lastValidMeasurementValues: HealthValue[] = [];
  private sdk: VPBleSDK = VPBleSDK.getInstance();
  private lastBinding: StoredWearableBinding | undefined = undefined;
  private restoreConnectPending: boolean = false;
  private dialFiles: Map<string, DeviceDialFile> = new Map();
  private originalDial: DeviceDialFile | null = null;
  private accountSession: HealthOwnerSession = { ownerId: '', generation: -1 };
  private ownershipSince: number = Number.MAX_SAFE_INTEGER;
  private healthUploader: HealthUploadService = new HealthUploadService(wearableHealthStore, saydianApi);
  private yucAdapter: YucWearableAdapter | null = null;

  attachContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.attachEvents();
    this.yuc().attachContext(context, {
      onState: (state: number): void => this.onYucState(state),
      onBattery: (level: number, state: number): void => this.onYucBattery(level, state),
      onRealtime: (data: YucRealtimeHealth): void => this.onYucRealtime(data),
      onMeasurementEnd: (metric: WearableMetricKey): void => this.onYucMeasurementEnd(metric),
      onSport: (data: YucSportTelemetry): void => this.onYucSport(data)
    });
    saydianApi.observeHealthSession((session: HealthOwnerSession) => this.updateAccountSession(session));
    this.initializeStorage();
  }

  private updateAccountSession(session: HealthOwnerSession): void {
    if (session.ownerId === this.accountSession.ownerId && session.generation === this.accountSession.generation) return;
    const metric = this.measurement.running ? this.measurement.metric : undefined;
    const pendingStart = this.measurementStartInFlight, pendingStop = this.measurementStopInFlight;
    const pendingCommand = this.deviceCommandInFlight;
    this.finishSportSession(false, '账号已切换，本次运动已结束');
    ++this.sportSessionGeneration;
    this.sportSession = emptySportSession(); this.sportSaved = false;
    this.accountSession = session;
    ++this.connectionGeneration;
    this.cancelReconnect(); this.stopScan();
    this.userDisconnect = true;
    this.invalidateMeasurementSession();
    this.measurement = emptyMeasurement(); this.measurementStopping = false;
    this.lastValidMeasurementValues = [];
    this.connectedKey = ''; this.lastDevice = null; this.lastBinding = undefined;
    this.ownershipSince = Number.MAX_SAFE_INTEGER;
    this.snapshot = emptyWearableSnapshot(); this.busyOperation = '切换账号';
    this.emitSnapshot(); this.emitMeasurement(); this.emitSportSession();
    this.accountTeardownPending = true;
    this.accountTeardown = this.accountTeardown.catch(() => {}).then(async () => {
      let failed = false;
      try {
        if (metric && !pendingStop) {
          try { await this.withTimeout(this.requestMeasurementStop(metric), WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS, '结束测量超时'); }
          catch { /* Native disconnect is still mandatory. */ }
        }
        await this.disconnectNativeForAccount();
        const settling: Promise<void>[] = [];
        if (pendingStart) settling.push(pendingStart.then(() => {}, () => {}));
        if (pendingStop) settling.push(pendingStop.catch(() => {}));
        if (pendingCommand) settling.push(pendingCommand);
        await this.withTimeout(Promise.all(settling), 5000, '旧测量指令尚未结束');
        await this.waitForNativeDisconnect();
      } catch { failed = true; }
      if (!sameHealthSession(session, this.accountSession)) return;
      this.accountTeardownFailed = failed;
      this.activeProvider = '';
      this.accountTeardownPending = false;
      if (this.busyOperation === '切换账号') this.busyOperation = '';
      if (failed) {
        this.snapshot.message = '旧戒指连接尚未结束，请关闭再开启蓝牙后重试';
        this.emitSnapshot();
      } else this.initializeStorage();
    });
  }

  private async waitForNativeDisconnect(): Promise<void> {
    if (this.activeProvider === 'Yuc') {
      for (let attempt = 0; attempt < 50; attempt++) {
        if (!this.yuc().isReady()) return;
        await this.delay(100);
      }
      throw new Error('旧 W8 戒指连接尚未结束');
    }
    for (let attempt = 0; attempt < 50; attempt++) {
      const state = this.sdk.getState();
      if (state === ConnectionState.DISCONNECTED || state === ConnectionState.READY ||
        state === ConnectionState.UNINITIALIZED) return;
      await this.delay(100);
    }
    throw new Error('旧戒指连接尚未结束');
  }

  private async disconnectNativeForAccount(): Promise<void> {
    if (this.activeProvider === 'Yuc') {
      await this.yuc().disconnect(false);
      return;
    }
    const state = this.sdk.getState();
    if (state !== ConnectionState.UNINITIALIZED && state !== ConnectionState.READY &&
      state !== ConnectionState.DISCONNECTED) this.sdk.disconnect();
  }

  private async accountWearableReady(): Promise<boolean> {
    const session = this.accountSession;
    let pending: Promise<void>;
    do { pending = this.accountTeardown; await pending; } while (pending !== this.accountTeardown);
    if (!sameHealthSession(session, this.accountSession)) return false;
    // SDK methods can send a second packet after an internal await. A timeout is
    // not cancellation: keep the unresolved command until it actually settles.
    if (!this.snapshot.connected) {
      try {
        while (this.deviceCommandInFlight) {
          await this.withTimeout(this.deviceCommandInFlight, 5000, '旧戒指指令尚未结束');
          if (!sameHealthSession(session, this.accountSession)) return false;
        }
      } catch {
        this.emitPhase('error', '旧戒指操作尚未结束，请稍后重试');
        return false;
      }
    }
    if (this.accountTeardownFailed) {
      // A manual retry may succeed after Bluetooth released the prior session.
      try {
        await this.disconnectNativeForAccount();
        await this.waitForNativeDisconnect();
        await this.withTimeout(Promise.all([
          this.measurementStartInFlight?.then(() => {}, () => {}) ?? Promise.resolve(),
          this.measurementStopInFlight?.catch(() => {}) ?? Promise.resolve()
        ]), 5000, '旧测量指令尚未结束');
        if (!sameHealthSession(session, this.accountSession)) return false;
        this.accountTeardownFailed = false;
      } catch {
        this.emitPhase('error', '旧戒指连接尚未结束，请关闭再开启蓝牙后重试');
        return false;
      }
    }
    return !this.accountTeardownPending;
  }

  async synchronizeCloud(): Promise<HealthSyncResult> {
    const session = this.accountSession, generation = this.connectionGeneration;
    const current = (): boolean => sameHealthSession(session, this.accountSession) && generation === this.connectionGeneration;
    const result = await this.healthUploader.synchronize(current);
    if (current()) this.listener?.onCloudSync?.(result);
    return result;
  }

  setListener(listener: WearableServiceListener): void {
    this.listener = listener;
    this.emitDevices();
    this.emitSnapshot();
    this.emitMeasurement();
    this.emitSportSession();
    this.emitPhase(this.snapshot.connected ? 'connected' : 'idle',
      this.snapshot.connected ? `已连接 ${this.snapshot.deviceName}` : '尚未连接戒指');
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

  currentSportSession(): SportSessionState {
    return this.copySportSession();
  }

  async startScan(): Promise<boolean> {
    const session = this.accountSession;
    if (!await this.accountWearableReady() || !sameHealthSession(session, this.accountSession)) return false;
    if (this.busyOperation && this.busyOperation !== 'scan') {
      if (this.busyOperation !== '连接戒指') {
        this.emitPhase('error', `正在${this.busyOperation}，请稍后再扫描`);
        return false;
      }
      // Scanning is also the user's escape hatch from a pending reconnect.
      ++this.connectionGeneration;
      this.cancelReconnect();
      this.userDisconnect = true;
      try {
        if (this.activeProvider === 'Yuc') await this.yuc().disconnect(false);
        else this.sdk.disconnect();
      } catch {}
      this.busyOperation = '';
      await this.delay(500);
      this.userDisconnect = false;
    }
    if (!await this.requestPermissions()) {
      this.emitPhase('permission', '需要蓝牙和附近设备权限才能扫描戒指');
      return false;
    }
    this.stopScan();
    const scanGeneration = ++this.scanGeneration;
    this.devices = [];
    this.vepDevices.clear();
    this.yucDevices.clear();
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
      this.emitPhase('scanning', '正在扫描附近戒指…');
      this.scanTimer = setTimeout(() => {
        if (scanGeneration !== this.scanGeneration || !this.scanning) return;
        // Do not clear the timer that is currently executing. The generation
        // guard prevents a late timeout from stopping a newer scan.
        this.scanTimer = -1;
        this.stopScan(this.devices.length ? '扫描已完成' : '未收到戒指配对信号，请将戒指充电并靠近手机后重试');
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
    const requestedSession = this.accountSession;
    if (!await this.accountWearableReady() || !sameHealthSession(requestedSession, this.accountSession)) return false;
    if (!validHealthOwner(this.accountSession.ownerId)) {
      this.emitPhase('error', '请先登录再连接戒指'); return false;
    }
    const descriptor = this.devices.find((item: WearableDevice) => item.key === deviceKey);
    if (!descriptor) {
      this.emitPhase('error', '该设备已离开扫描范围，请重新扫描');
      return false;
    }
    const routedProvider = wearableProviderForName(descriptor.name);
    if (!routedProvider || routedProvider !== descriptor.provider) {
      this.emitPhase('error', '设备信息已变化，请重新扫描');
      return false;
    }
    if (descriptor.provider === 'Moyoung') {
      this.emitPhase('error', '当前型号暂未开放连接');
      return false;
    }
    if (descriptor.provider === 'Yuc') {
      return this.connectYuc(descriptor, isRetry);
    }
    const target = this.vepDevices.get(deviceKey);
    if (!target) {
      this.emitPhase('error', '该 Vep 设备的连接信息已失效，请重新扫描');
      return false;
    }
    if (this.busyOperation && this.busyOperation !== 'scan') {
      const replacesPendingConnection = !isRetry && this.busyOperation === '连接戒指' &&
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
      try {
        if (this.activeProvider === 'Yuc') await this.yuc().disconnect(false);
        else this.sdk.disconnect();
      } catch {}
      this.busyOperation = '';
      await this.delay(500);
    }
    this.stopScan();
    this.cancelReconnect();
    if (!isRetry) this.reconnectAttempt = 0;
    this.busyOperation = '连接戒指';
    this.userDisconnect = false;
    const generation = ++this.connectionGeneration;
    const session = this.accountSession;
    if (this.snapshot.connected && this.connectedKey !== deviceKey) {
      this.userDisconnect = true;
      try {
        if (this.activeProvider === 'Yuc') await this.yuc().disconnect(false);
        else this.sdk.disconnect();
      } catch {}
      await this.delay(300);
      this.userDisconnect = false;
    }
    this.activeProvider = 'Vep';
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
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration) || !sameHealthSession(session, this.accountSession)) return false;
      const current = (): boolean => generation === this.connectionGeneration && sameHealthSession(session, this.accountSession);
      const ownedSince = await wearableHealthStore.claimDevice(session.ownerId, deviceKey, Date.now(), isRetry, current);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration) || !sameHealthSession(session, this.accountSession)) return false;
      this.ownershipSince = ownedSince;
      await this.loadStoredRecords(this.connectedKey);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return false;
      const mac = normalizeMac(this.snapshot.mac);
      if (mac) {
        this.lastBinding = { provider: 'Vep', name: this.snapshot.deviceName, mac: mac, updatedAt: Date.now() };
        await wearableHealthStore.saveBinding(session.ownerId, this.lastBinding, current);
      }
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return false;
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

  private async connectYuc(descriptor: WearableDevice, isRetry: boolean): Promise<boolean> {
    const target = this.yucDevices.get(descriptor.key);
    if (!target) {
      this.emitPhase('error', '该 W8 设备的连接信息已失效，请重新扫描');
      return false;
    }
    if (this.busyOperation && this.busyOperation !== 'scan') {
      const replacesPendingConnection = !isRetry && this.busyOperation === '连接戒指' &&
        !!this.connectedKey && this.connectedKey !== descriptor.key;
      if (!replacesPendingConnection) {
        this.emitPhase('error', `正在${this.busyOperation}，请稍后再连接`);
        return false;
      }
      ++this.connectionGeneration;
      this.cancelReconnect();
      this.userDisconnect = true;
      try {
        if (this.activeProvider === 'Yuc') await this.yuc().disconnect(false);
        else this.sdk.disconnect();
      } catch {}
      this.busyOperation = '';
      await this.delay(500);
    }
    this.stopScan();
    this.cancelReconnect();
    if (!isRetry) this.reconnectAttempt = 0;
    this.busyOperation = '连接戒指';
    this.userDisconnect = false;
    const generation = ++this.connectionGeneration;
    const session = this.accountSession;
    if (this.snapshot.connected && this.connectedKey !== descriptor.key) {
      this.userDisconnect = true;
      try {
        if (this.activeProvider === 'Yuc') await this.yuc().disconnect(false);
        else this.sdk.disconnect();
      } catch {}
      await this.delay(300);
      this.userDisconnect = false;
    }
    this.activeProvider = 'Yuc';
    this.connectedKey = descriptor.key;
    this.lastDevice = null;
    this.emitPhase('connecting', `正在连接 ${descriptor.name}…`);
    try {
      this.emitPhase('authenticating', '正在建立 W8 蓝牙通道并完成设备认证…');
      await this.yuc().connect(target);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return false;
      await this.refreshYucDeviceInternal(generation, descriptor, true);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration) ||
        !sameHealthSession(session, this.accountSession)) return false;
      const current = (): boolean => generation === this.connectionGeneration &&
        sameHealthSession(session, this.accountSession);
      const ownedSince = await wearableHealthStore.claimDevice(session.ownerId, descriptor.key,
        Date.now(), isRetry, current);
      if (!current()) return false;
      this.ownershipSince = ownedSince;
      await this.loadStoredRecords(this.connectedKey);
      if (!current()) return false;
      const mac = normalizeMac(this.snapshot.mac);
      if (mac) {
        this.lastBinding = { provider: 'Yuc', name: this.snapshot.deviceName, mac: mac, updatedAt: Date.now() };
        await wearableHealthStore.saveBinding(session.ownerId, this.lastBinding, current);
      }
      if (!current()) return false;
      this.emitSnapshot();
      this.emitPhase('connected', `已连接 ${this.snapshot.deviceName}`);
      setTimeout(() => this.postConnectInitialize(generation), 3000);
      return true;
    } catch (error) {
      if (isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
        try { await this.yuc().disconnect(false); } catch {}
        this.snapshot = emptyWearableSnapshot();
        this.snapshot.message = this.bluetoothError(error as Error, '连接 W8 失败');
        this.emitSnapshot();
        this.emitPhase('error', this.snapshot.message);
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
    if (this.sportActive()) {
      const stopped = await this.stopSport();
      if (!stopped && this.sportActive()) this.finishSportSession(true, '连接已断开，已保留断开前的真实运动数据');
    }
    const generation = ++this.connectionGeneration;
    this.busyOperation = '断开连接';
    this.emitPhase('disconnecting', '正在断开戒指…');
    await this.cancelMeasurement(true);
    if (generation !== this.connectionGeneration) return;
    this.invalidateMeasurementSession();
    this.measurement = emptyMeasurement(); this.measurementStopping = false;
    let disconnected = false;
    try {
      if (this.activeProvider === 'Yuc') await this.yuc().disconnect(true);
      else { this.sdk.disconnect(); await this.waitForNativeDisconnect(); }
      disconnected = true;
    } catch {}
    if (generation !== this.connectionGeneration) return;
    this.accountTeardownFailed = !disconnected;
    this.connectedKey = '';
    this.activeProvider = '';
    this.snapshot = emptyWearableSnapshot();
    this.sportSession = emptySportSession();
    this.busyOperation = '';
    if (!disconnected) this.snapshot.message = '尚未确认戒指已断开，请关闭再开启蓝牙后重试';
    this.emitSnapshot();
    this.emitMeasurement();
    this.emitSportSession();
    this.emitPhase(disconnected ? 'idle' : 'error', disconnected ? '已断开戒指' : this.snapshot.message);
  }

  async refresh(): Promise<boolean> {
    return this.runConnectedOperation('刷新设备', async (current: () => void): Promise<boolean> => {
      await this.refreshConnectedDeviceInternal(this.connectionGeneration);
      current();
      this.emitPhase('connected', '设备信息已刷新');
      return true;
    });
  }

  async syncHistory(): Promise<boolean> {
    return this.runConnectedOperation('同步健康数据', async (current: () => void): Promise<boolean> => {
      const generation = this.connectionGeneration;
      this.emitPhase('syncing', '正在同步近三天戒指数据…');
      await this.syncHistoryInternal(generation, [HealthQueryDay.TODAY,
        HealthQueryDay.YESTERDAY, HealthQueryDay.DAY_BEFORE_YESTERDAY]);
      current();
      this.snapshot.syncedAt = Date.now();
      this.snapshot.message = '戒指历史数据已同步';
      await this.saveCurrentRecords(this.snapshot.records);
      current();
      this.synchronizeCloud();
      this.emitSnapshot();
      this.emitPhase('connected', '同步完成');
      return true;
    });
  }

  async findDevice(): Promise<boolean> {
    if (!this.snapshot.capabilities.findDevice) return false;
    return this.runConnectedOperation('查找设备', async (current: () => void): Promise<boolean> => {
      if (this.activeProvider === 'Yuc') {
        await this.yuc().findDevice();
        current();
        this.emitPhase('connected', '已向 W8 戒指发送查找提示');
        return true;
      }
      const result = await this.sdk.deviceControlService.findDevice(true);
      current();
      const ok = result.success;
      this.emitPhase(ok ? 'connected' : 'error', ok ? '已向戒指发送查找提示' :
        (result.errorMessage ?? '戒指不支持查找设备'));
      return ok;
    });
  }

  async syncTime(): Promise<boolean> {
    return this.runConnectedOperation('同步时间', async (current: () => void): Promise<boolean> => {
      if (this.activeProvider === 'Yuc') {
        await this.yuc().syncTime();
        current();
        this.emitPhase('connected', 'W8 戒指时间已同步');
        return true;
      }
      const result = await this.sdk.deviceControlService.syncTimeNow(new Date());
      current();
      this.emitPhase(result.success ? 'connected' : 'error', result.success ? '戒指时间已同步' :
        (result.errorMessage ?? '时间同步失败'));
      return result.success;
    });
  }

  async readDeviceConfiguration(): Promise<boolean> {
    return this.runConnectedOperation('读取设备设置', async (current: () => void): Promise<boolean> => {
      if (this.activeProvider === 'Yuc') {
        current();
        const settings = emptyDeviceSettings();
        settings.loadedAt = Date.now();
        settings.unitSystem = '由戒指端管理';
        settings.timeFormat = '已随手机时间同步';
        settings.automaticHealth = '请在健康监测页设置';
        settings.sedentaryReminder = this.snapshot.capabilities.sedentaryReminder ? 'W8 SDK 暂未开放读取' : '设备不支持';
        settings.messageReminder = this.snapshot.capabilities.notification ? 'W8 SDK 暂未开放读取' : '设备不支持';
        this.snapshot.settings = settings;
        this.snapshot.message = '已读取 W8 当前可用设置';
        this.emitSnapshot();
        this.emitPhase('connected', this.snapshot.message);
        return true;
      }
      const settings = emptyDeviceSettings();
      let successes = 0;
      try {
        const result = await this.sdk.configService.getSwitchConfig();
        current();
        if (result.success && result.data) {
          settings.unitSystem = result.data.unitSystem === 1 ? '公制' : result.data.unitSystem === 2 ? '英制' : '未返回';
          settings.timeFormat = result.data.timeFormat === 1 ? '24 小时' : result.data.timeFormat === 2 ? '12 小时' : '未返回';
          settings.automaticHealth = this.automaticHealthText(result.data);
          ++successes;
        }
      } catch {}
      current();
      if (this.snapshot.capabilities.notification) {
        try {
          const result = await this.sdk.configService.getMsgSwitchConfig();
          current();
          if (result.success && result.data) {
            settings.messageReminder = this.messageReminderText(result.data);
            ++successes;
          }
        } catch {}
      } else { settings.messageReminder = '设备不支持'; }
      current();
      if (this.snapshot.capabilities.sedentaryReminder) {
        try {
          const result = await this.sdk.reminderService.getSedentaryReminder();
          current();
          if (result.success && result.data) {
            settings.sedentaryReminder = result.data.enabled ?
              `已开启 · ${result.data.startTime}-${result.data.endTime} · ${result.data.intervalMinutes} 分钟` : '已关闭';
            ++successes;
          }
        } catch {}
      } else { settings.sedentaryReminder = '设备不支持'; }
      current();
      if (this.snapshot.capabilities.alarm) {
        try {
          const result = await this.sdk.alarmClockService.readAll();
          current();
          if (result.success && result.data) {
            settings.alarms = result.data.map((item: AlarmClockItem) =>
              `${item.enabled ? '开' : '关'} · ${item.time}${item.labels ? ` · ${item.labels}` : ''}`);
            ++successes;
          }
        } catch {}
      }
      current();
      settings.loadedAt = successes > 0 ? Date.now() : 0;
      this.snapshot.settings = settings;
      this.snapshot.message = successes > 0 ? '已读取戒指实际设置' : '戒指未返回可读取的设置';
      this.emitSnapshot();
      this.emitPhase(successes > 0 ? 'connected' : 'error', this.snapshot.message);
      return successes > 0;
    });
  }

  async readDials(): Promise<boolean> {
    if (!this.snapshot.capabilities.dial) return false;
    return this.runConnectedOperation('读取表盘', async (current: () => void): Promise<boolean> => {
      const listResult = await this.sdk.dialService.getDialFileList();
      current();
      const currentResult = await this.sdk.dialService.getCurrentDial();
      current();
      if (!listResult.success || !listResult.list) {
        this.emitPhase('error', listResult.errorMessage ?? '戒指未返回可用表盘');
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
      this.snapshot.message = dials.length > 0 ? `已读取 ${dials.length} 个戒指内表盘` : '戒指未返回表盘文件';
      this.emitSnapshot();
      this.emitPhase(dials.length > 0 ? 'connected' : 'error', this.snapshot.message);
      return dials.length > 0;
    });
  }

  async setExistingDial(dialKey: string): Promise<boolean> {
    if (!this.snapshot.capabilities.dial) return false;
    return this.runConnectedOperation('切换表盘', async (current: () => void): Promise<boolean> => {
      const dial = this.dialFiles.get(dialKey);
      if (!dial) {
        this.emitPhase('error', '表盘列表已过期，请重新读取');
        return false;
      }
      const setOk = await this.sdk.dialService.setUsingDial(dial);
      current();
      if (!setOk) {
        this.emitPhase('error', '戒指未确认表盘切换');
        return false;
      }
      const readback = await this.sdk.dialService.getCurrentDial();
      current();
      const confirmed = readback.success && readback.dial && this.dialKey(readback.dial) === dialKey;
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
    });
  }

  async restoreOriginalDial(): Promise<boolean> {
    if (!this.originalDial) {
      this.emitPhase('error', '尚未读取原表盘，请先读取表盘');
      return false;
    }
    return this.setExistingDial(this.dialKey(this.originalDial));
  }

  async startMeasurement(metric: WearableMetricKey): Promise<boolean> {
    if (this.measurementStartInFlight || this.accountTeardownPending || this.accountTeardownFailed) return false;
    const pending = this.startMeasurementInternal(metric);
    this.measurementStartInFlight = pending;
    try { return await pending; }
    finally { if (this.measurementStartInFlight === pending) this.measurementStartInFlight = undefined; }
  }

  private async startMeasurementInternal(metric: WearableMetricKey): Promise<boolean> {
    if (!this.ensureConnected() || !this.supportsMetric(metric)) {
      this.emitPhase('error', '当前戒指不支持该测量项目');
      return false;
    }
    if ((metric === 'hrv' && this.activeProvider !== 'Yuc') || metric === 'activity' || metric === 'sleep' || metric === 'sport') {
      this.emitPhase('error', '该项目仅支持同步历史数据');
      return false;
    }
    if (!this.beginOperation('手动测量')) return false;
    this.invalidateMeasurementSession();
    const session: MeasurementSession = { owner: this.accountSession, connection: this.connectionGeneration,
      generation: this.measurementGeneration, ecgWearConfirmed: false };
    this.measurementSession = session;
    if (this.activeProvider === 'Vep') this.attachMeasurementEvents(session);
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
      if (this.activeProvider === 'Yuc') {
        await this.yuc().startMeasurement(metric);
        if (!this.isCurrentMeasurement(session)) return false;
        success = true;
        this.measurement.status = metric === 'ecg' ? '请正确佩戴，并持续接触心电电极' :
          `W8 正在测量${this.metricName(metric)}，请保持佩戴和静止`;
      } else if (metric === 'heart') {
        const r = await this.sdk.heartRateService.startMeasurement(HeartRateBrightness.HIGH);
        if (!this.isCurrentMeasurement(session)) return false;
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onHeartRate(r.data);
      } else if (metric === 'pressure') {
        const r = await this.sdk.bloodPressureService.startMeasurement(false);
        if (!this.isCurrentMeasurement(session)) return false;
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onBloodPressure(r);
      } else if (metric === 'oxygen') {
        const r = await this.sdk.bloodOxygenService.startMeasurement();
        if (!this.isCurrentMeasurement(session)) return false;
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
        if (!this.isCurrentMeasurement(session)) return false;
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onBodyTemperature(r.data);
      } else if (metric === 'glucose') {
        const r = await this.sdk.bloodSugarService.startMeasurement(false);
        if (!this.isCurrentMeasurement(session)) return false;
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onBloodSugar(r);
      } else if (metric === 'bloodComponents') {
        const r = await this.sdk.bloodComponentsService.startMeasurement(false);
        if (!this.isCurrentMeasurement(session)) return false;
        success = r.success; errorMessage = r.errorMessage ?? '';
        if (r.data) this.onBloodComponents(r);
      } else if (metric === 'bodyComposition') {
        const r = await this.sdk.bodyCompositionService.startMeasurement();
        if (!this.isCurrentMeasurement(session)) return false;
        success = r.success; errorMessage = r.errorMessage ?? '';
      } else if (metric === 'ecg') {
        const r = await this.sdk.ecgService.startMeasurement();
        if (!this.isCurrentMeasurement(session)) return false;
        success = r.success; errorMessage = r.errorMessage ?? '';
      }
      if (!this.measurement.running && this.measurement.metric === metric) {
        this.emitMeasurement();
        return success;
      }
      if (!success) {
        this.measurement.running = false;
        this.measurement.status = errorMessage || '戒指未接受测量指令';
        this.endOperation();
      }
      this.emitMeasurement();
      return success;
    } catch (error) {
      // A bounded user stop may settle before the vendor start promise. Ignore
      // that late rejection so it cannot overwrite the already-finished UI.
      if (!this.isCurrentMeasurement(session) || !this.measurement.running || this.measurement.metric !== metric) return false;
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

  async startSport(mode: WearableSportMode): Promise<boolean> {
    if (this.sportActive() || this.sportCommandInFlight) return false;
    if (!this.snapshot.sportCapability.modes.includes(mode)) {
      this.emitPhase('error', '当前戒指未开放由 App 开启此运动');
      return false;
    }
    const generation = ++this.sportSessionGeneration;
    this.sportSaved = false;
    this.sportSession = emptySportSession(`正在开启${sportModeLabel(mode)}…`);
    this.sportSession.phase = 'starting';
    this.sportSession.mode = mode;
    this.emitSportSession();
    await this.startLocationTracking(generation);
    if (generation !== this.sportSessionGeneration) return false;
    this.sportSession.startedAt = Date.now();
    this.sportSession.observedAt = this.sportSession.startedAt;
    const success = await this.sendSportControl('开始运动', mode, SportControlCode.START);
    if (generation !== this.sportSessionGeneration) return false;
    if (!success) {
      this.stopLocationTracking();
      this.sportSession.phase = 'error';
      this.sportSession.status = '戒指未能开始运动，请确认戒指处于可操作状态';
      this.emitSportSession();
      return false;
    }
    if (generation === this.sportSessionGeneration && this.sportSession.phase === 'starting') {
      this.sportSession.phase = 'running';
      this.sportSession.status = `${sportModeLabel(mode)}进行中`;
      this.sportSession.observedAt = Date.now();
      this.emitSportSession();
    }
    return true;
  }

  async pauseSport(): Promise<boolean> {
    if (this.sportSession.phase !== 'running' || !this.snapshot.sportCapability.supportsPause) return false;
    const generation = this.sportSessionGeneration;
    this.captureSportWallTime();
    const success = await this.sendSportControl('暂停运动', this.sportSession.mode as WearableSportMode, SportControlCode.PAUSE);
    if (generation !== this.sportSessionGeneration) return false;
    if (success && this.sportSession.phase === 'running') {
      this.sportSession.phase = 'paused';
      this.sportSession.status = '运动已暂停';
      this.sportSession.observedAt = Date.now();
      this.emitSportSession();
    }
    return success;
  }

  async resumeSport(): Promise<boolean> {
    if (this.sportSession.phase !== 'paused' || !this.snapshot.sportCapability.supportsPause) return false;
    const generation = this.sportSessionGeneration;
    const success = await this.sendSportControl('继续运动', this.sportSession.mode as WearableSportMode, SportControlCode.RESUME);
    if (generation !== this.sportSessionGeneration) return false;
    if (success && this.sportSession.phase === 'paused') {
      this.sportSession.phase = 'running';
      this.sportSession.status = '运动已继续';
      this.sportSession.observedAt = Date.now();
      this.emitSportSession();
    }
    return success;
  }

  async stopSport(): Promise<boolean> {
    if (!this.sportActive() || this.sportCommandInFlight) return false;
    const generation = this.sportSessionGeneration;
    this.captureSportWallTime();
    const previousPhase = this.sportSession.phase === 'paused' ? 'paused' : 'running';
    this.sportSession.phase = 'stopping';
    this.sportSession.status = '正在结束并保存运动…';
    this.emitSportSession();
    const mode = this.sportSession.mode as WearableSportMode;
    const success = await this.sendSportControl('结束运动', mode, SportControlCode.STOP);
    if (generation !== this.sportSessionGeneration) return false;
    if (!success) {
      this.sportSession.phase = previousPhase;
      this.sportSession.status = '戒指未确认结束，请在戒指端结束后再刷新记录';
      this.emitSportSession();
      return false;
    }
    this.finishSportSession(true, '运动已结束并保存');
    return true;
  }

  private async sendSportControl(name: string, mode: WearableSportMode, code: SportControlCode): Promise<boolean> {
    if (this.sportCommandInFlight) return false;
    const operation = this.runConnectedOperation(name, async (current: () => void): Promise<boolean> => {
      if (this.activeProvider === 'Yuc') {
        await this.yuc().sport(Number(code), mode);
        current();
        return true;
      }
      if (this.snapshot.sportCapability.protocol === 'mode') {
        const control = code === SportControlCode.START ? SportModeControl.OPEN : SportModeControl.CLOSE;
        const result = await this.sdk.sportService.setMode(control, sportModeProtocolValue(mode));
        current();
        if (!result.success) throw new Error(result.errorMessage || `${name}失败`);
        return true;
      }
      const result = await this.sdk.sportService.setControl(sportModeProtocolValue(mode), code);
      current();
      if (!result.success) throw new Error(result.errorMessage || `${name}失败`);
      this.applySportControlRecords(result.data ?? []);
      return true;
    });
    const settling = operation.then(() => {}, () => {});
    this.sportCommandInFlight = settling;
    try { return await operation; }
    finally { if (this.sportCommandInFlight === settling) this.sportCommandInFlight = undefined; }
  }

  private onSportControlPush = (event: SportControlPushEvent): void => {
    if (!this.snapshot.connected || !event.data || event.data.length === 0) return;
    const latest = event.data[event.data.length - 1];
    const mode = sportModeFromProtocolValue(latest.motionType);
    if (!this.sportActive() && latest.code === SportControlCode.START && mode &&
      this.snapshot.sportCapability.modes.includes(mode)) {
      const generation = ++this.sportSessionGeneration;
      this.sportSaved = false;
      this.sportSession = emptySportSession(`${sportModeLabel(mode)}已从戒指开始`);
      this.sportSession.phase = 'running';
      this.sportSession.mode = mode;
      this.sportSession.startedAt = Date.now();
      this.startLocationTracking(generation);
    }
    if (!this.sportActive()) return;
    if (mode && mode !== this.sportSession.mode) return;
    this.applySportControlRecords(event.data);
    if (latest.code === SportControlCode.STOP) this.finishSportSession(true, '运动已在戒指端结束并保存');
  };

  private onSportModePush = (event: SportModePushEvent): void => {
    if (!this.snapshot.connected || !event.data) return;
    const mode = sportModeFromProtocolValue(event.data.type);
    if (event.data.kind === SportModePushKind.OPEN && !this.sportActive() && mode &&
      this.snapshot.sportCapability.modes.includes(mode)) {
      const generation = ++this.sportSessionGeneration;
      this.sportSaved = false;
      this.sportSession = emptySportSession(`${sportModeLabel(mode)}已从戒指开始`);
      this.sportSession.phase = 'running';
      this.sportSession.mode = mode;
      this.sportSession.startedAt = Date.now();
      this.sportSession.observedAt = this.sportSession.startedAt;
      this.startLocationTracking(generation);
      this.emitSportSession();
    } else if (event.data.kind === SportModePushKind.CLOSE && this.sportActive() &&
      (!mode || mode === this.sportSession.mode)) {
      this.finishSportSession(true, '运动已在戒指端结束并保存');
    }
  };

  private applySportControlRecords(records: SportControlRecord[]): void {
    if (!this.sportActive() || records.length === 0) return;
    records.forEach((record: SportControlRecord) => {
      const returnedMode = sportModeFromProtocolValue(record.motionType);
      if (returnedMode && returnedMode !== this.sportSession.mode) return;
      if (record.code === SportControlCode.PAUSE) this.sportSession.phase = 'paused';
      else if (record.code === SportControlCode.RESUME || record.code === SportControlCode.START) this.sportSession.phase = 'running';
      this.sportSession.durationSeconds = Math.max(this.sportSession.durationSeconds,
        Number.isFinite(record.motionTimes) ? Math.max(0, Math.round(record.motionTimes)) : 0);
      this.sportSession.distanceKm = Math.max(this.sportSession.distanceKm, sportDistanceKilometers(record.motionDistance));
      if (Number.isFinite(record.calorie) && record.calorie > 0) this.sportSession.calories = record.calorie;
      if (Number.isFinite(record.heartRate) && record.heartRate >= 20 && record.heartRate <= 240) this.sportSession.heartRate = record.heartRate;
      this.sportSession.observedAt = Date.now();
    });
    this.sportSession.status = this.sportSession.phase === 'paused' ? '运动已暂停' :
      `${sportModeLabel(this.sportSession.mode)}进行中`;
    this.emitSportSession();
  }

  private sportActive(): boolean {
    return ['starting', 'running', 'paused', 'stopping'].includes(this.sportSession.phase);
  }

  private captureSportWallTime(): void {
    if (this.sportSession.phase !== 'running' || this.sportSession.observedAt <= 0) return;
    const now = Date.now();
    this.sportSession.durationSeconds += Math.max(0, Math.floor((now - this.sportSession.observedAt) / 1000));
    this.sportSession.observedAt = now;
  }

  private finishSportSession(save: boolean, status: string): void {
    this.captureSportWallTime();
    this.stopLocationTracking();
    if (!this.sportActive()) return;
    const finishedAt = Date.now();
    if (this.sportSession.durationSeconds <= 0 && this.sportSession.startedAt > 0) {
      this.sportSession.durationSeconds = Math.max(1, Math.round((finishedAt - this.sportSession.startedAt) / 1000));
    }
    this.sportSession.routeDistanceKm = routeDistanceKilometers(this.sportSession.route);
    this.sportSession.phase = save ? 'completed' : 'error';
    this.sportSession.observedAt = finishedAt;
    this.sportSession.status = status;
    if (save && !this.sportSaved && this.sportSession.mode && this.connectedKey && validHealthOwner(this.accountSession.ownerId)) {
      const values: HealthValue[] = [];
      this.pushValue(values, healthValue('时长', this.sportSession.durationSeconds, '秒'));
      if (this.sportSession.distanceKm > 0) this.pushValue(values, healthValue('距离', this.sportSession.distanceKm, 'km'));
      else this.pushValue(values, healthValue('轨迹距离', this.sportSession.routeDistanceKm, 'km'));
      this.pushValue(values, healthValue('热量', this.sportSession.calories, 'kcal'));
      this.pushValue(values, boundedHealthValue('心率', this.sportSession.heartRate, 'BPM', 20, 240));
      const record = this.makeRecord('sport', this.sportSession.startedAt, values, 'app_measurement');
      record.sport = {
        mode: this.sportSession.mode,
        durationSeconds: this.sportSession.durationSeconds,
        distanceKm: this.sportSession.distanceKm,
        routeDistanceKm: this.sportSession.routeDistanceKm,
        steps: this.sportSession.steps,
        calories: this.sportSession.calories,
        heartRate: this.sportSession.heartRate,
        route: this.sportSession.route.slice()
      };
      this.sportSaved = true;
      this.addRecord(record);
      this.persistSportRecord(record);
    }
    this.emitSportSession();
    this.emitSnapshot();
  }

  private persistSportRecord(record: HealthRecord): void {
    const session = this.accountSession;
    const generation = this.sportSessionGeneration;
    if (!recordWithinOwnership(record, this.ownershipSince, Date.now())) return;
    wearableHealthStore.saveRecords(session.ownerId, [record],
      (): boolean => sameHealthSession(session, this.accountSession)).catch(() => {
      if (!sameHealthSession(session, this.accountSession) || generation !== this.sportSessionGeneration) return;
      this.sportSession.status = '运动已结束，但本机保存失败，请重试同步';
      this.emitSportSession();
    });
  }

  private async startLocationTracking(generation: number): Promise<void> {
    this.stopLocationTracking();
    if (!await this.requestPermissions() || generation !== this.sportSessionGeneration || !this.sportActive()) {
      if (generation === this.sportSessionGeneration) {
        this.sportSession.locationStatus = '未获得定位权限，仍会记录戒指运动数据';
        this.emitSportSession();
      }
      return;
    }
    const connection = this.connectionGeneration;
    this.locationListener = (location: geoLocationManager.Location): void => {
      if (generation !== this.sportSessionGeneration || connection !== this.connectionGeneration || !this.sportActive()) return;
      const point: SportRoutePoint = {
        latitude: location.latitude, longitude: location.longitude,
        timestamp: location.timeStamp > 0 ? location.timeStamp : Date.now(), accuracy: location.accuracy
      };
      const route = appendSportRoutePoint(this.sportSession.route, point);
      if (route === this.sportSession.route) return;
      this.sportSession.route = route;
      this.sportSession.routeDistanceKm = routeDistanceKilometers(route);
      this.sportSession.locationStatus = route.length > 1 ? '正在记录手机前台轨迹' : '已获取位置，等待形成轨迹';
      this.emitSportSession();
    };
    try {
      const request: geoLocationManager.LocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.TRAJECTORY_TRACKING,
        timeInterval: 3, distanceInterval: 3, maxAccuracy: 80
      };
      geoLocationManager.on('locationChange', request, this.locationListener);
      this.sportSession.locationStatus = '正在等待定位';
    } catch {
      this.locationListener = undefined;
      this.sportSession.locationStatus = '定位服务暂不可用，仍会记录戒指运动数据';
    }
    this.emitSportSession();
  }

  private stopLocationTracking(): void {
    if (!this.locationListener) return;
    try { geoLocationManager.off('locationChange', this.locationListener); } catch {}
    this.locationListener = undefined;
  }

  shutdown(): void {
    this.stopScan();
    this.cancelReconnect();
    this.userDisconnect = true;
    this.finishSportSession(true, 'App 已关闭，运动记录已保留');
    ++this.connectionGeneration;
    this.invalidateMeasurementSession();
    try {
      if (this.activeProvider === 'Yuc') this.yuc().disconnect(false).catch(() => {});
      else this.sdk.disconnect();
    } catch {}
    this.detachEvents();
    this.yucAdapter?.shutdown();
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
      if (wearableProviderForName(device.deviceName) !== 'Vep') return;
      const descriptor = createWearableDevice('Vep', device.deviceName, device.deviceId,
        device.mac, device.rssi, device.connectable);
      if (descriptor) {
        incoming.push(descriptor);
        this.vepDevices.set(descriptor.key, device);
      }
    });
    normalized.forEach((result: ble.ScanResult) => {
      const provider = knownWearableName(result.deviceName);
      // The available Moyoung sample is for glasses, not the target ring.
      // Recognize D-prefixed devices centrally but keep them out of the UI
      // until the licensed ring transport is integrated and verified.
      if (!provider || provider === 'Moyoung' || vepResults.some((device: BleDevice) =>
        device.deviceId === result.deviceId && provider === 'Vep')) return;
      const raw = results.find((item: ble.ScanResult) => item.deviceId === result.deviceId) ?? result;
      const mac = provider === 'Yuc' ? this.yuc().macFromScan(raw) : '';
      const descriptor = createWearableDevice(provider, result.deviceName, result.deviceId,
        mac, result.rssi, result.connectable);
      if (!descriptor) return;
      incoming.push(descriptor);
      if (provider === 'Vep') {
        // Official demo also connects a BleDevice with an empty mac. Never copy
        // the Harmony transport address into the hardware MAC field.
        this.vepDevices.set(descriptor.key, { deviceId: result.deviceId,
          deviceName: result.deviceName, mac: '', rssi: result.rssi, connectable: result.connectable });
      } else {
        this.yucDevices.set(descriptor.key, raw);
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
          if (!provider || provider === 'Moyoung') return;
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
    this.sdk.sportService.onControlPush(this.onSportControlPush);
    this.sdk.sportService.onModePush(this.onSportModePush);
  }

  private detachEvents(): void {
    if (!this.eventsAttached) return;
    this.eventsAttached = false;
    this.sdk.off(SDKEventType.CONNECTION_STATE_CHANGED, this.onConnectionState);
    this.sdk.sportService.offControlPush(this.onSportControlPush);
    this.sdk.sportService.offModePush(this.onSportModePush);
    this.detachMeasurementEvents();
  }

  private isCurrentMeasurement(session: MeasurementSession | undefined): boolean {
    return session !== undefined && session.generation === this.measurementGeneration &&
      session.connection === this.connectionGeneration && sameHealthSession(session.owner, this.accountSession) &&
      !this.accountTeardownPending && !this.accountTeardownFailed;
  }

  private invalidateMeasurementSession(): void {
    ++this.measurementGeneration;
    this.measurementSession = undefined;
    this.detachMeasurementEvents();
  }

  private attachMeasurementEvents(session: MeasurementSession): void {
    const listeners: MeasurementListeners = {
      heart: (data: HeartRateMeasurement) => { if (this.isCurrentMeasurement(session)) this.onHeartRate(data); },
      pressure: (data: BloodPressureResult) => { if (this.isCurrentMeasurement(session)) this.onBloodPressure(data); },
      oxygen: (data: SpO2Result) => { if (this.isCurrentMeasurement(session)) this.onOxygen(data); },
      temperature: (data: BodyTempMeasurement) => { if (this.isCurrentMeasurement(session)) this.onBodyTemperature(data); },
      glucose: (data: BloodSugarResult) => { if (this.isCurrentMeasurement(session)) this.onBloodSugar(data); },
      blood: (data: BloodComponentsResult) => { if (this.isCurrentMeasurement(session)) this.onBloodComponents(data); },
      body: (data: BodyCompPushEvent) => { if (this.isCurrentMeasurement(session)) this.onBodyComposition(data); },
      ecg: (data: EcgPushEvent) => { if (this.isCurrentMeasurement(session)) this.onEcg(data); }
    };
    this.measurementListeners = listeners;
    this.sdk.heartRateService.onHeartRatePush(listeners.heart);
    this.sdk.bloodPressureService.onBloodPressurePush(listeners.pressure);
    this.sdk.bloodOxygenService.onSpO2Push(listeners.oxygen);
    this.sdk.bodyTemperatureService.onBodyTempPush(listeners.temperature);
    this.sdk.bloodSugarService.onBloodSugarPush(listeners.glucose);
    this.sdk.bloodComponentsService.onBloodComponentsPush(listeners.blood);
    this.sdk.bodyCompositionService.onBodyCompPush(listeners.body);
    this.sdk.ecgService.onEcgPush(listeners.ecg);
  }

  private detachMeasurementEvents(): void {
    const listeners = this.measurementListeners;
    if (!listeners) return;
    this.measurementListeners = undefined;
    this.sdk.heartRateService.offHeartRatePush(listeners.heart);
    this.sdk.bloodPressureService.offBloodPressurePush(listeners.pressure);
    this.sdk.bloodOxygenService.offSpO2Push(listeners.oxygen);
    this.sdk.bodyTemperatureService.offBodyTempPush(listeners.temperature);
    this.sdk.bloodSugarService.offBloodSugarPush(listeners.glucose);
    this.sdk.bloodComponentsService.offBloodComponentsPush(listeners.blood);
    this.sdk.bodyCompositionService.offBodyCompPush(listeners.body);
    this.sdk.ecgService.offEcgPush(listeners.ecg);
  }

  private onConnectionState = (payload: ESObject): void => {
    if (this.activeProvider !== 'Vep') return;
    const event = payload as ConnectionEvent;
    if (event.newState === ConnectionState.DISCONNECTED && !this.userDisconnect && this.lastDevice) {
      this.finishSportSession(true, '戒指断开，已保留断开前的真实运动数据');
      ++this.connectionGeneration;
      this.invalidateMeasurementSession();
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
      this.snapshot.message = '戒指连接已中断';
      this.emitSnapshot();
      this.emitSportSession();
      this.scheduleReconnect();
    }
  };

  private onYucState(state: number): void {
    console.info(`[SaydianWearable] W8 state=${state}`);
    if (this.yuc().isReady()) {
      this.tryAdoptYucConnection();
      return;
    }
    if (this.activeProvider !== 'Yuc' || !this.snapshot.connected || this.userDisconnect) return;
    this.finishSportSession(true, 'W8 戒指断开，已保留断开前的真实运动数据');
    const generation = ++this.connectionGeneration;
    this.invalidateMeasurementSession();
    if (this.measurement.running) {
      this.measurement.running = false;
      this.measurement.values = [];
      this.measurement.samples = [];
      this.measurement.sampleFrequency = 0;
      this.measurement.status = '测量因蓝牙中断已取消，未保存不完整结果';
      this.emitMeasurement();
    }
    this.busyOperation = '';
    this.snapshot.connected = false;
    this.snapshot.battery = emptyBattery();
    this.snapshot.message = 'W8 连接中断，正在自动重连';
    this.emitSnapshot();
    this.emitSportSession();
    this.emitPhase('connecting', this.snapshot.message);
    setTimeout(() => {
      if (generation === this.connectionGeneration && !this.snapshot.connected && !this.scanning &&
        !this.userDisconnect && this.activeProvider === 'Yuc') this.startScan();
    }, 10000);
  }

  private onYucBattery(level: number, state: number): void {
    if (this.activeProvider !== 'Yuc' || !this.snapshot.connected || level < 0 || level > 100) return;
    this.snapshot.battery = { available: true, hasPercentage: true, level: level, levelGrade: 0,
      charging: state === 1, lowBattery: level <= 15, updatedAt: Date.now() };
    this.emitSnapshot();
  }

  private onYucRealtime(data: YucRealtimeHealth): void {
    if (this.activeProvider !== 'Yuc' || !this.measurement.running || !this.measurement.metric) return;
    const metric = this.measurement.metric;
    if (data.metric !== metric) return;
    const values: HealthValue[] = [];
    data.values.forEach((item) => {
      const value = healthValue(item.name, item.value, item.unit);
      if (value) values.push(value);
    });
    if (values.length > 0) this.measurement.values = values;
    if (metric === 'ecg' && data.samples.length > 0) {
      this.measurement.samples = this.measurement.samples.concat(data.samples).slice(-60000);
      if (data.sampleFrequency > 0) this.measurement.sampleFrequency = data.sampleFrequency;
    }
    this.measurement.progress = Math.min(95, Math.max(5, this.measurement.progress + 2));
    this.measurement.status = metric === 'ecg' ? '正在采集 W8 真实心电波形，请持续接触电极' :
      `正在接收 W8 ${this.metricName(metric)}读数`;
    this.emitMeasurement();
  }

  private onYucMeasurementEnd(metric: WearableMetricKey): void {
    const session = this.measurementSession;
    if (!this.isCurrentMeasurement(session) || !this.measurement.running || this.measurement.metric !== metric) return;
    const finish = (record?: HealthRecord): void => {
      if (!this.isCurrentMeasurement(session) || !this.measurement.running || this.measurement.metric !== metric) return;
      if (this.measurement.values.length === 0 && record) this.measurement.values = record.values.slice();
      if ((metric === 'ecg' && this.measurement.samples.length > 1) || this.measurement.values.length > 0) {
        this.completeMeasurement();
      } else {
        this.measurement.running = false;
        this.measurement.progress = 0;
        this.measurement.status = 'W8 未返回有效读数，请正确佩戴并保持静止后重试';
        this.endOperation();
        this.emitMeasurement();
      }
    };
    if (metric !== 'ecg' && this.measurement.values.length === 0) {
      this.yuc().latestMetric(this.connectedKey, metric).then((record?: HealthRecord) => finish(record))
        .catch(() => finish());
    } else finish();
  }

  private onYucSport(data: YucSportTelemetry): void {
    if (this.activeProvider !== 'Yuc' || !this.sportActive()) return;
    this.sportSession.steps = Math.max(this.sportSession.steps, Math.round(data.steps));
    this.sportSession.distanceKm = Math.max(this.sportSession.distanceKm, data.distanceMeters / 1000);
    this.sportSession.calories = Math.max(this.sportSession.calories, data.calories);
    this.sportSession.durationSeconds = Math.max(this.sportSession.durationSeconds, Math.round(data.durationSeconds));
    if (data.heartRate >= 20 && data.heartRate <= 240) this.sportSession.heartRate = data.heartRate;
    this.sportSession.observedAt = Date.now();
    this.sportSession.status = `${sportModeLabel(this.sportSession.mode as WearableSportMode)}数据同步中`;
    this.emitSportSession();
  }

  private tryAdoptYucConnection(): void {
    if (!this.yuc().isReady() || this.restoreConnectPending || this.snapshot.connected || this.busyOperation ||
      this.lastBinding?.provider !== 'Yuc' || !validHealthOwner(this.accountSession.ownerId)) return;
    const binding = this.lastBinding;
    const descriptor = createWearableDevice('Yuc', binding.name, `sdk-reconnect-${binding.mac}`,
      binding.mac, 0, true);
    if (!descriptor) return;
    this.restoreConnectPending = true;
    const session = this.accountSession;
    const generation = ++this.connectionGeneration;
    this.activeProvider = 'Yuc';
    this.connectedKey = descriptor.key;
    this.busyOperation = '恢复 W8 连接';
    this.refreshYucDeviceInternal(generation, descriptor, true).then(async (): Promise<void> => {
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration) ||
        !sameHealthSession(session, this.accountSession)) return;
      const current = (): boolean => generation === this.connectionGeneration &&
        sameHealthSession(session, this.accountSession);
      this.ownershipSince = await wearableHealthStore.claimDevice(session.ownerId, descriptor.key,
        Date.now(), true, current);
      if (!current()) return;
      await this.loadStoredRecords(descriptor.key);
      if (!current()) return;
      this.emitPhase('connected', `已自动恢复 ${this.snapshot.deviceName}`);
      setTimeout(() => this.postConnectInitialize(generation), 3000);
    }).catch((error: Error) => {
      if (generation === this.connectionGeneration) {
        this.snapshot = emptyWearableSnapshot();
        this.snapshot.message = this.bluetoothError(error, '恢复 W8 连接失败');
        this.emitSnapshot();
        this.emitPhase('error', this.snapshot.message);
      }
    }).finally(() => {
      if (generation === this.connectionGeneration) this.busyOperation = '';
      this.restoreConnectPending = false;
    });
  }

  private scheduleReconnect(): void {
    if (this.activeProvider !== 'Vep' || this.reconnectTimer !== -1 || this.userDisconnect) return;
    if (!this.lastDevice || this.reconnectAttempt >= WEARABLE_RECONNECT_DELAYS_MS.length) {
      this.emitPhase('error', '自动重连未成功，请确认戒指未被其他手机占用后手动重连');
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
    if (this.activeProvider === 'Yuc') {
      await this.refreshYucDeviceInternal(generation, fallback, includeBattery);
      return;
    }
    const device = this.sdk.getConnectedDevice();
    if (!device || !isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
      throw new Error('设备连接状态已变化');
    }
    const capabilities: WearableCapabilities = capabilitiesFromFeatureList(device.featureList ?? undefined);
    const sportCapability = sportCapabilityFromFeatureList(device.featureList ?? undefined);
    console.info(`[SaydianWearable] sport modes=${device.featureList?.sportModeCount ?? 0} ` +
      `type=${device.featureList?.sportModeType ?? 0} realtime=${device.featureList?.daSportControl ?? 0}`);
    const sameDevice = this.snapshot.deviceKey === this.connectedKey;
    if (!sameDevice) {
      this.dialFiles.clear();
      this.originalDial = null;
    }
    this.snapshot = {
      provider: 'Vep',
      connected: true,
      deviceKey: this.connectedKey,
      deviceName: device.deviceName || fallback?.name || 'Say Ring戒指',
      mac: normalizeMac(device.mac || fallback?.mac || ''),
      model: device.modelName || '',
      firmware: device.firmwareVersion || device.deviceVersion || '',
      capabilities: capabilities,
      sportCapability: sportCapability,
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
    if (isCurrentConnectionGeneration(generation, this.connectionGeneration)) this.emitSnapshot();
  }

  private async refreshYucDeviceInternal(generation: number, fallback?: WearableDevice,
    includeBattery: boolean = true): Promise<void> {
    if (!this.yuc().isReady() || !isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
      throw new Error('W8 设备连接状态已变化');
    }
    const flags = this.yuc().featureFlags();
    const capabilities: WearableCapabilities = yucCapabilitiesFromFlags(flags);
    const sportCapability = yucSportCapabilityFromFlags(flags);
    const sameDevice = this.snapshot.deviceKey === this.connectedKey;
    let mac = fallback?.mac || this.lastBinding?.mac || '';
    let model = 'W8 系列';
    let firmware = '';
    let battery = sameDevice ? this.snapshot.battery : emptyBattery();
    try {
      const metadata = await this.yuc().metadata();
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      mac = metadata.mac || mac;
      model = metadata.model || model;
      firmware = metadata.firmware || firmware;
      if (includeBattery && metadata.batteryLevel >= 0 && metadata.batteryLevel <= 100) {
        battery = { available: true, hasPercentage: true, level: metadata.batteryLevel,
          levelGrade: 0, charging: metadata.batteryState === 1, lowBattery: metadata.batteryLevel <= 15,
          updatedAt: Date.now() };
      }
    } catch (error) {
      console.warn(`[SaydianWearable] W8 metadata read skipped: ${(error as Error).message}`);
    }
    if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
    this.snapshot = {
      provider: 'Yuc', connected: true, deviceKey: this.connectedKey,
      deviceName: fallback?.name || this.lastBinding?.name || 'Say Ring W8 戒指',
      mac: normalizeMac(mac), model: model, firmware: firmware,
      capabilities: capabilities, sportCapability: sportCapability, battery: battery,
      records: sameDevice ? this.snapshot.records : [],
      settings: sameDevice ? this.snapshot.settings : emptyDeviceSettings(),
      dials: [], currentDialKey: '', originalDialKey: '',
      syncedAt: sameDevice ? this.snapshot.syncedAt : 0,
      message: 'W8 设备已认证'
    };
    this.emitSnapshot();
  }

  private async syncHistoryInternal(generation: number, days: HealthQueryDay[], includeAdvanced: boolean = true): Promise<void> {
    if (this.activeProvider === 'Yuc') {
      const records = await this.yuc().readHistory(this.connectedKey, includeAdvanced);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      records.forEach((record: HealthRecord) => this.addRecord(record));
      this.snapshot.records = this.snapshot.records.slice()
        .sort((a: HealthRecord, b: HealthRecord) => b.timestamp - a.timestamp);
      this.emitSnapshot();
      return;
    }
    for (const day of days) {
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      const health = await this.sdk.healthService.getHealthData(day, 1);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      if (health.success && health.data) this.addDailyHealth(day, health.data);
      const sleep = await this.sdk.healthService.getSleepData(day);
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
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
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      if (idResult.success && idResult.id && idResult.id > 0) {
        const history = await this.sdk.ecgService.getHistory(idResult.id);
        if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
        if (history.success && history.data) this.addEcgHistory(history.data);
      }
    }
    if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
    if (this.snapshot.capabilities.bodyComposition) {
      const ids = await this.sdk.bodyCompositionService.getSavedIds();
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      if (ids.success && ids.data) {
        for (const item of ids.data) {
          const history = await this.sdk.bodyCompositionService.getHistory(item.id);
          if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
          if (history.success && history.data) {
            const values = this.bodyCompositionValues(history.data.data);
            const timestamp = Date.parse(history.data.dateTime.replace(' ', 'T'));
            if (values.length > 0) this.addRecord(this.makeRecord('bodyComposition',
              Number.isFinite(timestamp) ? timestamp : 0, values));
          }
        }
      }
    }
    if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
    if (this.snapshot.capabilities.sport) {
      const crcResult = await this.sdk.sportService.readModeCrc();
      if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
      const crc = crcResult.data;
      if (crcResult.success && crc) {
        const slots: SportDataSlot[] = [];
        if (crc.crc0 > 0) slots.push(SportDataSlot.CRC0);
        if (crc.crc1 > 0) slots.push(SportDataSlot.CRC1);
        if (crc.crc2 > 0) slots.push(SportDataSlot.CRC2);
        for (const slot of slots) {
          const result = await this.sdk.sportService.readData(slot);
          if (!isCurrentConnectionGeneration(generation, this.connectionGeneration)) return;
          if (result.success && result.data) {
            const values: HealthValue[] = [];
            this.pushValue(values, healthValue('步数', result.data.allStep, '步'));
            this.pushValue(values, healthValue('距离', sportDistanceKilometers(result.data.allDistance), 'km'));
            this.pushValue(values, healthValue('热量', result.data.allCalorie, 'kcal'));
            this.pushValue(values, healthValue('时长', result.data.allMotion, '秒'));
            const timestamp = Date.parse(result.data.startTime.replace(' ', 'T'));
            if (values.length > 0) {
              const record = this.makeRecord('sport', Number.isFinite(timestamp) ? timestamp : 0, values);
              record.sport = {
                mode: sportModeFromProtocolValue(result.data.motionType),
                durationSeconds: Math.max(0, Math.round(result.data.allMotion)),
                distanceKm: sportDistanceKilometers(result.data.allDistance), routeDistanceKm: 0,
                steps: Math.max(0, Math.round(result.data.allStep)), calories: Math.max(0, result.data.allCalorie),
                heartRate: 0, route: []
              };
              this.addRecord(record);
            }
          } else if (result.success && result.dataA704?.motionData) {
            const motion = result.dataA704.motionData;
            const values: HealthValue[] = [];
            this.pushValue(values, healthValue('步数', motion.allStep, '步'));
            this.pushValue(values, healthValue('距离', sportDistanceKilometers(motion.allDistance), 'km'));
            this.pushValue(values, healthValue('热量', motion.allCalorie, 'kcal'));
            this.pushValue(values, healthValue('时长', motion.allDuration, '秒'));
            this.pushValue(values, boundedHealthValue('平均心率', motion.aveHeartRate, 'BPM', 20, 240));
            const timestamp = Date.parse(motion.startTime.replace(' ', 'T'));
            if (values.length > 0) {
              const startedAt = Number.isFinite(timestamp) ? timestamp : 0;
              const route: SportRoutePoint[] = [];
              result.dataA704.list.forEach((sample, index: number) => {
                if (Number.isFinite(sample.latitude) && Number.isFinite(sample.longitude) &&
                  Math.abs(sample.latitude ?? 0) <= 90 && Math.abs(sample.longitude ?? 0) <= 180 &&
                  sample.latitude !== 0 && sample.longitude !== 0) {
                  route.push({ latitude: sample.latitude ?? 0, longitude: sample.longitude ?? 0,
                    timestamp: startedAt > 0 ? startedAt + index : index + 1, accuracy: 0 });
                }
              });
              const record = this.makeRecord('sport', startedAt, values);
              record.sport = {
                // The SDK exposes module/data protocol fields here, but does not
                // document either as the user-facing sport type. Keep it unknown.
                mode: '',
                durationSeconds: Math.max(0, Math.round(motion.allDuration)),
                distanceKm: sportDistanceKilometers(motion.allDistance), routeDistanceKm: routeDistanceKilometers(route),
                steps: Math.max(0, Math.round(motion.allStep)), calories: Math.max(0, motion.allCalorie),
                heartRate: motion.aveHeartRate >= 20 && motion.aveHeartRate <= 240 ? motion.aveHeartRate : 0,
                route: route
              };
              this.addRecord(record);
            }
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
    const record = this.makeRecord('ecg', Number.isFinite(timestamp) ? timestamp : 0, values);
    record.samples = samples;
    record.sampleFrequency = data.sampleFrequency;
    this.addRecord(record);
  }

  private onHeartRate = (data: HeartRateMeasurement): void => {
    if (this.measurement.metric !== 'heart' || !this.measurement.running) return;
    const value = boundedHealthValue('心率', data.heartRate, 'BPM', 20, 240);
    if (!value) {
      this.measurement.values = [];
      this.measurement.status = '等待戒指获得有效心率，请正确佩戴并保持静止';
      this.emitMeasurement();
      return;
    }
    this.measurement.values = [value];
    this.measurement.status = '已收到戒指实时心率';
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
      this.measurement.status = '等待戒指获得有效血氧，请正确佩戴并保持静止';
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
    if (this.measurement.metric !== 'ecg' || !this.measurement.running || this.measurementStopping) return;
    const session = this.measurementSession;
    if (!session) return;
    if (event.kind === EcgPushEventKind.INSTRUCTION) {
      const data = event.data as EcgInstruction;
      this.measurement.sampleFrequency = data.samplingFreq;
      this.measurement.status = '请保持佩戴并持续接触心电电极';
    } else if (event.kind === EcgPushEventKind.WAVEFORM) {
      const data = event.data as EcgWaveformData;
      this.measurement.samples = this.measurement.samples.concat(data.samples).slice(-60000);
      this.measurement.status = '正在采集心电信号，请保持佩戴';
    } else if (event.kind === EcgPushEventKind.PROGRESS) {
      const data = event.data as EcgSecondMeasurement;
      // Veepoo ECG transport: wear=0 is confirmed, wear=1 is lead failure.
      // Other codes are unknown, not a medical assessment or proof of contact.
      session.ecgWearConfirmed = data.wearStatus === 0;
      if (data.wearStatus === 1) {
        this.measurement.values = [];
        this.cancelEcgWithGuidance('请调整佩戴并持续接触电极后重试');
        return;
      }
      this.measurement.progress = Math.max(0, Math.min(100, data.progress));
      this.measurement.values = session.ecgWearConfirmed ? this.validValues([
        healthValue('心率', data.hrPerMinute, 'BPM'), this.ecgHrvValue(data.hrv), healthValue('QT', data.qtc, 'ms')]) : [];
      this.measurement.status = session.ecgWearConfirmed ? `心电测量 ${this.measurement.progress}%` :
        '请保持佩戴并接触电极，等待有效读数';
    } else if (event.kind === EcgPushEventKind.RESULT) {
      if (!session.ecgWearConfirmed) {
        this.cancelEcgWithGuidance('未确认有效佩戴，请调整后重新测量');
        return;
      }
      const data = event.data as EcgDiagnosis;
      this.measurement.values = this.validValues([
        healthValue('心率', data.heartRate, 'BPM'), this.ecgHrvValue(data.hrv),
        healthValue('QT', data.qtc, 'ms'), healthValue('SDNN', data.sdnn, 'ms'), healthValue('RMSSD', data.rmssd, 'ms')]);
      this.measurement.progress = 100;
      this.completeMeasurement();
      return;
    }
    this.emitMeasurement();
  };

  private ecgHrvValue(value: number): HealthValue | undefined {
    // 255 is Veepoo's ECG HRV invalid marker, not a clinical upper limit.
    return value === 255 ? undefined : healthValue('HRV', value, 'ms');
  }

  private async cancelEcgWithGuidance(message: string): Promise<void> {
    const measurement = this.measurement, session = this.measurementSession;
    await this.cancelMeasurement(false);
    // Cancellation invalidates its session. Identity plus owner/connection checks
    // prevent this late completion from replacing a new measurement or account UI.
    if (this.measurement !== measurement || this.measurement.running || !session ||
      session.connection !== this.connectionGeneration || !sameHealthSession(session.owner, this.accountSession)) return;
    this.measurement.status = message;
    this.emitMeasurement();
  }

  private async cancelMeasurement(shutdown: boolean): Promise<void> {
    if (this.measurementStopInFlight) { await this.measurementStopInFlight; return; }
    const pending = this.cancelMeasurementInternal(shutdown);
    this.measurementStopInFlight = pending;
    try { await pending; }
    finally { if (this.measurementStopInFlight === pending) this.measurementStopInFlight = undefined; }
  }

  private async cancelMeasurementInternal(shutdown: boolean): Promise<void> {
    const session = this.measurementSession;
    if (!this.measurement.running || !this.measurement.metric) {
      if (this.busyOperation === '手动测量') this.endOperation();
      return;
    }
    if (this.measurementStopping) return;
    this.measurementStopping = true;
    this.detachMeasurementEvents();
    const metric = this.measurement.metric;
    const values = retainedMeasurementValues(this.measurement.values, this.lastValidMeasurementValues);
    if (!shutdown) {
      this.measurement.status = '正在结束测量…';
      this.emitMeasurement();
    }
    try {
      await this.withTimeout(this.requestMeasurementStop(metric), WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS, '结束测量超时');
    } catch {}
    if (!this.isCurrentMeasurement(session)) return;
    this.measurement.running = false;
    if (metric === 'ecg') {
      this.measurement.values = [];
      this.measurement.samples = [];
      this.measurement.sampleFrequency = 0;
      this.measurement.status = shutdown ? '' : '已取消心电测量，未保存未完成波形';
    } else if (values.length > 0 && !shutdown) {
      this.measurement.values = values;
      this.measurement.status = '测量已结束，已保留戒指实时读数';
      this.addMeasurementRecord();
    } else {
      this.measurement.status = shutdown ? '' : '已取消测量，未收到有效读数';
    }
    this.measurementStopping = false;
    this.invalidateMeasurementSession();
    this.endOperation();
    this.emitMeasurement();
  }

  private async requestMeasurementStop(metric: WearableMetricKey): Promise<void> {
    if (this.activeProvider === 'Yuc') await this.yuc().stopMeasurement(metric);
    else if (metric === 'heart') await this.sdk.heartRateService.stopMeasurement();
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
    this.detachMeasurementEvents();
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
    const time = Number.isFinite(timestamp) && timestamp > 0 ? Math.round(timestamp) : 0;
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
    if (!this.snapshot.connected || !validHealthOwner(this.accountSession.ownerId) || record.deviceKey !== this.connectedKey ||
      !recordWithinOwnership(record, this.ownershipSince, Date.now())) return;
    const map: Map<string, HealthRecord> = new Map();
    this.snapshot.records.forEach((item: HealthRecord) => map.set(item.id, item));
    map.set(record.id, record);
    this.snapshot.records = Array.from(map.values());
  }

  private initializeStorage(): void {
    if (!this.context) return;
    const session = this.accountSession;
    wearableHealthStore.open(this.context).then(async () => {
      if (!sameHealthSession(session, this.accountSession)) return;
      const binding = await wearableHealthStore.loadBinding(session.ownerId);
      if (!sameHealthSession(session, this.accountSession)) return;
      this.lastBinding = binding;
      this.synchronizeCloud();
      this.tryAdoptYucConnection();
      if (this.lastBinding && !this.snapshot.connected && !this.scanning && !this.busyOperation) {
        setTimeout(() => {
          if (sameHealthSession(session, this.accountSession) && !this.snapshot.connected && !this.scanning && !this.busyOperation) this.startScan();
        }, 800);
      }
    }).catch(() => {
      if (!sameHealthSession(session, this.accountSession)) return;
      this.snapshot.message = '本机加密健康数据库暂不可用，本次数据仅保留到 App 关闭前';
      this.emitSnapshot();
    });
  }

  private async loadStoredRecords(deviceKey: string): Promise<void> {
    const session = this.accountSession, generation = this.connectionGeneration;
    try {
      const stored = await wearableHealthStore.loadRecent(session.ownerId, deviceKey);
      if (!sameHealthSession(session, this.accountSession) || generation !== this.connectionGeneration) return;
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
      if (repaired.length > 0) await this.saveCurrentRecords(repaired);
      this.emitSnapshot();
    } catch {}
  }

  async savedSportRecords(): Promise<HealthRecord[]> {
    const session = this.accountSession;
    if (!validHealthOwner(session.ownerId)) return [];
    const records = await wearableHealthStore.loadSportRecords(session.ownerId);
    if (!sameHealthSession(session, this.accountSession)) throw new Error('账号已变化，请重新打开运动记录');
    return records.map(normalizeLegacyDistanceRecord);
  }

  async healthRange(deviceKey: string, metric: WearableMetricKey, start: number, end: number): Promise<HealthRecord[]> {
    if (!deviceKey || deviceKey !== this.snapshot.deviceKey || !Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
      throw new Error('设备或日期已变更，请重新选择');
    }
    const generation = this.connectionGeneration;
    const session = this.accountSession;
    const records = await wearableHealthStore.loadRange(session.ownerId, deviceKey, metric, start, end - 1);
    if (!sameHealthSession(session, this.accountSession)) throw new Error('账号已变化，请重新选择');
    if (generation !== this.connectionGeneration || deviceKey !== this.snapshot.deviceKey) throw new Error('设备已变更，请重新选择');
    const result: Map<string, HealthRecord> = new Map();
    records.forEach((record: HealthRecord) => result.set(record.id, record));
    this.snapshot.records.filter((record: HealthRecord) => record.deviceKey === deviceKey && record.metric === metric &&
      record.timestamp >= start && record.timestamp < end).forEach((record: HealthRecord) => result.set(record.id, record));
    return Array.from(result.values());
  }

  private persistRecords(records: HealthRecord[]): void {
    const session = this.accountSession;
    this.saveCurrentRecords(records).then(() => this.synchronizeCloud()).catch(() => {
      if (!sameHealthSession(session, this.accountSession)) return;
      this.snapshot.message = '测量完成，但本机加密保存失败';
      this.emitSnapshot();
    });
  }

  private async saveCurrentRecords(records: HealthRecord[]): Promise<void> {
    const session = this.accountSession, generation = this.connectionGeneration;
    const current = (): boolean => sameHealthSession(session, this.accountSession) && generation === this.connectionGeneration;
    const owned = records.filter((record: HealthRecord) => record.deviceKey === this.connectedKey &&
      recordWithinOwnership(record, this.ownershipSince, Date.now()));
    await wearableHealthStore.saveRecords(session.ownerId, owned, current);
  }

  private tryRestoreConnection(): void {
    if (!this.lastBinding || this.restoreConnectPending ||
      this.snapshot.connected || this.busyOperation !== 'scan') return;
    const match = this.devices.find((item: WearableDevice) =>
      item.provider === this.lastBinding?.provider && !!item.mac && item.mac === this.lastBinding?.mac);
    if (!match) return;
    this.restoreConnectPending = true;
    setTimeout(() => {
      this.connect(match.key).finally(() => { this.restoreConnectPending = false; });
    }, 200);
  }

  private async postConnectInitialize(generation: number): Promise<void> {
    if (!isCurrentConnectionGeneration(generation, this.connectionGeneration) || !this.snapshot.connected ||
      this.busyOperation || this.measurement.running || this.sportActive()) return;
    try {
      await this.runDeviceCommand('连接后初始化', async (current: () => void): Promise<void> => {
        this.emitPhase('syncing', '正在读取电量并同步今日戒指数据…');
        console.info(`[SaydianWearable] delayed post-connect initialization started generation=${generation}`);
        await this.refreshConnectedDeviceInternal(generation);
        current();
        // Advanced history remains a manual action; no nested public command locks.
        await this.syncHistoryInternal(generation, [HealthQueryDay.TODAY], false);
        current();
        this.snapshot.syncedAt = Date.now();
        this.snapshot.message = '今日戒指数据已自动同步';
        await this.saveCurrentRecords(this.snapshot.records);
        current();
        this.synchronizeCloud();
        this.emitSnapshot();
        this.emitPhase('connected', '今日数据同步完成');
      });
    } catch (error) {
      if (isCurrentConnectionGeneration(generation, this.connectionGeneration)) {
        // Post-connect reads are optional. A failed read must not disconnect a
        // device that has already authenticated successfully.
        this.snapshot.message = this.bluetoothError(error as Error, '已连接，自动读取失败，可手动重试');
        this.emitSnapshot();
        this.emitPhase('connected', this.snapshot.message);
      }
    }
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
    if (this.accountTeardownPending || this.accountTeardownFailed) {
      this.emitPhase('error', '请等待旧戒指连接结束后重试'); return false;
    }
    const sportControl = ['开始运动', '暂停运动', '继续运动', '结束运动'].includes(name);
    if (this.sportActive() && !sportControl) {
      this.emitPhase('error', '运动进行中，请先结束运动再操作戒指');
      return false;
    }
    if (this.busyOperation || this.deviceCommandInFlight) {
      this.emitPhase('error', this.busyOperation ? `正在${this.busyOperation}，请完成后再操作` : '旧戒指操作尚未结束，请稍后重试');
      return false;
    }
    this.busyOperation = name;
    ++this.operationGeneration;
    return true;
  }

  private async runConnectedOperation(name: string, operation: (current: () => void) => Promise<boolean>): Promise<boolean> {
    const connection = this.connectionGeneration, session = this.accountSession;
    try { return await this.runDeviceCommand(name, operation); }
    catch (error) {
      if (connection === this.connectionGeneration && sameHealthSession(session, this.accountSession)) {
        this.emitPhase('error', this.bluetoothError(error as Error, `${name}失败`));
      }
      return false;
    }
  }

  async runDeviceCommand<T>(name: string, operation: (assertCurrent: () => void) => Promise<T>): Promise<T> {
    if (this.deviceCommandInFlight || !this.ensureConnected() || !this.beginOperation(name)) {
      throw new Error('请连接戒指并等待当前操作完成');
    }
    const connection = this.connectionGeneration, session = this.accountSession, generation = this.operationGeneration;
    const assertCurrent = (): void => {
      if (connection !== this.connectionGeneration || !sameHealthSession(session, this.accountSession) ||
        generation !== this.operationGeneration || !this.snapshot.connected || this.accountTeardownPending) {
        throw new Error('账号或戒指已变化，请重新操作');
      }
    };
    const result = Promise.resolve().then(async (): Promise<T> => {
      assertCurrent(); const value = await operation(assertCurrent); assertCurrent(); return value;
    });
    const settling = result.then(() => {}, () => {});
    this.deviceCommandInFlight = settling;
    try { return await result; }
    finally {
      if (this.deviceCommandInFlight === settling) this.deviceCommandInFlight = undefined;
      if (connection === this.connectionGeneration && generation === this.operationGeneration) this.endOperation();
    }
  }

  private endOperation(): void {
    if (this.busyOperation !== 'scan') this.busyOperation = '';
  }

  private ensureConnected(): boolean {
    const nativeConnected = this.activeProvider === 'Yuc' ? this.yuc().isReady() :
      this.sdk.getState() === ConnectionState.CONNECTED;
    if (!this.snapshot.connected || !nativeConnected) {
      this.emitPhase('error', '请先连接戒指');
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

  private emitSportSession(): void {
    this.listener?.onSportSession?.(this.copySportSession());
  }

  private copySnapshot(): WearableSnapshot {
    return {
      provider: this.snapshot.provider,
      connected: this.snapshot.connected,
      deviceKey: this.snapshot.deviceKey,
      deviceName: this.snapshot.deviceName,
      mac: this.snapshot.mac,
      model: this.snapshot.model,
      firmware: this.snapshot.firmware,
      capabilities: this.snapshot.capabilities,
      sportCapability: {
        modes: this.snapshot.sportCapability.modes.slice(),
        supportsPause: this.snapshot.sportCapability.supportsPause,
        protocol: this.snapshot.sportCapability.protocol
      },
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

  private copySportSession(): SportSessionState {
    return {
      phase: this.sportSession.phase,
      mode: this.sportSession.mode,
      startedAt: this.sportSession.startedAt,
      observedAt: this.sportSession.observedAt,
      durationSeconds: this.sportSession.durationSeconds,
      distanceKm: this.sportSession.distanceKm,
      routeDistanceKm: this.sportSession.routeDistanceKm,
      steps: this.sportSession.steps,
      calories: this.sportSession.calories,
      heartRate: this.sportSession.heartRate,
      route: this.sportSession.route.slice(),
      locationStatus: this.sportSession.locationStatus,
      status: this.sportSession.status
    };
  }

  private bluetoothError(error: Error, fallback: string): string {
    const code = (error as BusinessError).code;
    if (code === 201) return '蓝牙或附近设备权限未开启';
    if (code === 2900003) return '手机蓝牙已关闭';
    if (code === 2900001) return '系统蓝牙服务暂不可用';
    if (/JL RCSP service not available/i.test(error.message)) {
      return `${fallback}：当前戒指暂不支持表盘读取`;
    }
    if (/timeout|超时/i.test(error.message)) return `${fallback}：连接超时，请确认戒指未被其他手机占用`;
    return error.message && error.message.length <= 120 ? `${fallback}：${error.message}` : fallback;
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => setTimeout(resolve, milliseconds));
  }

  private yuc(): YucWearableAdapter {
    if (!this.yucAdapter) this.yucAdapter = new YucWearableAdapter();
    return this.yucAdapter;
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
