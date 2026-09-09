import { common } from '@kit.AbilityKit';
import { HashMap } from '@kit.ArkTS';
import { ble } from '@kit.ConnectivityKit';
import {
  BLEState, CMD, Constants, SPUtil, YCBTClient, YCAppControlHealthDataMeasureType,
  YCAppControlHealthDataType, YCProductProtocolCommandType, YCProductScanResult
} from 'library';
import {
  HealthRecord, HealthValue, WearableMetricKey, WearableSportMode,
  boundedHealthValue, healthValue
} from '../model/WearableContracts';
import {
  YucDeviceMetadata, YucFeatureFlags, YucNamedValue, YucRealtimeHealth,
  emptyYucFeatureFlags, yucDecimalValue, yucSportModeFromProtocolValue,
  yucSportModeProtocolValue, yucValidTimestamp
} from '../model/YucWearableContracts';

export interface YucSportTelemetry {
  steps: number;
  distanceMeters: number;
  calories: number;
  durationSeconds: number;
  heartRate: number;
}

export interface YucWearableListener {
  onState?: (state: number) => void;
  onBattery?: (level: number, state: number) => void;
  onRealtime?: (data: YucRealtimeHealth) => void;
  onMeasurementEnd?: (metric: WearableMetricKey) => void;
  onSport?: (data: YucSportTelemetry) => void;
}

interface YucCommandResult {
  code: number;
  data: HashMap<string, Object> | null;
}

type YucResultCallback = (code: number, ratio: number, result: HashMap<string, Object> | null) => void;

export class YucWearableAdapter {
  private client: YCBTClient = YCBTClient.getInstance();
  private listener: YucWearableListener | null = null;
  private attached: boolean = false;
  private activeMeasurement: WearableMetricKey | '' = '';

  private stateListener = (state: number): void => {
    this.listener?.onState?.(state);
  };

  private batteryListener = (code: number, _ratio: number,
    result: HashMap<string, Object> | null): void => {
    if (code !== 0 || !result) return;
    const data = this.nested(result, 'data');
    const level = this.number(data ?? result, 'deviceBatteryValue',
      this.number(result, 'batteryLevel', -1));
    const state = this.number(data ?? result, 'deviceBatteryState', 0);
    if (level >= 0 && level <= 100) this.listener?.onBattery?.(level, state);
  };

  private realtimeListener = (dataType: number, result: HashMap<string, Object> | null): void => {
    if (!result) return;
    this.handleRealtime(dataType, result);
  };

  private deviceListener = (code: number, result: HashMap<string, Object> | null): void => {
    if (code !== 0 || !result) return;
    const dataType = this.number(result, 'dataType', -1);
    if (dataType === Constants.DATATYPE.DeviceMeasurStatusAndResults ||
      dataType === Constants.DATATYPE.DeviceMeasurementResult) {
      const metric = this.metricFromYucType(this.number(result, 'type', -1)) || this.activeMeasurement;
      this.emitDeviceMeasurement(metric, result);
      if (metric && this.number(result, 'state', 1) === 0) {
        this.listener?.onMeasurementEnd?.(metric);
        if (this.activeMeasurement === metric) this.activeMeasurement = '';
      }
    } else if (dataType === Constants.DATATYPE.DeviceEndECG && this.activeMeasurement === 'ecg') {
      this.listener?.onMeasurementEnd?.('ecg');
      this.activeMeasurement = '';
    }
  };

  attachContext(context: common.UIAbilityContext, listener: YucWearableListener): void {
    this.listener = listener;
    if (this.attached) return;
    // Keep reconnect provider-scoped in VepWearableService. The vendor-level
    // reconnect cache is not model-aware and can otherwise reclaim a W9/W9S
    // device while the Vep transport is using it. The app already restores a
    // saved W8 binding by scanning and reconnecting it explicitly.
    YCBTClient.init(context, false, false);
    this.client = YCBTClient.getInstance();
    this.client.registerBleStateChange(this.stateListener);
    this.client.registerBatteryLevelListener(this.batteryListener);
    this.client.appRegisterRealDataCallBack(this.realtimeListener);
    this.client.deviceToApp(this.deviceListener);
    this.attached = true;
  }

