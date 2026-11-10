import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/feature_models.dart';
import '../domain/urion_pulse_record.dart';
import '../l10n/global_locale_controller.dart';
import '../l10n/ui_labels.dart';
import '../services/app_controller.dart';
import 'urion_pulse_history.dart';

/// U19 功能独立呈现，避免将戒指提醒/手势页面套在手表上。
class U19DevicePage extends StatefulWidget {
  const U19DevicePage({
    required this.controller,
    required this.feature,
    super.key,
  });
  final AppController controller;
  final DeviceFeature feature;
  @override
  State<U19DevicePage> createState() => _U19DevicePageState();
}

class _U19DevicePageState extends State<U19DevicePage> {
  late final String _target;
  late final String _owner;
  bool _busy = false;
  bool _waiting = false;
  Timer? _waitLimit;
  Map<String, Object?> _data = const {};
  String _c(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  AppController get c => widget.controller;
  bool get _current =>
      mounted &&
      c.connectedDevice?.id == _target &&
      c.homeHealthCardOwner == _owner;
  @override
  void initState() {
    super.initState();
    _target = c.connectedDevice?.id ?? '';
    _owner = c.homeHealthCardOwner;
    c.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && widget.feature != DeviceFeature.findWatch) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _waitLimit?.cancel();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (!_current) {
      _waitLimit?.cancel();
      _waiting = false;
      _data = const {};
    } else if (c.deviceFeatureData[widget.feature]
        case final Map<String, Object?> value) {
      _data = value;
      if (value['justMeasured'] == true ||
          value['awaitingCompletion'] == false) {
        _waiting = false;
        _waitLimit?.cancel();
      }
    }
    setState(() {});
  }

