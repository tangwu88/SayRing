import 'package:flutter/widgets.dart';

/// Only the current UI's device class belongs here. Never infer a connection
/// route from wording, or rewrite a peripheral name, article or health record.
class DevicePromptScope extends InheritedWidget {
  const DevicePromptScope({
    required this.generic,
    required super.child,
    super.key,
  });

  final bool generic;

  static bool usesDevice(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DevicePromptScope>()
          ?.generic ??
      false;

  @override
  bool updateShouldNotify(DevicePromptScope oldWidget) =>
      generic != oldWidget.generic;
}

final _deviceNoun = RegExp(r'\bSay Ring\b|\brings?\b', caseSensitive: false);

/// 仅供开发者编写的静态中英文模板使用。先选用语，再插入设备名等参数。
String genericDevicePrompt(String template) => template
    .replaceAll('戒指 App', '配套 App')
    .replaceAll('戒指', '设备')
    .replaceAll('ring app', 'companion app')
    .replaceAllMapped(
      _deviceNoun,
      (m) => switch (m[0]) {
        'ring' => 'device',
        'Ring' => 'Device',
        'rings' => 'devices',
        'Rings' => 'Devices',
        _ => m[0]!,
      },
    );

String devicePromptLabel(BuildContext context, String label) =>
    DevicePromptScope.usesDevice(context) ? genericDevicePrompt(label) : label;

// 只登记 App 自己产生的状态。原生透传信息、用户文本和动态参数不做全文替换。
const deviceStatusEnglish = <String, String>{
  '保存的戒指暂时无法读取，请重新添加戒指': 'Could not read the saved device. Add it again.',
  '保存的戒指需要确认，请点重新连接': 'Tap Reconnect to confirm your saved device.',
  '写入戒指设置失败': 'Could not save device settings.',
  '另一项戒指测量尚未结束，请稍后重试': 'Wait for the current reading to finish.',
  '当前戒指不支持此功能': 'This device does not support this feature.',
  '当前戒指暂不支持由 App 发起此操作':
      'This action cannot be started from the app on this device.',
  '当前戒指不支持暂停运动': 'This device does not support pausing a workout.',
  '当前戒指不支持调整监测间隔': 'The monitoring interval cannot be changed on this device.',
  '当前戒指不支持此监测间隔，请刷新设置':
      'This interval is unavailable. Refresh device settings.',
  '当前戒指未提供可设置的健康检测项目': 'No adjustable monitoring settings are available.',
  '心率提醒已写入戒指': 'Heart rate reminder saved on the device.',
  '戒指已离开搜索范围，请重新搜索': 'Device not found. Search again.',
  '戒指数据正在同步，请稍后再测量': 'Device data is syncing. Try measuring again shortly.',
  '戒指数据读取超时': 'Reading device data timed out.',
  '戒指正在准备设置，正在重新读取': 'Waiting for device settings. Retrying.',
  '戒指自动重连失败': 'Could not reconnect automatically.',
  '戒指自动重连失败，可在设备页重新连接':
      'Could not reconnect automatically. Tap Reconnect on the device page.',
  '戒指设置读取失败，请稍后重试': 'Could not read device settings. Try again shortly.',
  '戒指返回的开关与设置不一致，请刷新后重试':
      'The device did not confirm the change. Refresh and try again.',
  '戒指返回的监测间隔与设置不一致，请刷新后重试':
      'The device did not confirm the interval. Refresh and try again.',
  '戒指连接中断，测量已停止；重连后请重试':
      'Device disconnected. The reading has stopped. Reconnect and try again.',
  '戒指连接出现问题，请稍后重试': 'Device connection failed. Try again shortly.',
  '戒指数据来源已变化，请重新连接后同步': 'The data source changed. Reconnect before syncing.',
  '戒指正在恢复连接，请稍后重试': 'The device is reconnecting. Try again shortly.',
  '戒指连接已变化': 'The device connection changed.',
  '戒指连接已变化，请重新同步': 'The device connection changed. Sync again.',
  '暂时无法恢复同步，请保持戒指靠近后重试':
      'Could not resume syncing. Keep the device nearby and try again.',
  '暂时无法查找戒指': 'Unable to search for devices.',
  '暂时无法查找戒指，请稍后重试': 'Unable to search for devices. Try again shortly.',
  '暂时无法读取可恢复的戒指': 'Could not read saved devices.',
  '暂时无法读取可恢复的戒指，请稍后重试': 'Could not read saved devices. Try again shortly.',
  '暂时无法读取已保存的戒指，请重新连接':
      'Could not read the saved device. Reconnect and try again.',
  '未收到戒指的完整数据，请稍后重试': 'Some device data was not received. Try again shortly.',
  '正在写入并确认戒指设置': 'Saving and checking device settings.',
  '正在确认并重新连接保存的戒指': 'Checking and reconnecting to the saved device.',
  '正在读取戒指数据': 'Reading device data',
  '正在读取戒指设置': 'Reading device settings',
  '正在连接戒指': 'Connecting to the device',
  '正在重新连接，戒指靠近后会自动连接': 'Reconnecting when the device is nearby.',
  '此手机暂不支持读取可恢复的戒指': 'Saved devices are not available on this phone.',
  '此版本不支持该设备，请选择兼容的智能戒指': 'Choose a compatible device.',
  '没有找到可恢复的戒指': 'No saved devices found.',
  '等待戒指靠近，靠近后会自动连接':
      'Waiting for the device to come within range. It will reconnect automatically.',
  '设备状态暂未确认，请保持戒指靠近后恢复同步': 'Keep the device nearby to resume syncing.',
  '设置已由戒指读回确认': 'Settings confirmed by the device.',
  '设置未确认，请从戒指刷新后重试':
      'Settings were not confirmed. Refresh from the device and try again.',
  '请先添加戒指': 'Add a device first.',
  '请先结束当前运动，再连接其他戒指':
      'End the current workout before connecting another device.',
  '请先读取戒指支持的监测项目': 'Read the available monitoring options first.',
  '请先连接戒指': 'Connect your device first.',
  '请先连接戒指后再开始运动': 'Connect your device before starting a workout.',
  '请在设备页重新连接戒指': 'Reconnect from the device page.',
  '请开启手机定位后再查找戒指':
      'Turn on location on your phone before searching for devices.',
  '请重新连接戒指后重试': 'Reconnect the device and try again.',
  '读取戒指设置失败，请点击重试': 'Could not read device settings. Tap to retry.',
  '连接失败，请将戒指靠近手机后重试': 'Move the device closer to your phone and try again.',
  '连接失败，请确认戒指未连接其他手机后重试':
      'Check that the device is not connected to another phone and try again.',
  '连接戒指后可读取': 'Connect your device to read this information.',
  '部分记录与当前戒指不匹配，请重新同步':
      'Some records did not match the current device. Sync again.',
};

final _readCount = RegExp(r'^已接收 (\d+) 条，正在读取戒指数据$');
final _readPercent = RegExp(r'^正在读取戒指数据 (\d{1,3})%$');

final _knownDeviceStates = {
  for (final e in deviceStatusEnglish.entries)
    for (final key in [e.key, genericDevicePrompt(e.key)])
      key: (genericDevicePrompt(e.key), e.value),
};

/// Returns null for anything not produced by the app's device-status templates.
String? localizeGenericDeviceStatus(String value, {required bool english}) {
  final known = _knownDeviceStates[value];
  if (known != null) return english ? known.$2 : known.$1;
  final count = _readCount.firstMatch(value)?[1];
  if (count != null) {
    return english
        ? 'Received $count records. Reading device data…'
        : '已接收 $count 条，正在读取设备数据';
  }
  final percent = _readPercent.firstMatch(value)?[1];
  if (percent != null) {
    return english ? 'Reading device data $percent%' : '正在读取设备数据 $percent%';
  }
  return null;
}