  shutdown(): void {
    this.listener = null;
    this.activeMeasurement = '';
    if (!this.attached) return;
    try { this.client.unRegisterBleStateChange(this.stateListener); } catch {}
    try { this.client.registerBatteryLevelListener(null); } catch {}
    try { this.client.appRegisterRealDataCallBack(null); } catch {}
    this.attached = false;
  }

  state(): number { return YCBTClient.connectState; }
  isReady(): boolean { return this.state() >= BLEState.ReadWriteOK; }

  macFromScan(result: ble.ScanResult): string {
    try {
      const parsed = new YCProductScanResult(result.deviceName ?? '', result.deviceId,
        result.rssi, result.data, result.connectable);
      return parsed.macAddress ?? '';
    } catch { return ''; }
  }

  async connect(result: ble.ScanResult): Promise<void> {
    if (this.isReady()) return;
    await new Promise<void>((resolve, reject) => {
      let settled = false;
      const finish = (error?: Error): void => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        this.client.unRegisterBleStateChange(temporary);
        if (error) reject(error); else resolve();
      };
      const temporary = (state: number): void => {
        if (state >= BLEState.ReadWriteOK) finish();
        else if (state === BLEState.TimeOut) finish(new Error('W8 连接超时'));
        else if (state === BLEState.NotOpen) finish(new Error('手机蓝牙未开启'));
      };
      const timer = setTimeout(() => finish(new Error('W8 连接超时')), 45000);
      this.client.registerBleStateChange(temporary);
      try { this.client.connect(result, null); }
      catch (error) { finish(error as Error); }
    });
  }

  async disconnect(unbind: boolean): Promise<void> {
    this.activeMeasurement = '';
    this.client.disconnectBle(unbind);
    for (let attempt = 0; attempt < 50; ++attempt) {
      const state = this.state();
      if (state === BLEState.Disconnect || state === BLEState.NotOpen || state === BLEState.TimeOut) return;
      await this.delay(100);
    }
    throw new Error('W8 尚未确认断开');
  }

  featureFlags(): YucFeatureFlags {
    const flags = emptyYucFeatureFlags();
    flags.step = this.enabled('isHasStepCount');
    flags.sleep = this.enabled('isHasSleep');
    flags.heart = this.enabled('isHasTestHeart') || this.enabled('isHasHeartRate');
    flags.pressure = this.enabled('isHasTestBlood') || this.enabled('isHasBlood');
    flags.oxygen = this.enabled('isHasTestSpo2') || this.enabled('isHasBloodOxygen');
    flags.temperature = this.enabled('isHasTestTemp') || this.enabled('isHasTemp');
    flags.glucose = this.enabled('isHasBloodSugarMeasurement') || this.enabled('isHasBloodSugar');
    flags.hrv = this.enabled('isHasHrvMeasurement') || this.enabled('isHasHrv');
    flags.ecg = this.enabled('isHasEcgRealUpload');
    flags.sportPause = this.enabled('isHasPauseExercise');
    flags.outdoorRunning = this.enabled('isHasOutdoorRuning');
    flags.outdoorWalking = this.enabled('isHasOutdoorWalking');
    flags.cycling = this.enabled('isHasRiding');
    flags.hiking = this.enabled('isHasOnFoot') || this.enabled('isHasMountainClimbing');
    flags.sport = flags.outdoorRunning || flags.outdoorWalking || flags.cycling || flags.hiking;
    flags.alarm = this.integerPreference('alarmCount') > 0;
    flags.sedentaryReminder = this.enabled('isHasLongSitting');
    flags.notification = this.enabled('isHasMessage');
    flags.findDevice = this.enabled('isHasFindDevice');
    return flags;
  }

  async metadata(): Promise<YucDeviceMetadata> {
    const result = await this.command((callback: YucResultCallback): void => this.client.queryDeviceInfo(callback), 8000);
    if (result.code !== 0 || !result.data) throw new Error('W8 设备信息读取失败');
    const data = this.nested(result.data, 'data') ?? result.data;
    let mac = '';
    try {
      const address = await this.command((callback: YucResultCallback): void => this.client.queryDeviceMacAddress(callback), 5000);
      if (address.code === 0 && address.data) mac = this.text(address.data, 'macAddress');
    } catch {}
    return {
      mac: mac,
      model: this.text(data, 'deviceId'),
      firmware: this.text(data, 'deviceVersion'),
      batteryLevel: this.number(data, 'deviceBatteryValue', -1),
      batteryState: this.number(data, 'deviceBatteryState', 0)
    };
  }

  async syncTime(): Promise<void> {
    if (!this.isReady()) throw new Error('W8 尚未连接');
    this.client.settingTime();
    await this.delay(250);
  }

  async findDevice(): Promise<void> {
    const result = await this.command((callback: YucResultCallback): void => this.client.findDevice(true, 3, 1, callback), 5000);
    if (result.code !== 0) throw new Error('W8 未确认查找指令');
  }

  async readHistory(deviceKey: string, includeAdvanced: boolean = true): Promise<HealthRecord[]> {
    const keys: number[] = [CMD.KEY_Health.HistorySport, CMD.KEY_Health.HistorySleep,
      CMD.KEY_Health.HistoryHeart, CMD.KEY_Health.HistoryBlood, CMD.KEY_Health.HistoryAll];
    if (includeAdvanced) {
      keys.push(CMD.KEY_Health.HistoryBloodOxygen, CMD.KEY_Health.HistoryTemp,
        CMD.KEY_Health.HistorySportMode, CMD.KEY_Health.HistoryComprehensiveMeasureData,
        CMD.KEY_Health.HistoryBodyData);
    }
    const records: HealthRecord[] = [];
    for (const key of keys) {
      const rows = await this.historyRows(key);
      records.push(...this.recordsForHistory(deviceKey, key, rows));
    }
    return records;
  }

  async latestMetric(deviceKey: string, metric: WearableMetricKey): Promise<HealthRecord | undefined> {
    let key = CMD.KEY_Health.HistoryAll;
    if (metric === 'heart') key = CMD.KEY_Health.HistoryHeart;
    else if (metric === 'pressure') key = CMD.KEY_Health.HistoryBlood;
    const rows = await this.historyRows(key);
    return this.recordsForHistory(deviceKey, key, rows)
      .filter((record: HealthRecord) => record.metric === metric)
      .sort((a: HealthRecord, b: HealthRecord) => b.timestamp - a.timestamp)[0];
  }

  async startMeasurement(metric: WearableMetricKey): Promise<void> {
    this.activeMeasurement = metric;
    let result: YucCommandResult;
    if (metric === 'ecg') {
      result = await this.command((callback: YucResultCallback): void => this.client.appEcgTestStart(callback), 8000);
    } else {
      const dataType = this.yucMeasurementType(metric);
      result = await this.command((callback: YucResultCallback): void => this.client.controlMeasureHealthData(
        YCAppControlHealthDataMeasureType.single, dataType, callback), 8000);
    }
    if (result.code !== 0) {
      this.activeMeasurement = '';
      throw new Error('W8 未接受测量指令');
    }
  }

  async stopMeasurement(metric: WearableMetricKey): Promise<void> {
    try {
      let result: YucCommandResult;
      if (metric === 'ecg') {
        result = await this.command((callback: YucResultCallback): void => this.client.appEcgTestEnd(callback), 5000);
      } else {
        const dataType = this.yucMeasurementType(metric);
        result = await this.command((callback: YucResultCallback): void => this.client.controlMeasureHealthData(
          YCAppControlHealthDataMeasureType.off, dataType, callback), 5000);
      }
      if (result.code !== 0) throw new Error('W8 未确认结束测量');
    } finally { this.activeMeasurement = ''; }
  }

  async sport(state: number, mode: WearableSportMode): Promise<void> {
    const type = yucSportModeProtocolValue(mode);
    const result = await this.command((callback: YucResultCallback): void => this.client.appRunMode(state, type, callback), 8000);
    if (result.code !== 0) throw new Error('W8 未确认运动指令');
  }

  private async historyRows(key: number): Promise<HashMap<string, Object>[]> {
    const result = await this.command((callback: YucResultCallback): void => this.client.healthHistoryData(
      YCProductProtocolCommandType.healthData, key, callback), 10000);
    if (result.code === Constants.CODE.Code_TimeOut) throw new Error('W8 健康数据读取超时');
    if (result.code !== 0 || !result.data) return [];
    const rows = result.data.get('data') as HashMap<string, Object>[] | undefined;
    return rows ?? [];
  }

  private recordsForHistory(deviceKey: string, key: number,
    rows: HashMap<string, Object>[]): HealthRecord[] {
    const records: HealthRecord[] = [];
    rows.forEach((row: HashMap<string, Object>) => {
      if (key === CMD.KEY_Health.HistorySport) {
        const timestamp = yucValidTimestamp(this.number(row, 'sportStartTime'));
        const values = this.values([
          healthValue('步数', this.number(row, 'sportStep'), '步'),
          healthValue('距离', this.number(row, 'sportDistance') / 1000, 'km'),
          healthValue('热量', this.number(row, 'sportCalorie'), 'kcal')]);
        this.pushRecord(records, deviceKey, 'activity', timestamp, values);
      } else if (key === CMD.KEY_Health.HistorySleep) {
        const timestamp = yucValidTimestamp(this.number(row, 'startTime'));
        const deep = this.number(row, 'deepSleepTotal') / 60;
        const light = this.number(row, 'lightSleepTotal') / 60;
        const rem = this.number(row, 'rapidEyeMovementTotal') / 60;
        const values = this.values([healthValue('总睡眠', deep + light + rem, '分钟'),
          healthValue('深睡', deep, '分钟'), healthValue('浅睡', light, '分钟'),
          healthValue('快速眼动', rem, '分钟'),
          healthValue('清醒', this.number(row, 'wakeDuration') / 60, '分钟')]);
        this.pushRecord(records, deviceKey, 'sleep', timestamp, values);
      } else if (key === CMD.KEY_Health.HistoryHeart) {
        this.pushRecord(records, deviceKey, 'heart', yucValidTimestamp(this.number(row, 'heartStartTime')),
          this.values([boundedHealthValue('心率', this.number(row, 'heartValue'), 'BPM', 20, 240)]));
      } else if (key === CMD.KEY_Health.HistoryBlood) {
        this.pushRecord(records, deviceKey, 'pressure', yucValidTimestamp(this.number(row, 'bloodStartTime')),
          this.values([boundedHealthValue('收缩压', this.number(row, 'bloodSBP'), 'mmHg', 20, 300),
            boundedHealthValue('舒张压', this.number(row, 'bloodDBP'), 'mmHg', 20, 220)]));
      } else if (key === CMD.KEY_Health.HistoryAll) {
        this.addCombinedHistory(records, deviceKey, row);
      } else if (key === CMD.KEY_Health.HistoryBloodOxygen) {
        this.pushRecord(records, deviceKey, 'oxygen', yucValidTimestamp(this.number(row, 'startTime')),
          this.values([boundedHealthValue('血氧', this.number(row, 'value'), '%', 50, 100)]));
      } else if (key === CMD.KEY_Health.HistoryTemp) {
        this.pushRecord(records, deviceKey, 'temperature', yucValidTimestamp(this.number(row, 'startTime')),
          this.values([boundedHealthValue('体温', this.number(row, 'tempValue'), '°C', 20, 50)]));
      } else if (key === CMD.KEY_Health.HistorySportMode) {
        this.addSportHistory(records, deviceKey, row);
      } else if (key === CMD.KEY_Health.HistoryComprehensiveMeasureData) {
        this.addBloodComponentHistory(records, deviceKey, row);
      } else if (key === CMD.KEY_Health.HistoryBodyData) {
        this.addBodyHistory(records, deviceKey, row);
      }
    });
    return records;
  }

  private addCombinedHistory(records: HealthRecord[], deviceKey: string,
    row: HashMap<string, Object>): void {
    const timestamp = yucValidTimestamp(this.number(row, 'startTime'));
    this.pushRecord(records, deviceKey, 'heart', timestamp,
      this.values([boundedHealthValue('心率', this.number(row, 'heartValue'), 'BPM', 20, 240)]));
    this.pushRecord(records, deviceKey, 'pressure', timestamp,
      this.values([boundedHealthValue('收缩压', this.number(row, 'SBPValue'), 'mmHg', 20, 300),
        boundedHealthValue('舒张压', this.number(row, 'DBPValue'), 'mmHg', 20, 220)]));
    this.pushRecord(records, deviceKey, 'oxygen', timestamp,
      this.values([boundedHealthValue('血氧', this.number(row, 'OOValue'), '%', 50, 100)]));
    const temperature = yucDecimalValue(this.signedByte(this.number(row, 'tempIntValue')),
      this.number(row, 'tempFloatValue'));
    this.pushRecord(records, deviceKey, 'temperature', timestamp,
      this.values([boundedHealthValue('体温', temperature, '°C', 20, 50)]));
    this.pushRecord(records, deviceKey, 'hrv', timestamp,
      this.values([boundedHealthValue('HRV', this.number(row, 'hrvValue'), 'ms', 1, 1000)]));
    this.pushRecord(records, deviceKey, 'glucose', timestamp,
      this.values([boundedHealthValue('血糖', this.number(row, 'bloodSugarValue'), 'mmol/L', 0.1, 50)]));
  }

  private addSportHistory(records: HealthRecord[], deviceKey: string,
    row: HashMap<string, Object>): void {
    const timestamp = yucValidTimestamp(this.number(row, 'startTime'));
    const steps = this.number(row, 'sportSteps');
    const distanceKm = this.number(row, 'sportDistances') / 1000;
    const calories = this.number(row, 'sportCalories');
    const duration = this.number(row, 'sportTime');
    const heart = this.number(row, 'sportHeartRate');
    const values = this.values([healthValue('步数', steps, '步'), healthValue('距离', distanceKm, 'km'),
      healthValue('热量', calories, 'kcal'), healthValue('时长', duration, '秒'),
      boundedHealthValue('平均心率', heart, 'BPM', 20, 240)]);
    const record = this.record(deviceKey, 'sport', timestamp, values);
    if (!record) return;
    record.sport = { mode: yucSportModeFromProtocolValue(this.number(row, 'sportMode')),
      durationSeconds: Math.max(0, Math.round(duration)), distanceKm: Math.max(0, distanceKm),
      routeDistanceKm: 0, steps: Math.max(0, Math.round(steps)), calories: Math.max(0, calories),
      heartRate: heart >= 20 && heart <= 240 ? heart : 0, route: [] };
    records.push(record);
  }

  private addBloodComponentHistory(records: HealthRecord[], deviceKey: string,
    row: HashMap<string, Object>): void {
    const timestamp = yucValidTimestamp(this.number(row, 'time'));
    const glucose = yucDecimalValue(this.number(row, 'bloodSugarInteger'), this.number(row, 'bloodSugarFloat'));
    this.pushRecord(records, deviceKey, 'glucose', timestamp,
      this.values([boundedHealthValue('血糖', glucose, 'mmol/L', 0.1, 50)]));
    const values = this.values([
      healthValue('尿酸', this.number(row, 'uricAcid'), 'μmol/L'),
      healthValue('总胆固醇', yucDecimalValue(this.number(row, 'cholesterolInteger'),
        this.number(row, 'cholesterolFloat'), 100), 'mmol/L'),
      healthValue('高密度脂蛋白', yucDecimalValue(this.number(row, 'highLipoproteinCholesterolInteger'),
        this.number(row, 'highLipoproteinCholesterolFloat'), 100), 'mmol/L'),
      healthValue('低密度脂蛋白', yucDecimalValue(this.number(row, 'lowLipoproteinCholesterolInteger'),
        this.number(row, 'lowLipoproteinCholesterolFloat'), 100), 'mmol/L'),
      healthValue('甘油三酯', yucDecimalValue(this.number(row, 'triglycerideCholesterolInteger'),
        this.number(row, 'triglycerideCholesterolFloat'), 100), 'mmol/L')]);
    this.pushRecord(records, deviceKey, 'bloodComponents', timestamp, values);
  }

  private addBodyHistory(records: HealthRecord[], deviceKey: string,
    row: HashMap<string, Object>): void {
    const timestamp = yucValidTimestamp(this.number(row, 'time'));
    const hrv = yucDecimalValue(this.number(row, 'hrvInteger'), this.number(row, 'hrvFloat'));
    this.pushRecord(records, deviceKey, 'hrv', timestamp,
      this.values([boundedHealthValue('HRV', hrv, 'ms', 1, 1000)]));
    const values = this.values([
      healthValue('负荷指数', yucDecimalValue(this.number(row, 'loadIndexInteger'),
        this.number(row, 'loadIndexFloat')), ''),
      healthValue('压力指数', yucDecimalValue(this.number(row, 'pressureInteger'),
        this.number(row, 'pressureFloat')), ''),
      healthValue('身体指数', yucDecimalValue(this.number(row, 'bodyInteger'),
        this.number(row, 'bodyFloat')), ''),
      healthValue('交感神经指数', yucDecimalValue(this.number(row, 'sympatheticInteger'),
        this.number(row, 'sympatheticFloat')), ''),
      healthValue('SDNN', this.number(row, 'sdn'), 'ms'),
      healthValue('最大摄氧量', this.number(row, 'maximalOxygenIntake'), 'mL/kg/min')]);
    this.pushRecord(records, deviceKey, 'bodyComposition', timestamp, values);
  }

  private handleRealtime(dataType: number, result: HashMap<string, Object>): void {
    if (dataType === Constants.DATATYPE.Real_UploadHeart) {
      this.emitRealtime('heart', [this.named('心率', this.number(result, 'heartRate'), 'BPM')]);
    } else if (dataType === Constants.DATATYPE.Real_UploadBloodOxygen) {
      this.emitRealtime('oxygen', [this.named('血氧', this.number(result, 'bloodOxygen'), '%')]);
    } else if (dataType === Constants.DATATYPE.Real_UploadBlood) {
      this.emitRealtime('pressure', [this.named('收缩压', this.number(result, 'systolicBloodPressure'), 'mmHg'),
        this.named('舒张压', this.number(result, 'diastolicBloodPressure'), 'mmHg')]);
    } else if (dataType === Constants.DATATYPE.Real_UploadComprehensive) {
      this.emitRealtime('heart', [this.named('心率', this.number(result, 'heartRate'), 'BPM')]);
      this.emitRealtime('pressure', [this.named('收缩压', this.number(result, 'systolicBloodPressure'), 'mmHg'),
        this.named('舒张压', this.number(result, 'diastolicBloodPressure'), 'mmHg')]);
      this.emitRealtime('oxygen', [this.named('血氧', this.number(result, 'bloodOxygen'), '%')]);
      this.emitRealtime('temperature', [this.named('体温', this.number(result, 'temperature'), '°C')]);
      this.emitRealtime('glucose', [this.named('血糖', this.number(result, 'bloodGlucose'), 'mmol/L')]);
    } else if (dataType === Constants.DATATYPE.Real_UploadBodyData) {
      this.emitRealtime('hrv', [this.named('HRV', this.number(result, 'hrv'), 'ms')]);
    } else if (dataType === Constants.DATATYPE.Real_UploadECG) {
      const samples = result.get('data') as number[] | undefined;
      const hrv = this.named('HRV', this.number(result, 'hrv'), 'ms');
      this.listener?.onRealtime?.({ metric: 'ecg', values: hrv ? [hrv] : [],
        samples: samples ?? [], sampleFrequency: 250 });
    } else if (dataType === Constants.DATATYPE.Real_UploadECGHR && this.activeMeasurement === 'ecg') {
      this.emitRealtime('ecg', [this.named('心率', this.number(result, 'heartRate',
        this.number(result, 'heartValue')), 'BPM')]);
    } else if (dataType === Constants.DATATYPE.Real_UploadRun) {
      this.listener?.onSport?.({ steps: this.number(result, 'sportStep'),
        distanceMeters: this.number(result, 'sportDistance'), calories: this.number(result, 'sportCalorie'),
        durationSeconds: this.number(result, 'sportTime'), heartRate: this.number(result, 'heartRate') });
    }
  }

  private emitDeviceMeasurement(metric: WearableMetricKey | '', result: HashMap<string, Object>): void {
    if (!metric) return;
    if (metric === 'heart') this.emitRealtime(metric, [this.named('心率', this.number(result, 'heartRate'), 'BPM')]);
    else if (metric === 'pressure') this.emitRealtime(metric, [this.named('收缩压', this.number(result, 'SBP'), 'mmHg'),
      this.named('舒张压', this.number(result, 'DBP'), 'mmHg')]);
    else if (metric === 'oxygen') this.emitRealtime(metric, [this.named('血氧', this.number(result, 'bloodOxygen'), '%')]);
    else if (metric === 'temperature') this.emitRealtime(metric, [this.named('体温',
      yucDecimalValue(this.signedByte(this.number(result, 'tempInteger')), this.number(result, 'tempFloat')), '°C')]);
    else if (metric === 'glucose') this.emitRealtime(metric, [this.named('血糖',
      yucDecimalValue(this.number(result, 'bloodSugarInteger'), this.number(result, 'bloodSugarFloat')), 'mmol/L')]);
  }

  private emitRealtime(metric: WearableMetricKey, values: Array<YucNamedValue | undefined>): void {
    const valid: YucNamedValue[] = [];
    values.forEach((value: YucNamedValue | undefined) => { if (value) valid.push(value); });
    if (valid.length > 0) this.listener?.onRealtime?.({ metric: metric, values: valid, samples: [], sampleFrequency: 0 });
  }

  private named(name: string, value: number, unit: string): YucNamedValue | undefined {
    return Number.isFinite(value) && value > 0 ? { name: name, value: value, unit: unit } : undefined;
  }

  private metricFromYucType(type: number): WearableMetricKey | '' {
    if (type === YCAppControlHealthDataType.heartRate) return 'heart';
    if (type === YCAppControlHealthDataType.bloodPressure) return 'pressure';
    if (type === YCAppControlHealthDataType.bloodOxygen) return 'oxygen';
    if (type === YCAppControlHealthDataType.bodyTemperature) return 'temperature';
    if (type === YCAppControlHealthDataType.bloodGlucose) return 'glucose';
    if (type === YCAppControlHealthDataType.hrv) return 'hrv';
    return '';
  }

  private yucMeasurementType(metric: WearableMetricKey): YCAppControlHealthDataType {
    if (metric === 'heart') return YCAppControlHealthDataType.heartRate;
    if (metric === 'pressure') return YCAppControlHealthDataType.bloodPressure;
    if (metric === 'oxygen') return YCAppControlHealthDataType.bloodOxygen;
    if (metric === 'temperature') return YCAppControlHealthDataType.bodyTemperature;
    if (metric === 'glucose') return YCAppControlHealthDataType.bloodGlucose;
    if (metric === 'hrv') return YCAppControlHealthDataType.hrv;
    throw new Error('W8 SDK 未开放该测量项目');
  }

  private pushRecord(records: HealthRecord[], deviceKey: string, metric: WearableMetricKey,
    timestamp: number, values: HealthValue[]): void {
    const record = this.record(deviceKey, metric, timestamp, values);
    if (record) records.push(record);
  }

  private record(deviceKey: string, metric: WearableMetricKey, timestamp: number,
    values: HealthValue[]): HealthRecord | undefined {
    if (!deviceKey || timestamp <= 0 || values.length === 0) return undefined;
    return { id: `${deviceKey}|${metric}|${timestamp}|watch_history`, deviceKey: deviceKey,
      metric: metric, timestamp: timestamp, source: 'watch_history', values: values,
      samples: [], sampleFrequency: 0 };
  }

  private values(values: Array<HealthValue | undefined>): HealthValue[] {
    const result: HealthValue[] = [];
    values.forEach((value: HealthValue | undefined) => { if (value) result.push(value); });
    return result;
  }

  private nested(map: HashMap<string, Object>, key: string): HashMap<string, Object> | undefined {
    const value = map.get(key);
    return value ? value as HashMap<string, Object> : undefined;
  }

  private number(map: HashMap<string, Object>, key: string, fallback: number = 0): number {
    const raw = map.get(key);
    if (raw === undefined || raw === null) return fallback;
    const value = Number(raw);
    return Number.isFinite(value) ? value : fallback;
  }

  private text(map: HashMap<string, Object>, key: string): string {
    const raw = map.get(key);
    return raw === undefined || raw === null ? '' : `${raw}`.trim().slice(0, 120);
  }

  private enabled(key: string): boolean { return this.integerPreference(key) === 1; }

  private integerPreference(key: string): number {
    try {
      const value = Number(SPUtil.getStringWithDefault(key, '0'));
      return Number.isFinite(value) ? Math.round(value) : 0;
    } catch { return 0; }
  }

  private signedByte(value: number): number { return value > 127 ? value - 256 : value; }

  private command(send: (callback: YucResultCallback) => void, timeoutMs: number): Promise<YucCommandResult> {
    return new Promise<YucCommandResult>((resolve, reject) => {
      let settled = false;
      const timer = setTimeout(() => {
        if (settled) return;
        settled = true;
        reject(new Error('W8 指令响应超时'));
      }, timeoutMs);
      try {
        send((code: number, _ratio: number, result: HashMap<string, Object> | null): void => {
          if (settled) return;
          settled = true;
          clearTimeout(timer);
          resolve({ code: code, data: result });
        });
      } catch (error) {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          reject(error as Error);
        }
      }
    });
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
  }
}