  Future<void> _load() async {
    if (!_current || _busy) return;
    setState(() => _busy = true);
    try {
      final value = await c.readDeviceFeature(widget.feature);
      if (_current) setState(() => _data = value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _save(Map<String, Object?> values) async {
    if (!_current || _busy) return false;
    setState(() => _busy = true);
    try {
      final saved = await c.writeDeviceFeature(widget.feature, values);
      if (saved && _current && values['operation'] != 'start') {
        final value = await c.readDeviceFeature(widget.feature);
        if (_current) setState(() => _data = value);
      }
      return saved && _current;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ) ==
      true;
  Future<void> _editNumber(String key, String label, int min, int max) async {
    final input = TextEditingController(text: '${_data[key] ?? ''}');
    final value = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(label),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: '$min–$max'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(input.text);
              if (n != null && n >= min && n <= max) Navigator.pop(dialog, n);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    // 路由退出动画结束后再释放输入控制器。
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    if (value != null && _current) await _save({key: value});
  }

  Future<void> _syncTime() async {
    final language = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(_c('手表语言与校时', 'Watch language and time')),
        children: [
          for (final item in [
            ('zh', uiCopy(context, "简体中文")),
            ('en', 'English'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, item.$1),
              child: Text(item.$2),
            ),
        ],
      ),
    );
    if (language != null && _current) await _save({'syncTime': language});
  }

  Future<void> _schedule() async {
    final raw = _data['dynamicBloodPressure'];
    if (raw is! Map) return;
    final plan = Map<String, Object?>.from(raw);
    var hour = (plan['startHour'] as num?)?.toInt() ?? 8;
    var day = (plan['dayIntervalMinutes'] as num?)?.toInt() ?? 60;
    var night = (plan['nightIntervalMinutes'] as num?)?.toInt() ?? 60;
    final next = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _c('定时血压', 'Scheduled blood pressure'),
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                _c(
                  '开启后手表会定时充气。请确认佩戴合适。',
                  'Your watch will inflate on a schedule. Check the fit before enabling.',
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: hour,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _c('开始时间', 'Start time'),
                ),
                items: [
                  for (var h = 0; h < 24; h++)
                    DropdownMenuItem(
                      value: h,
                      child: Text(TimeOfDay(hour: h, minute: 0).format(sheet)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) update(() => hour = v);
                },
              ),
              for (final daytime in [true, false])
                DropdownButtonFormField<int>(
                  initialValue:
                      {60, 90, 120, 180}.contains(daytime ? day : night)
                      ? (daytime ? day : night)
                      : 60,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: daytime
                        ? _c('白天间隔', 'Day interval')
                        : _c('夜间间隔', 'Night interval'),
                  ),
                  items: [
                    for (final n in [60, 90, 120, 180])
                      DropdownMenuItem(
                        value: n,
                        child: Text(_c('$n 分钟', '$n min')),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      update(() {
                        if (daytime) {
                          day = v;
                        } else {
                          night = v;
                        }
                      });
                    }
                  },
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, {
                  ...plan,
                  'enabled': true,
                  'startHour': hour,
                  'dayIntervalMinutes': day,
                  'nightIntervalMinutes': night,
                }),
                child: Text(_c('继续', 'Continue')),
              ),
            ],
          ),
        ),
      ),
    );
    if (next == null || !_current) return;
    if (await _confirm(
          _c('开启定时充气？', 'Enable scheduled inflation?'),
          _c(
            '手表可能在白天和夜间充气，可随时返回关闭。',
            'Your watch may inflate during the day and at night. You can return here to turn it off.',
          ),
        ) &&
        _current) {
      await _save({'dynamicBloodPressure': next});
    }
  }

  Future<void> _pulse() async {
    if (!await _confirm(
          _c('开始脉搏测量？', 'Start a pulse reading?'),
          _c('请戴好手表并保持静止。', 'Wear your watch snugly and keep still.'),
        ) ||
        !_current) {
      return;
    }
    setState(() => _waiting = true);
    if (await _save(const {'operation': 'start'}) && _current && _waiting) {
      _waitLimit?.cancel();
      _waitLimit = Timer(const Duration(minutes: 3), () {
        if (_current) setState(() => _waiting = false);
      });
    } else if (_current) {
      setState(() => _waiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _current && c.availabilityFor(widget.feature).isReady;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.feature == DeviceFeature.findWatch
              ? _c('查找手表', 'Find watch')
              : context.l10n.deviceFeatureName(widget.feature),
        ),
      ),
      body: !ready
          ? Center(child: Text(_c('请连接手表', 'Connect your watch')))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.feature == DeviceFeature.findWatch)
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await c.triggerDeviceAction(
                                DeviceFeature.findWatch,
                              );
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    icon: const Icon(Icons.watch_outlined),
                    label: Text(_c('查找手表', 'Find watch')),
                  )
                else if (_data.isEmpty && _busy)
                  const Center(child: CircularProgressIndicator())
                else if (widget.feature == DeviceFeature.healthMonitoring) ...[
                  for (final item in [
                    ('heartRate', _c('自动心率', 'Automatic heart rate')),
                    ('bloodOxygen', _c('自动血氧', 'Automatic blood oxygen')),
                  ])
                    if (_data[item.$1] is bool)
                      Card(
                        child: SwitchListTile(
                          title: Text(item.$2),
                          value: _data[item.$1] == true,
                          onChanged: _busy ? null : (v) => _save({item.$1: v}),
                        ),
                      ),
                  if (_data['dynamicBloodPressure'] case final Map plan)
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.schedule),
                            title: Text(_c('定时血压', 'Scheduled blood pressure')),
                            subtitle: Text(
                              plan['enabled'] == true
                                  ? _c('已开启', 'On')
                                  : _c('已关闭', 'Off'),
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: _busy ? null : _schedule,
                                child: Text(_c('设置计划', 'Set schedule')),
                              ),
                              if (plan['enabled'] == true)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _save({
                                          'dynamicBloodPressure': {
                                            ...plan,
                                            'enabled': false,
                                          },
                                        }),
                                  child: Text(_c('关闭', 'Turn off')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ] else if (widget.feature == DeviceFeature.basicSettings) ...[
                  if (_data['is24Hour'] is bool)
                    Card(
                      child: SwitchListTile(
                        title: Text(_c('24 小时制', '24-hour time')),
                        value: _data['is24Hour'] == true,
                        onChanged: _busy ? null : (v) => _save({'is24Hour': v}),
                      ),
                    ),
                  for (final item in [
                    ('age', _c('年龄', 'Age'), 1, 120),
                    ('heightCm', _c('身高（cm）', 'Height (cm)'), 50, 240),
                    ('weightKg', _c('体重（kg）', 'Weight (kg)'), 10, 250),
                    ('stepGoal', _c('步数目标', 'Step goal'), 1, 100000),
                  ])
                    if (_data[item.$1] is num)
                      Card(
                        child: ListTile(
                          title: Text(item.$2),
                          trailing: Text('${_data[item.$1]}'),
                          onTap: _busy
                              ? null
                              : () => _editNumber(
                                  item.$1,
                                  item.$2,
                                  item.$3,
                                  item.$4,
                                ),
                        ),
                      ),
                  if (_data['gender'] is int)
                    Card(
                      child: ListTile(
                        title: Text(_c('性别', 'Sex')),
                        subtitle: Text(
                          _data['gender'] == 0
                              ? _c('女', 'Female')
                              : _c('男', 'Male'),
                        ),
                        onTap: _busy
                            ? null
                            : () async {
                                final v = await showDialog<int>(
                                  context: context,
                                  builder: (d) => SimpleDialog(
                                    title: Text(_c('性别', 'Sex')),
                                    children: [
                                      for (final item in [
                                        (0, _c('女', 'Female')),
                                        (1, _c('男', 'Male')),
                                      ])
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.pop(d, item.$1),
                                          child: Text(item.$2),
                                        ),
                                    ],
                                  ),
                                );
                                if (v != null && _current) {
                                  await _save({'gender': v});
                                }
                              },
                      ),
                    ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(_c('手表语言与校时', 'Watch language and time')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : _syncTime,
                    ),
                  ),
                ] else if (widget.feature == DeviceFeature.screenDisplay &&
                    _data['durationSeconds'] is num)
                  Card(
                    child: ListTile(
                      title: Text(_c('亮屏时长', 'Screen timeout')),
                      subtitle: Text(
                        _c(
                          '${_data['durationSeconds']} 秒',
                          '${_data['durationSeconds']} s',
                        ),
                      ),
                      onTap: _busy
                          ? null
                          : () => _editNumber(
                              'durationSeconds',
                              _c('亮屏时长（秒）', 'Screen timeout (s)'),
                              1,
                              20,
                            ),
                    ),
                  )
                else if (widget.feature == DeviceFeature.u19Pulse) ...[
                  if (_data['pulse'] case final Map pulse)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (final item in [
                              ('bloodStasis', _c('血瘀指数', 'Flow index')),
                              ('qiBlood', _c('气血指数', 'Vitality index')),
                              ('dampness', _c('湿气指数', 'Moisture index')),
                            ])
                              ListTile(
                                title: Text(item.$2),
                                trailing: Text('${pulse[item.$1] ?? '—'} / 10'),
                              ),
                            Text(
                              _c(
                                '手表提供的参考指数',
                                'Reference indices from your watch',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_waiting) const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy || _waiting ? null : _pulse,
                    child: Text(_c('开始测量', 'Start reading')),
                  ),
                  if (_data['awaitingCompletion'] == true || _waiting)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm(
                                    _c('手表已结束测量？', 'Finished on your watch?'),
                                    _c(
                                      '请先在手表上结束测量，再确认。',
                                      'End the reading on your watch before confirming.',
                                    ),
                                  ) &&
                                  _current &&
                                  await _save(const {
                                    'operation': 'watchEnded',
                                  })) {
                                if (_current) setState(() => _waiting = false);
                              }
                            },
                      child: Text(_c('已在手表上结束', 'Finished on watch')),
                    ),
                  UrionPulseHistory(
                    records: [
                      if (_data['pulseHistory'] case final List rows)
                        for (final row in rows)
                          ?UrionPulseRecord.tryParse(row, deviceId: _target),
                    ],
                  ),
                ],
                if (widget.feature != DeviceFeature.findWatch) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_c('刷新', 'Refresh')),
                  ),
                ],
              ],
            ),
    );
  }
}
