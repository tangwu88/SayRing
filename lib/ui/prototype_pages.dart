import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/feature_models.dart';
import '../domain/ecg_waveform.dart';
import '../domain/health_interpretation.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/camera_remote_shutter_gate.dart';
import '../services/device_weather_service.dart';
import '../services/device_watch_face_market_service.dart';
import '../services/health_analysis.dart';
import 'app_theme.dart';
import 'app_update_gate_scope.dart';
import 'brand_assets.dart';
import 'watch_face_market_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _distributor = TextEditingController();
  bool _accepted = false;
  bool _obscure = true;
  bool _sendingCode = false;
  int _codeCountdown = 0;
  Timer? _codeTimer;

  @override
  void dispose() {
    _mobile.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    _distributor.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      _message('请输入正确的中国大陆手机号');
      return;
    }
    setState(() => _sendingCode = true);
    final success = await widget.controller.sendSmsCode(
      mobile: mobile,
      usage: 'register',
    );
    if (!mounted) return;
    setState(() => _sendingCode = false);
    if (!success) {
      _message(widget.controller.errorMessage ?? '验证码发送失败，请稍后重试');
      return;
    }
    _message('验证码已发送，请注意查收');
    _codeTimer?.cancel();
    setState(() => _codeCountdown = 60);
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _codeCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _codeCountdown = 0);
      } else {
        setState(() => _codeCountdown--);
      }
    });
  }

  Future<void> _submit() async {
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      _message('请输入正确的中国大陆手机号');
      return;
    }
    if (_password.text.length < 6) {
      _message('密码至少需要 6 位');
      return;
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(_code.text.trim())) {
      _message('请输入收到的短信验证码');
      return;
    }
    if (_password.text != _confirmation.text) {
      _message('两次输入的密码不一致');
      return;
    }
    if (!_accepted) {
      _message('请先阅读并同意用户协议与隐私政策');
      return;
    }
    final success = await widget.controller.register(
      mobile,
      _password.text,
      code: _code.text,
      privacyConsentGranted: true,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _message(widget.controller.errorMessage ?? '注册失败，请稍后重试');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            const Center(child: SaydianBrandLockup(width: 154)),
            const SizedBox(height: 28),
            TextField(
              key: const Key('registration-mobile'),
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号'),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('registration-code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: '短信验证码',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    key: const Key('registration-send-code'),
                    onPressed:
                        _sendingCode ||
                            _codeCountdown > 0 ||
                            widget.controller.isBusy
                        ? null
                        : _sendCode,
                    child: Text(
                      _sendingCode
                          ? '发送中'
                          : _codeCountdown > 0
                          ? '${_codeCountdown}s'
                          : '获取验证码',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '设置密码',
                helperText: '至少 6 位',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmation,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: '确认密码'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _distributor,
              decoration: const InputDecoration(
                labelText: '经销商编号（选填）',
                helperText: '没有可不填',
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('我已阅读并同意用户协议与隐私政策'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('registration-submit'),
              onPressed: widget.controller.isBusy ? null : _submit,
              child: widget.controller.isBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('注册'),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({this.controller, super.key});

  final AppController? controller;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _message;
  bool _obscure = true;
  bool _sendingCode = false;
  int _codeCountdown = 0;
  Timer? _codeTimer;

  @override
  void dispose() {
    _mobile.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _message = '短信服务暂时无法使用，请稍后再试');
      return;
    }
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      setState(() => _message = '请输入正确的中国大陆手机号');
      return;
    }
    setState(() {
      _sendingCode = true;
      _message = null;
    });
    final success = await controller.sendSmsCode(
      mobile: mobile,
      usage: 'up-pwd',
    );
    if (!mounted) return;
    setState(() {
      _sendingCode = false;
      _message = success
          ? '验证码已发送，请注意查收'
          : controller.errorMessage ?? '验证码发送失败，请稍后重试';
    });
    if (!success) return;
    _codeTimer?.cancel();
    setState(() => _codeCountdown = 60);
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _codeCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _codeCountdown = 0);
      } else {
        setState(() => _codeCountdown--);
      }
    });
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _message = '找回密码服务暂时无法使用，请稍后再试');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _message = '两次输入的新密码不一致');
      return;
    }
    final success = await controller.resetPassword(
      mobile: _mobile.text,
      code: _code.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已重置，并已自动登录')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _message = controller.errorMessage ?? '密码重置失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('找回密码')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            size: 72,
            color: SaydianColors.blue,
          ),
          const SizedBox(height: 20),
          const Text(
            '验证手机号',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '输入注册手机号，验证通过后可重新设置密码。',
            textAlign: TextAlign.center,
            style: TextStyle(color: SaydianColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            key: const Key('password-recovery-mobile'),
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '手机号'),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('password-recovery-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '短信验证码',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  key: const Key('password-recovery-send-code'),
                  onPressed:
                      _sendingCode ||
                          _codeCountdown > 0 ||
                          (widget.controller?.isBusy ?? false)
                      ? null
                      : _sendCode,
                  child: Text(
                    _sendingCode
                        ? '发送中'
                        : _codeCountdown > 0
                        ? '${_codeCountdown}s'
                        : '获取验证码',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-recovery-password'),
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '新密码',
              helperText: '至少 6 位',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-recovery-confirmation'),
            controller: _confirmation,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: '确认新密码'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            FeatureStateCard(
              message: _message!,
              icon: Icons.info_outline_rounded,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('password-recovery-submit'),
            onPressed: widget.controller?.isBusy == true ? null : _submit,
            child: const Text('重置密码'),
          ),
        ],
      ),
    );
  }
}

class HealthWarningPage extends StatefulWidget {
  const HealthWarningPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<HealthWarningPage> createState() => _HealthWarningPageState();
}

class _HealthWarningPageState extends State<HealthWarningPage> {
  late bool _heartRateEnabled;
  late bool _bloodPressureEnabled;
  late bool _temperatureEnabled;
  late final TextEditingController _heartRateUpper;
  late final TextEditingController _systolicUpper;
  late final TextEditingController _diastolicUpper;
  late final TextEditingController _temperatureUpper;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.healthWarningSettings;
    _heartRateEnabled = settings.heartRateEnabled;
    _bloodPressureEnabled = settings.bloodPressureEnabled;
    _temperatureEnabled = settings.temperatureEnabled;
    _heartRateUpper = TextEditingController(text: '${settings.heartRateUpper}');
    _systolicUpper = TextEditingController(text: '${settings.systolicUpper}');
    _diastolicUpper = TextEditingController(text: '${settings.diastolicUpper}');
    _temperatureUpper = TextEditingController(
      text: settings.temperatureUpper.toStringAsFixed(1),
    );
    widget.controller.addListener(_refresh);
    unawaited(widget.controller.refreshNotificationHistory(allPages: true));
    unawaited(widget.controller.markAllHealthWarningsRead());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _heartRateUpper.dispose();
    _systolicUpper.dispose();
    _diastolicUpper.dispose();
    _temperatureUpper.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final heartRate = int.tryParse(_heartRateUpper.text.trim());
    final systolic = int.tryParse(_systolicUpper.text.trim());
    final diastolic = int.tryParse(_diastolicUpper.text.trim());
    final temperature = double.tryParse(_temperatureUpper.text.trim());
    if (heartRate == null ||
        systolic == null ||
        diastolic == null ||
        temperature == null) {
      _message('请填写正确的报警数值');
      return;
    }
    final success = await widget.controller.saveHealthWarningSettings(
      HealthWarningSettings(
        heartRateEnabled: _heartRateEnabled,
        heartRateUpper: heartRate,
        bloodPressureEnabled: _bloodPressureEnabled,
        systolicUpper: systolic,
        diastolicUpper: diastolic,
        temperatureEnabled: _temperatureEnabled,
        temperatureUpper: temperature,
      ),
    );
    if (!mounted) return;
    _message(
      success ? '健康预警设置已保存' : widget.controller.errorMessage ?? '保存失败，请稍后重试',
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isExplicitHealthWarning(Map<String, Object?> item) {
    final type = [
      item['type'],
      item['category'],
      item['message_type'],
      item['notice_type'],
    ].whereType<Object>().join(' ').toLowerCase();
    return type.contains('health') ||
        type.contains('warning') ||
        type.contains('健康') ||
        type.contains('预警');
  }

  String _warningStatus(Map<String, Object?> item) {
    final raw =
        [
              item['status_text'],
              item['level_text'],
              item['status_label'],
              item['level'],
            ]
            .whereType<Object>()
            .map((value) => '$value'.trim())
            .firstWhere(
              (value) => value.isNotEmpty && int.tryParse(value) == null,
              orElse: () => '',
            );
    final normalized = raw.toLowerCase();
    if (normalized.contains('high') || raw.contains('高')) return '偏高';
    if (normalized.contains('low') || raw.contains('低')) return '偏低';
    if (normalized.contains('abnormal') || raw.contains('异常')) return '异常';
    return raw.isEmpty ? '异常提醒' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final warnings = widget.controller.notifications
        .where(_isExplicitHealthWarning)
        .toList();
    final loading = widget.controller.notificationStatus == '正在加载';
    return Scaffold(
      appBar: AppBar(title: const Text('健康预警')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FeatureStateCard(
            message: '设置健康数据上限提醒',
            detail: '开关开启后，新测量值超过你设置的上限时，会在 APP 全局显示醒目提示。',
            icon: Icons.notifications_active_outlined,
            color: SaydianColors.orange,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('warning-heart-rate-switch'),
                    value: _heartRateEnabled,
                    onChanged: (value) =>
                        setState(() => _heartRateEnabled = value),
                    title: const Text('心率报警'),
                    subtitle: const Text('超过设定心率时提示'),
                    secondary: const Icon(Icons.favorite_rounded),
                  ),
                  if (_heartRateEnabled)
                    _WarningThresholdField(
                      key: const Key('warning-heart-rate-threshold'),
                      label: '心率上限',
                      controller: _heartRateUpper,
                      unit: 'bpm',
                    ),
                  const Divider(height: 12),
                  SwitchListTile(
                    key: const Key('warning-blood-pressure-switch'),
                    value: _bloodPressureEnabled,
                    onChanged: (value) =>
                        setState(() => _bloodPressureEnabled = value),
                    title: const Text('血压报警'),
                    subtitle: const Text('收缩压或舒张压超过设定值时提示'),
                    secondary: const Icon(Icons.bloodtype_outlined),
                  ),
                  if (_bloodPressureEnabled) ...[
                    _WarningThresholdField(
                      key: const Key('warning-systolic-threshold'),
                      label: '收缩压上限',
                      controller: _systolicUpper,
                      unit: 'mmHg',
                    ),
                    const SizedBox(height: 10),
                    _WarningThresholdField(
                      key: const Key('warning-diastolic-threshold'),
                      label: '舒张压上限',
                      controller: _diastolicUpper,
                      unit: 'mmHg',
                    ),
                  ],
                  const Divider(height: 12),
                  SwitchListTile(
                    key: const Key('warning-temperature-switch'),
                    value: _temperatureEnabled,
                    onChanged: (value) =>
                        setState(() => _temperatureEnabled = value),
                    title: const Text('体温报警'),
                    subtitle: const Text('超过设定体温时提示'),
                    secondary: const Icon(Icons.thermostat_rounded),
                  ),
                  if (_temperatureEnabled)
                    _WarningThresholdField(
                      key: const Key('warning-temperature-threshold'),
                      label: '体温上限',
                      controller: _temperatureUpper,
                      unit: '℃',
                      decimal: true,
                    ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FilledButton.icon(
                      key: const Key('warning-save'),
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存预警设置'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '预警记录',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final alert in widget.controller.healthWarningAlerts)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: SaydianColors.danger,
                ),
                title: Text(alert.title),
                subtitle: Text('${alert.message}\n来源：${alert.origin.label}'),
                trailing: Text(
                  DateFormat('yyyy-MM-dd\nHH:mm').format(alert.triggeredAt),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (warnings.isEmpty &&
              widget.controller.healthWarningAlerts.isEmpty)
            FeatureStateCard(
              message: '当前暂无健康预警',
              detail:
                  widget.controller.notificationStatus == '已加载' ||
                      widget.controller.notificationStatus == '暂无消息'
                  ? '这里只显示已确认的健康提醒，不会根据普通测量值自行判断疾病。'
                  : '${widget.controller.notificationStatus}。不会用普通测量值生成预警。',
              icon: Icons.health_and_safety_outlined,
              color: SaydianColors.green,
            )
          else
            for (final warning in warnings)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(
                    Icons.health_and_safety_outlined,
                    color: SaydianColors.orange,
                  ),
                  title: Text(
                    '${warning['title'] ?? warning['name'] ?? '健康提醒'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: SaydianColors.orange,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _warningStatus(warning),
                              style: const TextStyle(
                                color: SaydianColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${warning['content'] ?? warning['message'] ?? warning['created_at'] ?? '已收到健康提醒'}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 14),
          const FeatureStateCard(
            message: '如有明显不适，请及时咨询专业医务人员',
            detail: '手表测量结果用于日常健康管理参考。',
            icon: Icons.medical_information_outlined,
          ),
        ],
      ),
    );
  }
}

class _WarningThresholdField extends StatelessWidget {
  const _WarningThresholdField({
    required this.label,
    required this.controller,
    required this.unit,
    this.decimal = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 112,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          SizedBox(width: 62, child: Text(unit, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class SharingManagementPage extends StatelessWidget {
  const SharingManagementPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final targets = <Map<String, Object?>>[];
    final seenMemberIds = <int>{};
    for (final invitation in controller.careInvitations) {
      final status = int.tryParse('${invitation['examine_status'] ?? 0}') ?? 0;
      final inviterId = int.tryParse('${invitation['inviter_id'] ?? 0}') ?? 0;
      if (status != 1 || inviterId <= 0 || !seenMemberIds.add(inviterId)) {
        continue;
      }
      final rawMember = invitation['member'];
      final member = rawMember is Map
          ? rawMember.map(
              (key, value) => MapEntry<String, Object?>('$key', value),
            )
          : const <String, Object?>{};
      targets.add({
        'member_id': inviterId,
        'nickname': '${member['nickname'] ?? ''}'.trim(),
        'mobile': '${member['mobile'] ?? ''}'.trim(),
        'head_portrait': '${member['head_portrait'] ?? ''}'.trim(),
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('共享管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FeatureStateCard(
            message: '默认不共享任何健康数据',
            detail: '家人接受邀请并选择允许的健康项目后，对方才能查看。',
            icon: Icons.privacy_tip_outlined,
            color: SaydianColors.green,
          ),
          const SizedBox(height: 14),
          if (targets.isEmpty)
            const FeatureStateCard(
              message: '暂无需要授权的关爱人',
              detail: '收到并同意家人的关爱邀请后，可在这里选择允许对方查看的健康项目。',
              icon: Icons.group_outlined,
            )
          else
            for (final member in targets)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () {
                    final memberId = int.tryParse(
                      '${member['member_id'] ?? 0}',
                    );
                    if (memberId == null || memberId == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('成员信息不完整，暂时无法设置共享项目')),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CareShareSettingsPage(
                          controller: controller,
                          member: member,
                          memberId: memberId,
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    foregroundImage:
                        '${member['head_portrait'] ?? ''}'.startsWith('http')
                        ? NetworkImage('${member['head_portrait']}')
                        : null,
                    child: const Icon(Icons.person_outline),
                  ),
                  title: Text(
                    '${member['nickname'] ?? ''}'.trim().isNotEmpty
                        ? '${member['nickname']}'.trim()
                        : '关爱邀请人',
                  ),
                  subtitle: Text(
                    '${member['mobile'] ?? ''}'.trim().isNotEmpty
                        ? '${member['mobile']} · 设置允许查看的健康项目'
                        : '邀请人账号 ID：${member['member_id']} · 设置允许查看的健康项目',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
        ],
      ),
    );
  }
}

class CareShareSettingsPage extends StatefulWidget {
  const CareShareSettingsPage({
    required this.controller,
    required this.member,
    required this.memberId,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?> member;
  final int memberId;

  @override
  State<CareShareSettingsPage> createState() => _CareShareSettingsPageState();
}

class _CareShareSettingsPageState extends State<CareShareSettingsPage> {
  static const _dailyKeys = <String, String>{
    'steps': '步数',
    'reliang': '卡路里',
    'juli': '距离',
    'sleep': '总睡眠',
  };
  static const _healthKeys = <String, String>{
    'bloodPressure': '血压',
    'bloodGlucose': '血糖',
    'bloodOxygen': '血氧',
    'bodyTemperature': '体温',
    'ecg': '心电图',
    'heartReat': '心率',
    'HRV': 'HRV',
    'bodycomposition': '身体成分',
    'bloodcomposition': '血液成分',
  };

  Set<String> _enabled = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await widget.controller.loadCareShareSettings(
        memberId: widget.memberId,
      );
      if (!mounted) return;
      setState(() {
        _enabled = values;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '共享设置服务暂不可用';
        _loading = false;
      });
    }
  }

  void _setGroup(Iterable<String> keys, bool enabled) {
    setState(() {
      final values = {..._enabled};
      enabled ? values.addAll(keys) : values.removeAll(keys);
      _enabled = values;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final succeeded = await widget.controller.saveCareShareSettings(
      memberId: widget.memberId,
      settings: _enabled,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(succeeded ? '共享设置已保存' : '保存失败，请稍后重试')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${widget.member['nickname'] ?? widget.member['mobile'] ?? '关爱成员'}';
    return Scaffold(
      appBar: AppBar(title: const Text('共享数据管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FeatureStateCard(
                  message: name,
                  detail: '只有已开启的项目会共享；关闭后保存即可撤销。',
                  icon: Icons.privacy_tip_outlined,
                  color: SaydianColors.green,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  FeatureStateCard(
                    message: _error!,
                    detail: '当前不会更改任何授权项目。',
                    icon: Icons.cloud_off_outlined,
                  ),
                ],
                const SizedBox(height: 14),
                _permissionGroup('每日数据', _dailyKeys),
                const SizedBox(height: 12),
                _permissionGroup('健康数据', _healthKeys),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving || _error != null ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中' : '保存共享设置'),
                ),
              ],
            ),
    );
  }

  Widget _permissionGroup(String title, Map<String, String> values) {
    final allEnabled = values.keys.every(_enabled.contains);
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: TextButton(
              onPressed: () => _setGroup(values.keys, !allEnabled),
              child: Text(allEnabled ? '全部关闭' : '全选'),
            ),
          ),
          for (final entry in values.entries) ...[
            const Divider(indent: 16),
            SwitchListTile(
              title: Text(entry.value),
              value: _enabled.contains(entry.key),
              onChanged: (enabled) => _setGroup([entry.key], enabled),
            ),
          ],
        ],
      ),
    );
  }
}

class CareInvitationsPage extends StatefulWidget {
  const CareInvitationsPage({
    required this.controller,
    this.targetInvitationId,
    super.key,
  });

  final AppController controller;
  final String? targetInvitationId;

  @override
  State<CareInvitationsPage> createState() => _CareInvitationsPageState();
}

class _CareInvitationsPageState extends State<CareInvitationsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshCareInvitations());
  }

  Future<void> _respond(Map<String, Object?> invite, bool accepted) async {
    final id = int.tryParse('${invite['id'] ?? 0}') ?? 0;
    if (id == 0) return;
    await widget.controller.respondCareInvitation(id: id, accepted: accepted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关爱邀请')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final invitations = widget.controller.pendingCareInvitations;
          final targetId = widget.targetInvitationId;
          final targetedMatches = targetId == null
              ? const <Map<String, Object?>>[]
              : widget.controller.careInvitations
                    .where(
                      (item) =>
                          '${item['id'] ?? item['invitation_id'] ?? ''}' ==
                          targetId,
                    )
                    .toList(growable: false);
          final targeted = targetedMatches.isEmpty
              ? null
              : targetedMatches.first;
          if (invitations.isEmpty) {
            return RefreshIndicator(
              onRefresh: widget.controller.refreshCareInvitations,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FeatureStateCard(
                    message: targeted != null
                        ? '该关爱邀请已处理'
                        : targetId != null &&
                              widget.controller.careInvitationStatus != '加载中'
                        ? '该关爱邀请已处理或撤销'
                        : widget.controller.careInvitationStatus == '服务暂不可用'
                        ? '关爱邀请服务暂不可用'
                        : '暂无新的关爱邀请',
                    detail: targeted != null || targetId != null
                        ? '页面已刷新为最新状态，不会重复显示操作按钮。'
                        : '收到邀请后，可在这里明确同意或拒绝。',
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.controller.refreshCareInvitations,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final invite = invitations[index];
                final member = invite['member'];
                final memberMap = member is Map ? member : const {};
                final nickname = '${memberMap['nickname'] ?? ''}'.trim();
                final mobile = '${memberMap['mobile'] ?? ''}'.trim();
                final avatar = '${memberMap['head_portrait'] ?? ''}'.trim();
                final inviterId = '${invite['inviter_id'] ?? ''}'.trim();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: SaydianColors.brandRedSoft,
                              foregroundImage:
                                  avatar.startsWith('http://') ||
                                      avatar.startsWith('https://')
                                  ? NetworkImage(avatar)
                                  : null,
                              child: const Icon(
                                Icons.person_rounded,
                                color: SaydianColors.brandRed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nickname.isEmpty ? '赛电用户' : nickname,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    mobile.isNotEmpty
                                        ? mobile
                                        : inviterId.isNotEmpty
                                        ? '邀请人账号 ID：$inviterId'
                                        : '邀请人手机号暂未返回',
                                    style: const TextStyle(
                                      color: SaydianColors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (nickname.isEmpty && mobile.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '服务器暂未返回邀请人的公开头像、昵称和手机号，已避免错误显示为当前账号。',
                            style: TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _respond(invite, false),
                                child: const Text('拒绝'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _respond(invite, true),
                                child: const Text('同意'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class HealthCalibrationPage extends StatefulWidget {
  const HealthCalibrationPage({
    required this.controller,
    required this.metric,
    super.key,
  });

  final AppController controller;
  final HealthMetric metric;

  @override
  State<HealthCalibrationPage> createState() => _HealthCalibrationPageState();
}

class _HealthCalibrationPageState extends State<HealthCalibrationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _primary;
  late final TextEditingController _secondary;
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _primary = TextEditingController(
      text: widget.metric == HealthMetric.bloodPressure ? '120' : '5.5',
    );
    _secondary = TextEditingController(text: '80');
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final values = widget.metric == HealthMetric.bloodPressure
        ? <String, Object?>{
            'operation': 'bp_calibration',
            'enabled': _enabled,
            'systolic': int.tryParse(_primary.text.trim()) ?? 0,
            'diastolic': int.tryParse(_secondary.text.trim()) ?? 0,
          }
        : <String, Object?>{
            'operation': 'glucose_calibration',
            'enabled': _enabled,
            'value': double.tryParse(_primary.text.trim()) ?? 0,
          };
    final saved = await widget.controller.writeDeviceFeature(
      DeviceFeature.healthMonitoring,
      values,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? '${widget.metric.label}校准已保存到手表'
              : widget.controller.errorMessage ?? '校准保存失败，请稍后重试',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBloodPressure = widget.metric == HealthMetric.bloodPressure;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.metric.label}校准')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FeatureStateCard(
              message: '请使用刚刚由专业设备测得的数值',
              detail: '校准值只适用于当前佩戴者。更换佩戴者后，请关闭或重新校准。',
              icon: Icons.verified_user_outlined,
              color: SaydianColors.info,
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用校准'),
                      subtitle: const Text('关闭后恢复手表公共测量模式'),
                      value: _enabled,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _enabled = value),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _primary,
                      enabled: _enabled && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: isBloodPressure ? '收缩压（高压）' : '血糖校准值',
                        suffixText: isBloodPressure ? 'mmHg' : 'mmol/L',
                      ),
                      validator: (value) {
                        if (!_enabled) return null;
                        final number = double.tryParse(value?.trim() ?? '');
                        if (number == null) return '请输入有效数值';
                        if (isBloodPressure && (number < 60 || number > 300)) {
                          return '收缩压需在 60–300 mmHg';
                        }
                        if (!isBloodPressure && (number < 1 || number > 30)) {
                          return '血糖值需在 1.0–30.0 mmol/L';
                        }
                        return null;
                      },
                    ),
                    if (isBloodPressure) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _secondary,
                        enabled: _enabled && !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '舒张压（低压）',
                          suffixText: 'mmHg',
                        ),
                        validator: (value) {
                          if (!_enabled) return null;
                          final low = int.tryParse(value?.trim() ?? '');
                          final high = int.tryParse(_primary.text.trim());
                          if (low == null || low < 20 || low > 200) {
                            return '舒张压需在 20–200 mmHg';
                          }
                          if (high != null && low >= high) {
                            return '舒张压必须低于收缩压';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: Key('health-calibration-${widget.metric.wireName}'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '正在写入手表' : '保存校准'),
            ),
          ],
        ),
      ),
    );
  }
}

class HealthRecordDetailPage extends StatelessWidget {
  const HealthRecordDetailPage({
    required this.controller,
    required this.record,
    super.key,
  });

  final AppController controller;
  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    if (record.metric == HealthMetric.ecg) {
      return _EcgRecordDetailPage(record: record);
    }
    final time = HealthAnalysisService.displayTime(record);
    final date =
        '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final values = <MapEntry<String, num>>[...record.values.entries];
    return Scaffold(
      appBar: AppBar(title: Text('${record.metric.label}详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    record.displayValue,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    record.unit,
                    style: const TextStyle(color: SaydianColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    date,
                    style: const TextStyle(color: SaydianColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '数据来源：${record.origin.label}',
                    style: const TextStyle(
                      color: SaydianColors.techBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (values.length > 1) ...[
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < values.length; index++) ...[
                    ListTile(
                      title: Text(
                        healthValueLabel(values[index].key, record.metric),
                      ),
                      trailing: Text(
                        '${_formatRecordNumber(values[index].value)} ${healthValueUnit(values[index].key, record)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (index != values.length - 1) const Divider(indent: 16),
                  ],
                ],
              ),
            ),
          ],
          if (record.metric == HealthMetric.ecg &&
              record.samples.length > 1) ...[
            const SizedBox(height: 12),
            _EcgWaveformCard(
              samples: record.samples,
              sampleFrequency: record.values['sampleFrequency']?.toInt() ?? 250,
              calibrated: record.rawVersion >= 2,
            ),
          ],
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final interpretation = interpretHealthRecord(record);
              return FeatureStateCard(
                message: interpretation.title,
                detail: interpretation.detail,
                icon: record.metric == HealthMetric.ecg
                    ? Icons.monitor_heart_outlined
                    : Icons.insights_rounded,
                color: SaydianColors.brandRed,
              );
            },
          ),
          const SizedBox(height: 12),
          const FeatureStateCard(
            message: '查看长期趋势更有参考价值',
            detail: '单次测量可能受佩戴方式、运动和环境影响；如有不适，请咨询专业医务人员。',
            icon: Icons.health_and_safety_outlined,
            color: SaydianColors.green,
          ),
        ],
      ),
    );
  }

  String _formatRecordNumber(num value) =>
      value is int || value == value.round()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
}

class _EcgRecordDetailPage extends StatefulWidget {
  const _EcgRecordDetailPage({required this.record});

  final HealthRecord record;

  @override
  State<_EcgRecordDetailPage> createState() => _EcgRecordDetailPageState();
}

class _EcgRecordDetailPageState extends State<_EcgRecordDetailPage> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Scaffold(
      appBar: AppBar(title: const Text('心电详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EcgSummaryCard(record: record),
          const SizedBox(height: 12),
          _EcgWaveformCard(
            samples: record.samples,
            sampleFrequency: record.values['sampleFrequency']?.toInt() ?? 250,
            calibrated: record.rawVersion >= 2,
          ),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.monitor_heart_outlined),
                label: Text('测量指标'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.health_and_safety_outlined),
                label: Text('风险分析'),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (value) =>
                setState(() => _section = value.first),
          ),
          const SizedBox(height: 12),
          if (_section == 0)
            _EcgMedicalSection(record: record)
          else
            _EcgRiskSection(record: record),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'ecg-full-report'),
                builder: (_) => _EcgFullReportPage(record: record),
              ),
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('查看完整报告'),
          ),
          const SizedBox(height: 12),
          const FeatureStateCard(
            message: '心电结果仅供健康管理参考',
            detail: '单次测量会受到佩戴、运动和环境影响，不能代替医疗诊断。如有不适，请及时就医。',
            icon: Icons.info_outline_rounded,
            color: SaydianColors.brandRed,
          ),
        ],
      ),
    );
  }
}

class _EcgSummaryCard extends StatelessWidget {
  const _EcgSummaryCard({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final measuredAt = record.measuredAt.toLocal();
    final date = DateFormat('yyyy-MM-dd HH:mm').format(measuredAt);
    return Card(
      color: const Color(0xFF9D1830),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor_heart_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '本次心电记录',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: const TextStyle(color: Color(0xFFEECBD2)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    record.origin.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _EcgSummaryValue(
                    label: '心率',
                    value: _ecgValue(record, const ['meanHeartRate', 'value']),
                    unit: 'bpm',
                  ),
                ),
                Expanded(
                  child: _EcgSummaryValue(
                    label: 'QT',
                    value: _ecgValue(record, const ['averageTimeInterval']),
                    unit: 'ms',
                  ),
                ),
                Expanded(
                  child: _EcgSummaryValue(
                    label: 'HRV',
                    value: _ecgValue(record, const ['averageHRV']),
                    unit: 'ms',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EcgSummaryValue extends StatelessWidget {
  const _EcgSummaryValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final num? value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: Color(0xFFEECBD2))),
      const SizedBox(height: 4),
      Text(
        value == null ? '--' : _formatEcgNumber(value!),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        unit,
        style: const TextStyle(color: Color(0xFFEECBD2), fontSize: 12),
      ),
    ],
  );
}

class _EcgMedicalSection extends StatelessWidget {
  const _EcgMedicalSection({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    const definitions = <(String, String, String)>[
      ('meanHeartRate', '平均心率', 'bpm'),
      ('averageHRV', '心率变异性 HRV', 'ms'),
      ('averageTimeInterval', 'QT 间期', 'ms'),
      ('respiratoryRate', '呼吸频率', '次/分'),
      ('sdnn', 'SDNN', 'ms'),
      ('rmssd', 'RMSSD', 'ms'),
      ('qrsTime', 'QRS 时限', 'ms'),
      ('qrsAmplitude', 'QRS 振幅', ''),
      ('stAmplitude', 'ST 振幅', ''),
      ('pulseWaveVelocity', '脉搏波速度', ''),
    ];
    final values = definitions
        .where((item) => record.values[item.$1] != null)
        .toList(growable: false);
    if (values.isEmpty) {
      return const FeatureStateCard(
        message: '本次仅返回基础心电数据',
        detail: '不同型号手表返回的医学指标数量不同，未返回的指标不会推算或补造。',
        icon: Icons.monitor_heart_outlined,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '测量指标',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final item in values)
                      SizedBox(
                        width: itemWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    color: SaydianColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatEcgNumber(record.values[item.$1]!)} ${item.$3}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EcgRiskSection extends StatelessWidget {
  const _EcgRiskSection({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    const definitions = <(String, String)>[
      ('diseaseRisk', '综合异常风险'),
      ('myocarditisRisk', '心肌健康风险'),
      ('chdRisk', '冠心病相关风险'),
      ('angioscleroticRisk', '血管硬化相关风险'),
      ('pressureIndex', '压力指数'),
      ('fatigueIndex', '疲劳指数'),
      ('deviceAbnormalFlags', '设备识别异常项'),
    ];
    final values = definitions
        .where((item) => record.values[item.$1] != null)
        .toList(growable: false);
    final hasAnalysis =
        (record.values['riskAnalysisAvailable'] ?? 0) > 0 ||
        values.any((item) => (record.values[item.$1] ?? 0) > 0);
    if (!hasAnalysis) {
      return const FeatureStateCard(
        message: '本次手表未返回风险指标',
        detail: '风险分析只展示设备实际返回的数据，不根据单次波形自行诊断。',
        icon: Icons.health_and_safety_outlined,
      );
    }
    final highestRisk = values
        .where(
          (item) => const {
            'diseaseRisk',
            'myocarditisRisk',
            'chdRisk',
            'angioscleroticRisk',
          }.contains(item.$1),
        )
        .map((item) => record.values[item.$1] ?? 0)
        .fold<num>(0, math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '风险分析',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '以下数值来自手表算法，仅作健康趋势参考。',
              style: TextStyle(color: SaydianColors.muted, height: 1.45),
            ),
            const SizedBox(height: 12),
            _EcgRiskOverview(value: highestRisk),
            const SizedBox(height: 14),
            for (var index = 0; index < values.length; index++) ...[
              _EcgRiskRow(
                riskKey: values[index].$1,
                label: values[index].$2,
                value: record.values[values[index].$1]!,
              ),
              if (index != values.length - 1) const Divider(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _EcgRiskRow extends StatelessWidget {
  const _EcgRiskRow({
    required this.riskKey,
    required this.label,
    required this.value,
  });

  final String riskKey;
  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    final normalized = value >= 0 && value <= 100 ? value / 100 : null;
    final level = _ecgRiskLevel(riskKey, value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: level.color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${level.label} · ${_formatEcgNumber(value)}',
                style: TextStyle(
                  color: level.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        if (normalized != null) ...[
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: normalized.toDouble(),
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
        const SizedBox(height: 7),
        Text(
          _ecgRiskDescription(riskKey, value),
          style: const TextStyle(
            color: SaydianColors.muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _EcgRiskOverview extends StatelessWidget {
  const _EcgRiskOverview({required this.value});

  final num value;

  @override
  Widget build(BuildContext context) {
    final level = _ecgRiskLevel('diseaseRisk', value);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: level.color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_rounded, color: level.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本次风险等级：${level.label}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  value < 30
                      ? '本次设备算法未提示明显高风险，建议继续保持规律监测。'
                      : '建议在静息状态复测；如多次提示异常或伴随不适，请及时就医。',
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({String label, Color color}) _ecgRiskLevel(String key, num value) {
  if (key == 'pressureIndex' || key == 'fatigueIndex') {
    if (value < 30) return (label: '较低', color: SaydianColors.green);
    if (value < 60) return (label: '中等', color: SaydianColors.orange);
    return (label: '偏高', color: SaydianColors.brandRed);
  }
  if (value < 30) return (label: '低风险', color: SaydianColors.green);
  if (value < 60) return (label: '需关注', color: SaydianColors.orange);
  return (label: '风险较高', color: SaydianColors.brandRed);
}

String _ecgRiskDescription(String key, num value) {
  if (key == 'pressureIndex') {
    return value < 30
        ? '压力指标较低，当前状态相对放松。'
        : value < 60
        ? '压力指标处于中等范围，建议适当休息并保持规律作息。'
        : '压力指标偏高，建议静息后复测，并关注近期睡眠与情绪变化。';
  }
  if (key == 'fatigueIndex') {
    return value < 30
        ? '疲劳指标较低，当前恢复状态较好。'
        : value < 60
        ? '存在一定疲劳，建议减少高强度活动并保证休息。'
        : '疲劳指标偏高，建议充分休息后复测。';
  }
  const names = {
    'diseaseRisk': '综合异常',
    'myocarditisRisk': '心肌健康',
    'chdRisk': '冠心病相关',
    'angioscleroticRisk': '血管硬化相关',
    'deviceAbnormalFlags': '设备识别异常',
  };
  final name = names[key] ?? '该项';
  if (key == 'deviceAbnormalFlags') {
    return value <= 0
        ? '设备未识别到异常标记。'
        : '设备识别到 ${_formatEcgNumber(value)} 项异常标记，建议在静息状态规范佩戴后复测。';
  }
  return value < 30
      ? '$name风险较低，建议继续观察长期趋势。'
      : value < 60
      ? '$name指标需要关注，建议在静息状态规范复测。'
      : '$name指标偏高；若复测仍高或伴有胸闷、心悸等不适，请及时就医。';
}

class _EcgFullReportPage extends StatefulWidget {
  const _EcgFullReportPage({required this.record});

  final HealthRecord record;

  @override
  State<_EcgFullReportPage> createState() => _EcgFullReportPageState();
}

class _EcgFullReportPageState extends State<_EcgFullReportPage> {
  static const _channel = MethodChannel('cc.saidian/wearable_methods');
  final _reportKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _reportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('report boundary unavailable');
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('report encoding failed');
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      await _channel.invokeMethod<Object?>('saveReportImage', {
        'bytes': data.buffer.asUint8List(),
        'fileName': 'saidian-ecg-report-$stamp.png',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('心电报告已保存到手机相册')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('报告保存失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('心电健康报告')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _reportKey,
          child: ColoredBox(
            color: const Color(0xFFF6F6F7),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '赛电 · 心电健康报告',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  _EcgSummaryCard(record: widget.record),
                  const SizedBox(height: 12),
                  _EcgWaveformCard(
                    samples: widget.record.samples,
                    sampleFrequency:
                        widget.record.values['sampleFrequency']?.toInt() ?? 250,
                    calibrated: widget.record.rawVersion >= 2,
                  ),
                  const SizedBox(height: 12),
                  _EcgMedicalSection(record: widget.record),
                  const SizedBox(height: 12),
                  _EcgRiskSection(record: widget.record),
                  const SizedBox(height: 12),
                  const Text(
                    '说明：本报告由手表测量数据生成，仅供健康管理参考，不能替代医生诊断。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SaydianColors.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: Text(_saving ? '正在保存报告' : '保存报告图片'),
        ),
      ),
    );
  }
}

num? _ecgValue(HealthRecord record, List<String> keys) {
  for (final key in keys) {
    final value = record.values[key];
    if (value != null) return value;
  }
  return null;
}

String _formatEcgNumber(num value) => value == value.round()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

class DeviceFeaturePage extends StatefulWidget {
  const DeviceFeaturePage({
    required this.controller,
    required this.feature,
    super.key,
  });

  final AppController controller;
  final DeviceFeature feature;

  @override
  State<DeviceFeaturePage> createState() => _DeviceFeaturePageState();
}

class _DeviceFeaturePageState extends State<DeviceFeaturePage>
    with WidgetsBindingObserver {
  static const _nativeMethods = MethodChannel('cc.saidian/wearable_methods');
  DeviceScreenSettings? _screen;
  Map<String, Object?> _featureData = const {};
  bool _finding = false;
  Timer? _findResetTimer;
  CameraController? _camera;
  XFile? _lastPhoto;
  String? _cameraMessage;
  bool _takingPhoto = false;
  bool _cameraRemoteStarted = false;
  bool _cameraInitializing = false;
  bool _cameraPermissionRequesting = false;
  bool _cameraPermissionPermanentlyDenied = false;
  int _cameraGeneration = 0;
  late final CameraRemoteShutterGate _cameraShutterGate;
  XFile? _dialPhoto;
  int _dialTimePosition = 0;
  final DeviceWeatherService _weatherService = DeviceWeatherService();
  final DeviceWatchFaceMarketService _watchFaceMarketService =
      DeviceWatchFaceMarketService();
  bool _weatherRefreshing = false;
  String? _weatherMessage;
  bool _openingWatchFaceMarket = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraShutterGate = CameraRemoteShutterGate(
      initialSequence: widget.controller.cameraShutterSequence,
    );
    widget.controller.addListener(_handleControllerEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.controller.availabilityFor(widget.feature).isReady) {
        return;
      }
      if (widget.feature == DeviceFeature.screenDisplay) {
        unawaited(_loadScreen());
      } else if (widget.feature == DeviceFeature.healthMonitoring) {
        unawaited(widget.controller.refreshDeviceSettings());
      } else if (widget.feature == DeviceFeature.camera) {
        unawaited(_initializeCamera());
      } else if (widget.feature != DeviceFeature.findWatch) {
        unawaited(_loadFeature());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerEvent);
    _findResetTimer?.cancel();
    _cameraGeneration += 1;
    final camera = _camera;
    _camera = null;
    camera?.removeListener(_handleCameraState);
    _cameraShutterGate.disarm(
      currentSequence: widget.controller.cameraShutterSequence,
    );
    if (_cameraRemoteStarted) {
      unawaited(_stopCameraRemoteIgnoringErrors());
    }
    _cameraRemoteStarted = false;
    unawaited(camera?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.feature == DeviceFeature.camera) {
      _cameraShutterGate.setLifecycleState(
        state,
        currentSequence: widget.controller.cameraShutterSequence,
      );
      if (state == AppLifecycleState.resumed) {
        unawaited(_resumeCamera());
      } else {
        unawaited(_suspendCamera());
      }
      return;
    }
    if (state == AppLifecycleState.resumed &&
        widget.feature == DeviceFeature.notifications &&
        widget.controller.availabilityFor(widget.feature).isReady) {
      unawaited(_loadFeature());
    }
  }

  void _handleControllerEvent() {
    if (!mounted) return;
    if (widget.feature == DeviceFeature.findWatch &&
        !widget.controller.availabilityFor(widget.feature).isReady &&
        _finding) {
      _findResetTimer?.cancel();
      setState(() => _finding = false);
    }
    if (widget.feature == DeviceFeature.camera) {
      final availability = widget.controller.availabilityFor(widget.feature);
      if (!availability.isReady) {
        _cameraShutterGate.disarm(
          currentSequence: widget.controller.cameraShutterSequence,
        );
        if (_camera != null || _cameraRemoteStarted || _cameraInitializing) {
          unawaited(_suspendCamera(message: '手表已断开，请重新连接后使用'));
        }
        return;
      }
      if (_camera == null &&
          !_cameraInitializing &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_resumeCamera());
      }
      final sequence = widget.controller.cameraShutterSequence;
      if (_cameraShutterGate.shouldCapture(
        sequence: sequence,
        now: DateTime.now(),
      )) {
        unawaited(_takePhoto());
      }
    }
    final latest = widget.controller.deviceFeatureData[widget.feature];
    final progress = latest?['progress'];
    if (progress != null && progress != _featureData['progress']) {
      setState(() => _featureData = {..._featureData, 'progress': progress});
    }
  }

  Future<void> _loadFeature() async {
    final value = await widget.controller.readDeviceFeature(widget.feature);
    if (mounted && value.isNotEmpty) {
      setState(() => _featureData = value);
      if (widget.feature == DeviceFeature.watchFaces) {
        unawaited(_enrichWatchFacePreviews(value));
      }
    }
  }

  Future<void> _enrichWatchFacePreviews(Map<String, Object?> source) async {
    try {
      final profile = DeviceWatchFaceMarketProfile.fromMap(
        await widget.controller.readWatchFaceProfile(),
      );
      if (!profile.matchesDevice(widget.controller.connectedDevice?.id)) return;
      final catalogue = widget.controller.usesNativeWatchFaceMarket
          ? (await widget.controller.readNativeWatchFaceCatalog())
                .map(DeviceWatchFaceMarketItem.fromNative)
                .where(
                  (item) =>
                      item.available &&
                      item.dialShape == profile.dialShape &&
                      item.binProtocol == profile.binProtocol,
                )
                .take(200)
                .toList(growable: false)
          : await _watchFaceMarketService.loadIndex(profile: profile);
      final rawItems = source['items'];
      if (rawItems is! List) return;
      final enriched = rawItems
          .whereType<Map>()
          .map((raw) {
            final face = raw.map((key, value) => MapEntry('$key', value));
            final existingPreview = _watchFaceMarketService
                .hasUsablePreviewReference(face);
            if (existingPreview) return face;
            final installedPath =
                [face['path'], face['id'], face['filePath'], face['name']]
                    .map((value) => '${value ?? ''}'.trim())
                    .firstWhere((value) => value.isNotEmpty, orElse: () => '');
            final match = _watchFaceMarketService.matchInstalledPath(
              installedPath,
              catalogue,
            );
            return match == null
                ? face
                : {...face, 'previewUrl': match.previewUrl.toString()};
          })
          .toList(growable: false);
      if (mounted &&
          profile.matchesDevice(widget.controller.connectedDevice?.id)) {
        setState(() => _featureData = {...source, 'items': enriched});
      }
    } catch (_) {
      // Installed faces remain usable when the online index is unavailable.
    }
  }

  Future<void> _loadScreen() async {
    final value = await widget.controller.readDeviceFeature(widget.feature);
    if (mounted && value.isNotEmpty) {
      setState(() => _screen = DeviceScreenSettings.fromMap(value));
    }
  }

  Future<void> _saveScreen() async {
    final screen = _screen;
    if (screen == null) return;
    final saved = await widget.controller.writeDeviceFeature(
      widget.feature,
      screen.toMap(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? '屏幕设置已保存' : '屏幕设置保存失败，请稍后重试')),
    );
  }

  Future<bool> _saveFeature(
    Map<String, Object?> values,
    String successMessage, {
    bool reload = true,
  }) async {
    final saved = await widget.controller.writeDeviceFeature(
      widget.feature,
      values,
    );
    if (!mounted) return saved;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? successMessage
              : widget.controller.errorMessage ?? '保存失败，请稍后重试',
        ),
      ),
    );
    if (saved && reload) await _loadFeature();
    return saved;
  }

  Future<void> _initializeCamera() async {
    if (_cameraInitializing || _cameraPermissionRequesting || _camera != null) {
      return;
    }
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      _cameraPermissionRequesting = true;
      try {
        var status = await Permission.camera.status;
        if (!status.isGranted) status = await Permission.camera.request();
        if (!mounted) return;
        _cameraPermissionPermanentlyDenied = status.isPermanentlyDenied;
        if (!status.isGranted) {
          setState(() {
            _cameraMessage = status.isPermanentlyDenied
                ? '相机权限已关闭，请在系统设置中开启'
                : '允许相机权限后使用';
          });
          return;
        }
      } on PlatformException {
        if (!mounted) return;
        setState(() => _cameraMessage = '无法读取相机权限，请稍后重试');
        return;
      } finally {
        _cameraPermissionRequesting = false;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
    }
    _cameraInitializing = true;
    final generation = ++_cameraGeneration;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraMessage = '手机没有可用的相机');
        return;
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted ||
          generation != _cameraGeneration ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      controller.addListener(_handleCameraState);
      _handleCameraState();
      if (controller.value.hasError) return;
      final started = await widget.controller.triggerDeviceAction(
        DeviceFeature.camera,
      );
      if (!mounted || generation != _cameraGeneration) {
        if (started) unawaited(_stopCameraRemoteIgnoringErrors());
        return;
      }
      if (controller.value.hasError) {
        _handleCameraState();
        return;
      }
      setState(() {
        _cameraRemoteStarted = started;
        _cameraMessage = started
            ? '可点击手机按钮，也可在手表上点击拍照'
            : widget.controller.errorMessage ?? '手表相机遥控暂时无法开启';
      });
      if (started) {
        _cameraShutterGate.arm(
          now: DateTime.now(),
          currentSequence: widget.controller.cameraShutterSequence,
        );
      } else {
        _cameraShutterGate.disarm(
          currentSequence: widget.controller.cameraShutterSequence,
        );
      }
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraMessage = error.code == 'CameraAccessDenied'
            ? '允许相机权限后使用'
            : '手机相机暂时无法使用，请稍后重试';
      });
    } catch (_) {
      if (mounted) setState(() => _cameraMessage = '手机相机暂时无法使用，请稍后重试');
    } finally {
      if (generation == _cameraGeneration) _cameraInitializing = false;
    }
  }

  Future<void> _retryCamera() async {
    if (_cameraPermissionPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    if (mounted) setState(() => _cameraMessage = null);
    await _initializeCamera();
  }

  Future<void> _suspendCamera({String message = '返回 App 后将重新打开相机'}) async {
    if (widget.feature != DeviceFeature.camera) return;
    final generation = ++_cameraGeneration;
    _cameraInitializing = false;
    final camera = _camera;
    final shouldStopRemote = _cameraRemoteStarted;
    _camera = null;
    _cameraRemoteStarted = false;
    _cameraShutterGate.disarm(
      currentSequence: widget.controller.cameraShutterSequence,
    );
    camera?.removeListener(_handleCameraState);
    if (mounted) {
      setState(() => _cameraMessage = message);
    }
    if (shouldStopRemote) {
      await _stopCameraRemoteIgnoringErrors();
    }
    await camera?.dispose();
    if (generation != _cameraGeneration) return;
  }

  Future<void> _resumeCamera() async {
    if (!mounted || widget.feature != DeviceFeature.camera) return;
    _cameraShutterGate.setLifecycleState(
      AppLifecycleState.resumed,
      currentSequence: widget.controller.cameraShutterSequence,
    );
    if (!widget.controller.availabilityFor(widget.feature).isReady) {
      if (mounted) setState(() => _cameraMessage = '手表已断开，请重新连接后使用');
      return;
    }
    await _initializeCamera();
  }

  Future<void> _stopCameraRemoteIgnoringErrors() async {
    final controller = widget.controller;
    // `dispose` runs while Flutter has the element tree locked. The controller
    // publishes its busy state synchronously, so defer that notification to
    // the next event turn instead of rebuilding listeners during unmount.
    await Future<void>.delayed(Duration.zero);
    try {
      await controller.triggerDeviceAction(
        DeviceFeature.camera,
        enabled: false,
      );
    } catch (_) {
      // The foreground gate still prevents background callbacks from taking a
      // photo when the watch command cannot be stopped immediately.
    }
  }

  void _handleCameraState() {
    final camera = _camera;
    if (!mounted || camera == null || !camera.value.hasError) return;
    final description = camera.value.errorDescription?.trim() ?? '';
    final message = description.toLowerCase().contains('disabled')
        ? '相机已被系统策略停用，请在系统设置中开启相机后重试'
        : '手机相机暂时无法使用，请检查相机权限或系统设置';
    if (_cameraMessage == message) return;
    final shouldStopRemote = _cameraRemoteStarted;
    setState(() {
      _cameraMessage = message;
      _cameraRemoteStarted = false;
    });
    _cameraShutterGate.disarm(
      currentSequence: widget.controller.cameraShutterSequence,
    );
    if (shouldStopRemote) {
      unawaited(
        widget.controller.triggerDeviceAction(
          DeviceFeature.camera,
          enabled: false,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null ||
        !camera.value.isInitialized ||
        camera.value.hasError ||
        _takingPhoto) {
      return;
    }
    setState(() => _takingPhoto = true);
    try {
      final photo = await camera.takePicture();
      final bytes = await photo.readAsBytes();
      final fileName =
          'saidian-camera-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _nativeMethods.invokeMethod<Object?>('saveGalleryImage', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': 'image/jpeg',
      });
      if (mounted) {
        setState(() {
          _lastPhoto = photo;
          _cameraMessage = '照片已保存到手机相册';
        });
      }
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _cameraMessage = '拍照失败（${error.code}），请稍后重试');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _cameraMessage = error.message ?? '照片保存失败，请检查相册权限后重试');
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _toggleFind() async {
    final isOneShot =
        widget.controller.connectedDevice?.sdkSource ==
        WearableSdkSource.yucheng;
    if (isOneShot && _finding) return;
    final next = isOneShot || !_finding;
    final success = await widget.controller.triggerDeviceAction(
      widget.feature,
      enabled: next,
    );
    if (!mounted) return;
    if (success) {
      setState(() => _finding = next);
      if (isOneShot) {
        _findResetTimer?.cancel();
        _findResetTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _finding = false);
        });
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (isOneShot ? '已发送查找指令，请留意手表振动' : (next ? '手表正在响铃或振动' : '已停止查找'))
              : widget.controller.errorMessage ?? '暂时无法查找手表',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final availability = widget.controller.availabilityFor(widget.feature);
        final busy = widget.controller.deviceFeatureBusy.contains(
          widget.feature,
        );
        return Scaffold(
          appBar: AppBar(title: Text(widget.feature.label)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DeviceFeatureHeader(
                feature: widget.feature,
                device: widget.controller.connectedDevice,
              ),
              const SizedBox(height: 14),
              if (!availability.isReady)
                FeatureStateCard(
                  message: availability.message,
                  detail: _deviceFeatureDescription(widget.feature),
                  icon: _deviceFeatureIcon(widget.feature),
                )
              else if (widget.feature == DeviceFeature.findWatch)
                _FindWatchPanel(
                  finding: _finding,
                  busy: busy,
                  supportsStop:
                      widget.controller.connectedDevice?.sdkSource !=
                      WearableSdkSource.yucheng,
                  onPressed: _toggleFind,
                )
              else if (widget.feature == DeviceFeature.screenDisplay)
                _ScreenSettingsPanel(
                  settings: _screen,
                  busy: busy,
                  onReload: _loadScreen,
                  onChanged: (value) => setState(() => _screen = value),
                  onSave: _saveScreen,
                )
              else
                _buildReadyContent(busy),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadyContent(bool busy) => switch (widget.feature) {
    DeviceFeature.watchFaces => _buildWatchFacesPanel(busy),
    DeviceFeature.photoWatchFace => _buildPhotoWatchFacePanel(busy),
    DeviceFeature.camera => _buildCameraPanel(),
    DeviceFeature.phoneCalls => _buildPhoneCallsPanel(busy),
    DeviceFeature.contacts => _buildContactsPanel(busy),
    DeviceFeature.notifications => _buildNotificationsPanel(busy),
    DeviceFeature.alarms => _buildAlarmsPanel(busy),
    DeviceFeature.weather => _buildWeatherPanel(busy),
    DeviceFeature.worldClock => _buildWorldClocksPanel(busy),
    DeviceFeature.healthReminders => _buildHealthRemindersPanel(busy),
    DeviceFeature.healthAssessment => _buildHealthAssessmentPanel(busy),
    DeviceFeature.healthMonitoring => _buildHealthMonitoringPanel(),
    _ => FeatureStateCard(
      message: '请在手表上操作',
      detail: _deviceFeatureDescription(widget.feature),
      icon: _deviceFeatureIcon(widget.feature),
    ),
  };

  List<Map<String, Object?>> get _items {
    final raw = _featureData['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  Widget _loadingCard(bool busy, String label) => FeatureStateCard(
    message: busy ? '正在读取$label' : '暂时未读取到$label',
    detail: '请保持手表靠近手机后重试。',
    icon: _deviceFeatureIcon(widget.feature),
    actionLabel: busy ? null : '重新读取',
    onAction: busy ? null : _loadFeature,
  );

  Widget _buildWatchFacesPanel(bool busy) {
    final noLocalData = _featureData.isEmpty;
    final faces = _items;
    final progress = (_featureData['progress'] as num?)?.toInt();
    final onlineMarketSupported = _featureData['onlineMarketSupported'] == true;
    return Column(
      children: [
        if (onlineMarketSupported) ...[
          Card(
            color: SaydianColors.brandRedSoft,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              leading: const Icon(
                Icons.watch_rounded,
                color: SaydianColors.brandRed,
                size: 34,
              ),
              title: const Text(
                '表盘商城',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('浏览并下载适配当前手表的在线表盘'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: busy || _openingWatchFaceMarket
                  ? null
                  : _openWatchFaceMarket,
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('已安装表盘'),
              subtitle: const Text('可读取和切换手表内已有表盘，更多表盘以当前手表支持情况为准。'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '手表中的表盘',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        if (busy && progress != null && progress > 0) ...[
          LinearProgressIndicator(value: progress.clamp(0, 100) / 100),
          const SizedBox(height: 10),
          Text('正在读取表盘 $progress%'),
          const SizedBox(height: 12),
        ],
        if (noLocalData)
          _loadingCard(busy, '手表中的表盘')
        else
          Card(
            child: faces.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('手表中暂未读取到可切换的表盘')),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < faces.length; index++) ...[
                        ListTile(
                          minLeadingWidth: 64,
                          leading: _WatchFaceThumbnail(face: faces[index]),
                          title: Text('${faces[index]['name'] ?? '手表表盘'}'),
                          subtitle: Text(
                            faces[index]['isCurrent'] == true
                                ? '当前使用'
                                : '${faces[index]['status'] ?? '手表表盘'}',
                          ),
                          trailing: faces[index]['isCurrent'] == true
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: SaydianColors.green,
                                )
                              : TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => _switchWatchFace(faces[index]),
                                  child: const Text('使用'),
                                ),
                        ),
                        if (index != faces.length - 1)
                          const Divider(indent: 72),
                      ],
                    ],
                  ),
          ),
        if (!noLocalData) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : _loadFeature,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新手表表盘'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openWatchFaceMarket() async {
    if (_openingWatchFaceMarket) return;
    setState(() => _openingWatchFaceMarket = true);
    try {
      final profileData = await widget.controller.readWatchFaceProfile();
      final profile = DeviceWatchFaceMarketProfile.fromMap(profileData);
      if (!profile.matchesDevice(widget.controller.connectedDevice?.id)) {
        throw const DeviceWatchFaceMarketException('连接设备已变化，请重新进入表盘中心');
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DeviceWatchFaceMarketPage(
            controller: widget.controller,
            profile: profile,
          ),
        ),
      );
    } on DeviceWatchFaceMarketException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _openingWatchFaceMarket = false);
    }
  }

  Future<void> _switchWatchFace(Map<String, Object?> face) async {
    await _saveFeature({
      'operation': 'switch',
      'id': '${face['id'] ?? ''}',
      'type': '${face['type'] ?? ''}',
      'index': (face['index'] as num?)?.toInt() ?? 0,
    }, '表盘已切换');
  }

  Widget _buildPhotoWatchFacePanel(bool busy) {
    final progress = (_featureData['progress'] as num?)?.toInt() ?? 0;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      key: const Key('photo-watch-face-picker'),
                      onTap: busy ? null : _pickDialPhoto,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 126,
                        height: 154,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          border: Border.all(color: const Color(0xFFD9DDE3)),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: _dialPhoto == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 38,
                                    color: SaydianColors.brandRed,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '点击选择照片',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              )
                            : Image.file(
                                File(_dialPhoto!.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '照片表盘',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '选择一张清晰照片，预览无误后再传送到手表。',
                            style: TextStyle(
                              color: SaydianColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _pickDialPhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(_dialPhoto == null ? '选择照片' : '更换照片'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (busy) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: progress > 0 ? progress.clamp(0, 100) / 100 : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      progress > 0 ? '正在传送到手表 $progress%' : '正在准备照片表盘',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _dialTimePosition,
                  decoration: const InputDecoration(
                    labelText: '时间显示位置',
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('顶部居中')),
                    DropdownMenuItem(value: 1, child: Text('画面中央')),
                    DropdownMenuItem(value: 2, child: Text('底部居中')),
                    DropdownMenuItem(value: 3, child: Text('左上角')),
                    DropdownMenuItem(value: 4, child: Text('右上角')),
                    DropdownMenuItem(value: 5, child: Text('左下角')),
                    DropdownMenuItem(value: 6, child: Text('右下角')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) =>
                            setState(() => _dialTimePosition = value ?? 0),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy || _dialPhoto == null
                        ? null
                        : _uploadDialPhoto,
                    icon: const Icon(Icons.watch_rounded),
                    label: const Text('传送并设为表盘'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '传送时请保持手表靠近手机，并避免切换到其他页面。',
          textAlign: TextAlign.center,
          style: TextStyle(color: SaydianColors.muted, fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _pickDialPhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (photo != null && mounted) setState(() => _dialPhoto = photo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('允许照片权限后使用')));
    }
  }

  Future<void> _uploadDialPhoto() async {
    final photo = _dialPhoto;
    if (photo == null) return;
    await _saveFeature(
      {
        'operation': 'upload_photo',
        'imagePath': photo.path,
        'timePosition': _dialTimePosition,
      },
      '照片表盘已设置',
      reload: false,
    );
  }

  Widget _buildCameraPanel() {
    final camera = _camera;
    final previewHeight = math.min(
      MediaQuery.sizeOf(context).height * .56,
      560.0,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: previewHeight,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (camera != null &&
                      camera.value.isInitialized &&
                      !camera.value.hasError)
                    Center(
                      child: AspectRatio(
                        // Camera preview sizes are reported in the sensor's
                        // landscape orientation. In this portrait page the
                        // inverse ratio preserves the natural image without
                        // stretching or cropping.
                        aspectRatio: 1 / camera.value.aspectRatio,
                        child: CameraPreview(camera),
                      ),
                    )
                  else
                    Center(
                      child: _cameraMessage == null
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(
                              Icons.no_photography_outlined,
                              color: Colors.white70,
                              size: 54,
                            ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .58),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            child: Text(
                              _cameraMessage ?? '正在打开相机',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          button: true,
                          label: '拍照并保存到手机',
                          child: SizedBox(
                            width: 68,
                            height: 68,
                            child: FilledButton(
                              key: const ValueKey('camera-shutter-button'),
                              onPressed:
                                  camera == null ||
                                      camera.value.hasError ||
                                      _takingPhoto
                                  ? null
                                  : _takePhoto,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: SaydianColors.brandRed,
                                disabledBackgroundColor: Colors.white54,
                                shape: const CircleBorder(
                                  side: BorderSide(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: _takingPhoto
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: SaydianColors.brandRed,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 30,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.watch_rounded, color: SaydianColors.brandRed),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '可点击手机快门，也可按手表拍照键；照片会保存到手机相册。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SaydianColors.muted),
                      ),
                    ),
                  ],
                ),
                if (camera == null && _cameraMessage != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const ValueKey('camera-retry-button'),
                    onPressed:
                        _cameraInitializing || _cameraPermissionRequesting
                        ? null
                        : _retryCamera,
                    icon: Icon(
                      _cameraPermissionPermanentlyDenied
                          ? Icons.settings_outlined
                          : Icons.refresh_rounded,
                    ),
                    label: Text(
                      _cameraPermissionPermanentlyDenied ? '前往系统设置' : '重新打开相机',
                    ),
                  ),
                ],
                if (_lastPhoto != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_lastPhoto!.path),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCallsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '通话设置');
    final status = switch (_featureData['connectionStatus']) {
      'connected' => '通话连接已建立',
      'broadcasting' => '等待手机配对',
      _ => '通话连接未建立',
    };
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.bluetooth_audio_rounded),
            title: Text(status),
            subtitle: Text(
              _featureData['paired'] == true ? '手机已保存配对信息' : '请在手机蓝牙设置中完成配对',
            ),
            trailing: IconButton(
              onPressed: busy ? null : _loadFeature,
              tooltip: '刷新',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const Divider(indent: 56),
          ListTile(
            leading: Icon(
              _featureData['audioEnabled'] == true
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_outlined,
            ),
            title: const Text('通话与媒体声音'),
            subtitle: Text(
              _featureData['audioEnabled'] == true ? '手表媒体声音已连接' : '媒体声音尚未连接',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    busy || _featureData['connectionStatus'] == 'connected'
                    ? null
                    : () => _saveFeature(const {
                        'enabled': true,
                      }, '已发送通话连接请求，请按系统提示完成配对'),
                icon: const Icon(Icons.bluetooth_connected_rounded),
                label: Text(
                  _featureData['connectionStatus'] == 'connected'
                      ? '通话连接已建立'
                      : '建立通话连接',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureSwitch({
    required String title,
    required String subtitle,
    required String keyName,
    required bool busy,
    bool supported = true,
  }) => SwitchListTile(
    title: Text(title),
    subtitle: Text(supported ? subtitle : '当前手表不支持此项'),
    value: _featureData[keyName] == true,
    onChanged: busy || !supported
        ? null
        : (value) =>
              _saveFeature({..._featureData, keyName: value}, '$title已保存'),
  );

  Widget _buildNotificationsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '消息通知设置');
    final supported = (_featureData['supportedKeys'] as List?)
        ?.map((value) => '$value')
        .toSet();
    final entries = <(String, String, String)>[
      ('incomingCall', '来电提醒', '有电话时在手表提醒'),
      ('sms', '短信', '在手表显示短信提醒'),
      ('wechat', '微信', '在手表显示微信消息提醒'),
      ('qq', 'QQ', '在手表显示 QQ 消息提醒'),
      ('whatsapp', 'WhatsApp', '在手表显示 WhatsApp 消息提醒'),
      ('dingtalk', '钉钉', '在手表显示钉钉消息提醒'),
      ('wecom', '企业微信', '在手表显示企业微信消息提醒'),
      ('tiktok', '抖音', '在手表显示抖音消息提醒'),
      ('telegram', 'Telegram', '在手表显示 Telegram 消息提醒'),
      ('otherApps', '其他应用', '接收其他已允许应用的消息提醒'),
    ];
    final access = _featureData['notificationAccess'] == true;
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              access ? Icons.verified_user_rounded : Icons.security_rounded,
              color: access ? SaydianColors.green : SaydianColors.orange,
            ),
            title: Text(access ? '手机通知权限已允许' : '还需允许手机通知权限'),
            subtitle: Text(access ? '已开启的应用消息可以发送到手表' : '允许后，手表才能显示手机收到的应用消息'),
            trailing: TextButton(
              onPressed: busy
                  ? null
                  : access
                  ? _loadFeature
                  : _openNotificationSettings,
              child: Text(access ? '重新检查' : '去设置'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                _featureSwitch(
                  keyName: entries[index].$1,
                  title: entries[index].$2,
                  subtitle: entries[index].$3,
                  busy: busy,
                  supported: supported?.contains(entries[index].$1) ?? true,
                ),
                if (index != entries.length - 1) const Divider(indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openNotificationSettings() async {
    final opened = await widget.controller.triggerDeviceAction(
      DeviceFeature.notifications,
    );
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.errorMessage ?? '无法打开系统设置')),
    );
  }

  Widget _buildWeatherPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '天气设置');
    final city = '${_featureData['city'] ?? ''}'.trim();
    final updatedAt = (_featureData['updatedAt'] as num?)?.toInt() ?? 0;
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              _featureSwitch(
                keyName: 'enabled',
                title: '在手表显示天气',
                subtitle: '开启后可在手表查看天气信息',
                busy: busy || _weatherRefreshing,
              ),
              const Divider(indent: 56),
              SwitchListTile(
                title: const Text('使用摄氏度'),
                subtitle: Text(
                  _featureData['useCelsius'] == true ? '温度显示为 ℃' : '温度显示为 ℉',
                ),
                value: _featureData['useCelsius'] == true,
                onChanged: busy || _weatherRefreshing
                    ? null
                    : (value) => _saveFeature({
                        ..._featureData,
                        'useCelsius': value,
                      }, '温度单位已保存'),
              ),
              if (city.isNotEmpty) ...[
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(city),
                  subtitle: Text(
                    updatedAt > 0
                        ? '上次更新 ${_weatherTimeLabel(updatedAt)}'
                        : '已同步到手表',
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy || _weatherRefreshing
                            ? null
                            : _syncWeather,
                        icon: _weatherRefreshing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_sync_outlined),
                        label: Text(_weatherRefreshing ? '正在更新天气' : '更新当前位置天气'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy || _weatherRefreshing
                            ? null
                            : _chooseWeatherCity,
                        icon: const Icon(Icons.location_city_outlined),
                        label: const Text('选择城市'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_weatherMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _weatherMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Future<void> _chooseWeatherCity() async {
    final city = await showDialog<String>(
      context: context,
      builder: (_) => const _CityInputDialog(),
    );
    if (city == null || !mounted) return;
    await _syncWeather(city: city);
  }

  Future<void> _syncWeather({String? city}) async {
    setState(() {
      _weatherRefreshing = true;
      _weatherMessage = null;
    });
    try {
      final forecast = city == null
          ? await _weatherService.loadCurrentLocation()
          : await _weatherService.loadCity(city);
      final values = forecast.toFeatureValues(
        useCelsius: _featureData['useCelsius'] != false,
      );
      final saved = await _saveFeature(values, '天气已同步到手表', reload: false);
      if (saved && mounted) {
        setState(() {
          _featureData = {..._featureData, ...values};
          _weatherMessage = '${forecast.city}天气已更新';
        });
      }
    } on DeviceWeatherException catch (error) {
      if (!mounted) return;
      setState(() => _weatherMessage = error.message);
      if (error.openSettings) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            action: SnackBarAction(
              label: '去设置',
              onPressed: () {
                if (error.locationSettings) {
                  unawaited(Geolocator.openLocationSettings());
                } else {
                  unawaited(Geolocator.openAppSettings());
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _weatherMessage = '天气更新失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _weatherRefreshing = false);
    }
  }

  String _weatherTimeLabel(int milliseconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${value.month}月${value.day}日 '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAlarmsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '闹钟');
    final alarms = _items;
    return Column(
      children: [
        Card(
          child: alarms.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('手表中还没有闹钟')),
                )
              : Column(
                  children: [
                    for (var index = 0; index < alarms.length; index++) ...[
                      _alarmTile(alarms[index], busy),
                      if (index != alarms.length - 1) const Divider(indent: 56),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : () => _showAlarmEditor(),
            icon: const Icon(Icons.add_alarm_rounded),
            label: const Text('添加闹钟'),
          ),
        ),
      ],
    );
  }

  Widget _alarmTile(Map<String, Object?> alarm, bool busy) {
    final hour = (alarm['hour'] as num?)?.toInt() ?? 0;
    final minute = (alarm['minute'] as num?)?.toInt() ?? 0;
    final enabled = alarm['enabled'] == true;
    final label = alarm['label']?.toString().trim() ?? '';
    final repeatLabel = _repeatDaysLabel(alarm['repeatDays']);
    return ListTile(
      onTap: busy ? null : () => _showAlarmEditor(alarm),
      leading: const Icon(Icons.alarm_rounded),
      title: Text(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(label.isEmpty ? repeatLabel : '$label · $repeatLabel'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: enabled,
            onChanged: busy
                ? null
                : (value) => _saveFeature({
                    ...alarm,
                    'operation': 'update',
                    'enabled': value,
                  }, value ? '闹钟已开启' : '闹钟已关闭'),
          ),
          IconButton(
            onPressed: busy ? null : () => _deleteAlarm(alarm),
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlarmEditor([Map<String, Object?>? alarm]) async {
    var time = TimeOfDay(
      hour: (alarm?['hour'] as num?)?.toInt() ?? 8,
      minute: (alarm?['minute'] as num?)?.toInt() ?? 0,
    );
    final repeatDays =
        (alarm?['repeatDays'] as List?)
            ?.whereType<num>()
            .map((day) => day.toInt())
            .toSet() ??
        <int>{1, 2, 3, 4, 5, 6, 7};
    var enabled = alarm?['enabled'] != false;
    var label = alarm?['label']?.toString().trim() ?? '闹钟';
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(alarm == null ? '添加闹钟' : '编辑闹钟'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('提醒时间'),
                  subtitle: Text(time.format(context)),
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: dialogContext,
                      initialTime: time,
                    );
                    if (selected != null) setDialogState(() => time = selected);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用闹钟'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                TextFormField(
                  initialValue: label,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: '提醒名称',
                    hintText: '例如：吃药、起床',
                  ),
                  onChanged: (value) => label = value.trim(),
                ),
                const SizedBox(height: 8),
                const Text('重复'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(
                          const ['一', '二', '三', '四', '五', '六', '日'][day - 1],
                        ),
                        selected: repeatDays.contains(day),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            repeatDays.add(day);
                          } else {
                            repeatDays.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, <String, Object?>{
                if (alarm?['id'] != null) 'id': alarm!['id'],
                'operation': alarm == null ? 'add' : 'update',
                'hour': time.hour,
                'minute': time.minute,
                'enabled': enabled,
                'label': label.isEmpty ? '闹钟' : label,
                'repeatDays': repeatDays.toList()..sort(),
              }),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (values != null) await _saveFeature(values, '闹钟已保存');
  }

  Future<void> _deleteAlarm(Map<String, Object?> alarm) async {
    final confirmed = await _confirm('删除闹钟', '确定删除这个闹钟吗？');
    if (!confirmed) return;
    await _saveFeature({...alarm, 'operation': 'delete'}, '闹钟已删除');
  }

  String _repeatDaysLabel(Object? raw) {
    final days =
        (raw as List?)?.whereType<num>().map((day) => day.toInt()).toSet() ??
        {};
    if (days.isEmpty) return '仅一次';
    if (days.length == 7) return '每天';
    if (days.length == 5 && days.containsAll([1, 2, 3, 4, 5])) return '工作日';
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final sorted = days.toList()..sort();
    return sorted.map((day) => labels[day - 1]).join('、');
  }

  Widget _buildContactsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '联系人');
    final contacts = _items;
    Map<String, Object?>? emergency;
    for (final contact in contacts) {
      if (contact['isEmergency'] == true) {
        emergency = contact;
        break;
      }
    }
    return Column(
      children: [
        Card(
          color: SaydianColors.brandRedSoft,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: SaydianColors.brandRed,
              foregroundColor: Colors.white,
              child: Icon(Icons.sos_rounded),
            ),
            title: const Text(
              'SOS 紧急联系人',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              emergency == null
                  ? '尚未设置，手表触发 SOS 时将无法快速联系家人'
                  : '${emergency['name'] ?? ''}  ${emergency['phone'] ?? ''}',
            ),
            trailing: TextButton(
              onPressed: busy || contacts.isEmpty
                  ? null
                  : () => _selectEmergencyContact(contacts),
              child: Text(emergency == null ? '立即设置' : '更换'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: contacts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('手表中还没有常用联系人')),
                )
              : Column(
                  children: [
                    for (var index = 0; index < contacts.length; index++) ...[
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(_contactInitial(contacts[index])),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${contacts[index]['name'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (contacts[index]['isEmergency'] == true)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: SaydianColors.brandRedSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: SaydianColors.brandRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text('${contacts[index]['phone'] ?? ''}'),
                        trailing: IconButton(
                          onPressed: busy
                              ? null
                              : () => _deleteContact(contacts[index]),
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                      if (index != contacts.length - 1)
                        const Divider(indent: 56),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || contacts.length >= 10
                ? null
                : _showContactEditor,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(contacts.length >= 10 ? '联系人已满' : '添加联系人'),
          ),
        ),
      ],
    );
  }

  Future<void> _showContactEditor() async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _ContactEditorDialog(),
    );
    if (values != null) await _saveFeature(values, '联系人已添加');
  }

  Future<void> _deleteContact(Map<String, Object?> contact) async {
    final confirmed = await _confirm('删除联系人', '确定从手表删除这个联系人吗？');
    if (!confirmed) return;
    await _saveFeature({...contact, 'operation': 'delete'}, '联系人已删除');
  }

  Future<void> _toggleEmergencyContact(Map<String, Object?> contact) async {
    final enabled = contact['isEmergency'] != true;
    await _saveFeature({
      ...contact,
      'operation': 'emergency',
      'isEmergency': enabled,
    }, enabled ? '已设为紧急联系人' : '已取消紧急联系人');
  }

  Future<void> _selectEmergencyContact(
    List<Map<String, Object?>> contacts,
  ) async {
    final supported = contacts
        .where((contact) => contact['supportsEmergency'] == true)
        .toList(growable: false);
    if (supported.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前手表不支持设置 SOS 联系人')));
      return;
    }
    Map<String, Object?>? picked = supported.firstWhere(
      (contact) => contact['isEmergency'] == true,
      orElse: () => supported.first,
    );
    final selected = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '选择 SOS 紧急联系人',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  '手表触发 SOS 后，会优先联系这里选择的人。建议选择最常联系的家人。',
                  style: TextStyle(color: SaydianColors.muted, height: 1.5),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: supported.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = supported[index];
                      final chosen = identical(picked, contact);
                      return Material(
                        color: chosen
                            ? SaydianColors.brandRedSoft
                            : const Color(0xFFF7F7F8),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: chosen
                                ? SaydianColors.brandRed
                                : const Color(0xFFE4E4E7),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          onTap: () => setSheetState(() => picked = contact),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            child: Text(_contactInitial(contact)),
                          ),
                          title: Text(
                            '${contact['name'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text('${contact['phone'] ?? ''}'),
                          trailing: Icon(
                            chosen
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: chosen
                                ? SaydianColors.brandRed
                                : SaydianColors.muted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: picked == null
                      ? null
                      : () => Navigator.pop(sheetContext, picked),
                  icon: const Icon(Icons.sos_rounded),
                  label: const Text('确认设为 SOS 联系人'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && selected['isEmergency'] != true) {
      await _toggleEmergencyContact(selected);
    }
  }

  String _contactInitial(Map<String, Object?> contact) {
    final name = '${contact['name'] ?? '联'}'.trim();
    return name.isEmpty ? '联' : name.substring(0, 1);
  }

  Widget _buildWorldClocksPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '世界时钟');
    final clocks = _items;
    return Column(
      children: [
        Card(
          child: clocks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('手表中还没有世界时钟')),
                )
              : Column(
                  children: [
                    for (var index = 0; index < clocks.length; index++) ...[
                      ListTile(
                        leading: const Icon(Icons.public_rounded),
                        title: Text('${clocks[index]['city'] ?? ''}'),
                        subtitle: Text(
                          _utcLabel(
                            (clocks[index]['utcOffsetMinutes'] as num?)
                                    ?.toInt() ??
                                0,
                          ),
                        ),
                        trailing: IconButton(
                          onPressed: busy
                              ? null
                              : () => _deleteWorldClock(clocks[index]),
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                      if (index != clocks.length - 1) const Divider(indent: 56),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || clocks.length >= 10
                ? null
                : _showWorldClockEditor,
            icon: const Icon(Icons.add_rounded),
            label: Text(clocks.length >= 10 ? '世界时钟已满' : '添加城市'),
          ),
        ),
      ],
    );
  }

  Future<void> _showWorldClockEditor() async {
    const cities = <(String, int)>[
      ('北京', 480),
      ('东京', 540),
      ('新加坡', 480),
      ('迪拜', 240),
      ('伦敦', 0),
      ('巴黎', 60),
      ('纽约', -300),
      ('洛杉矶', -480),
      ('悉尼', 600),
    ];
    var selected = cities.first;
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加世界时钟'),
          content: DropdownButtonFormField<(String, int)>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: '城市'),
            items: [
              for (final city in cities)
                DropdownMenuItem(
                  value: city,
                  child: Text('${city.$1}  ${_utcLabel(city.$2)}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, <String, Object?>{
                'operation': 'add',
                'city': selected.$1,
                'utcOffsetMinutes': selected.$2,
                'enabled': true,
              }),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (values != null) await _saveFeature(values, '世界时钟已添加');
  }

  Future<void> _deleteWorldClock(Map<String, Object?> clock) async {
    final confirmed = await _confirm('删除世界时钟', '确定从手表删除这个城市吗？');
    if (!confirmed) return;
    await _saveFeature({...clock, 'operation': 'delete'}, '世界时钟已删除');
  }

  String _utcLabel(int minutes) {
    final sign = minutes >= 0 ? '+' : '-';
    final absolute = minutes.abs();
    return 'UTC$sign${(absolute ~/ 60).toString().padLeft(2, '0')}:${(absolute % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildHealthRemindersPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '健康提醒');
    final reminders = _items;
    return Card(
      child: reminders.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('当前手表没有可设置的健康提醒')),
            )
          : Column(
              children: [
                for (var index = 0; index < reminders.length; index++) ...[
                  ListTile(
                    onTap: busy
                        ? null
                        : () => _showReminderEditor(reminders[index]),
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text('${reminders[index]['label'] ?? '健康提醒'}'),
                    subtitle: Text(
                      '${_minutesLabel((reminders[index]['startMinutes'] as num?)?.toInt() ?? 0)}–'
                      '${_minutesLabel((reminders[index]['endMinutes'] as num?)?.toInt() ?? 0)}，'
                      '每 ${(reminders[index]['intervalMinutes'] as num?)?.toInt() ?? 60} 分钟',
                    ),
                    trailing: Switch(
                      value: reminders[index]['enabled'] == true,
                      onChanged: busy
                          ? null
                          : (value) => _saveFeature({
                              ...reminders[index],
                              'enabled': value,
                            }, value ? '提醒已开启' : '提醒已关闭'),
                    ),
                  ),
                  if (index != reminders.length - 1) const Divider(indent: 56),
                ],
              ],
            ),
    );
  }

  Future<void> _showReminderEditor(Map<String, Object?> reminder) async {
    var startMinutes = (reminder['startMinutes'] as num?)?.toInt() ?? 480;
    var endMinutes = (reminder['endMinutes'] as num?)?.toInt() ?? 1320;
    var interval = (reminder['intervalMinutes'] as num?)?.toInt() ?? 60;
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${reminder['label'] ?? '健康提醒'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开始时间'),
                trailing: Text(_minutesLabel(startMinutes)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay(
                      hour: startMinutes ~/ 60,
                      minute: startMinutes % 60,
                    ),
                  );
                  if (time != null) {
                    setDialogState(
                      () => startMinutes = time.hour * 60 + time.minute,
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('结束时间'),
                trailing: Text(_minutesLabel(endMinutes)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay(
                      hour: endMinutes ~/ 60,
                      minute: endMinutes % 60,
                    ),
                  );
                  if (time != null) {
                    setDialogState(
                      () => endMinutes = time.hour * 60 + time.minute,
                    );
                  }
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: interval,
                decoration: const InputDecoration(labelText: '提醒间隔'),
                items: const [30, 45, 60, 90, 120]
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes 分钟'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => interval = value ?? interval),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, <String, Object?>{
                ...reminder,
                'startMinutes': startMinutes,
                'endMinutes': endMinutes,
                'intervalMinutes': interval,
              }),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (values != null) await _saveFeature(values, '健康提醒已保存');
  }

  Widget _buildHealthAssessmentPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '辅助评估设置');
    final items = _items;
    if (items.isEmpty) {
      return const FeatureStateCard(
        message: '当前手表没有可设置的辅助评估',
        detail: '不同型号支持的项目可能不同，请以手表实际显示为准。',
        icon: Icons.assignment_turned_in_outlined,
      );
    }
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.health_and_safety_outlined),
                  title: Text('${items[index]['label'] ?? '健康辅助功能'}'),
                  subtitle: const Text('开启后由手表提供日常趋势参考'),
                  value: items[index]['enabled'] == true,
                  onChanged: busy
                      ? null
                      : (value) => _saveFeature({
                          ...items[index],
                          'enabled': value,
                        }, value ? '已开启' : '已关闭'),
                ),
                if (index != items.length - 1) const Divider(indent: 56),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '辅助评估仅供日常健康管理参考，不用于诊断或治疗。',
          textAlign: TextAlign.center,
          style: TextStyle(color: SaydianColors.muted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildHealthMonitoringPanel() {
    final settings = widget.controller.autoMeasureSettings;
    final warningSupported = widget.controller.heartRateWarningSupported;
    if (settings.isEmpty && !warningSupported) {
      return FeatureStateCard(
        message: widget.controller.deviceSettingsStatus,
        detail: '读取结果以当前连接手表实际支持的自动检测项目为准。',
        icon: Icons.monitor_heart_outlined,
        actionLabel: '重新读取',
        onAction: widget.controller.refreshDeviceSettings,
      );
    }
    const labels = <String, String>{
      'heartRate': '心率自动检测',
      'bloodPressure': '血压自动检测',
      'bloodGlucose': '血糖自动检测',
      'bodyTemperature': '体温自动检测',
    };
    final entries = settings.entries.toList(growable: false);
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.sensors_rounded),
                  title: Text(labels[entries[index].key] ?? entries[index].key),
                  subtitle: const Text('开启后由手表按设备设定周期自动检测'),
                  value: entries[index].value,
                  onChanged: (enabled) => widget.controller
                      .setAutoMeasureSetting(entries[index].key, enabled),
                ),
                if (index != entries.length - 1)
                  const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
        if (warningSupported) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: SaydianColors.orange,
              ),
              title: const Text('手表心率预警'),
              subtitle: const Text('持续超过阈值时由手表提醒'),
              trailing: DropdownButton<int>(
                value: widget.controller.heartRateWarning,
                items: [
                  for (var value = 70; value <= 185; value += 5)
                    DropdownMenuItem(value: value, child: Text('$value bpm')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    widget.controller.setHeartRateWarning(value);
                  }
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.controller.refreshDeviceSettings,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(widget.controller.deviceSettingsStatus),
        ),
      ],
    );
  }

  String _minutesLabel(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确定'),
            ),
          ],
        ),
      ) ??
      false;
}

class _WatchFaceThumbnail extends StatelessWidget {
  const _WatchFaceThumbnail({required this.face});

  final Map<String, Object?> face;

  @override
  Widget build(BuildContext context) {
    final source = _imageSource;
    final fallback = _fallback;
    Widget image = fallback;
    if (source != null) {
      final uri = Uri.tryParse(source);
      if (uri != null && uri.isScheme('https')) {
        image = Image.network(
          source,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      } else {
        final file = File(source.replaceFirst('file://', ''));
        if (file.existsSync()) {
          image = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      }
    }
    return Semantics(
      image: true,
      label: source == null
          ? '${face['name'] ?? '表盘'}预览暂不可用'
          : '${face['name'] ?? '表盘'}缩略图',
      child: Container(
        width: 62,
        height: 62,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.black12),
        ),
        child: image,
      ),
    );
  }

  String? get _imageSource {
    return DeviceWatchFaceMarketService.findUsablePreviewReference(face);
  }

  Widget get _fallback {
    return ColoredBox(
      color: const Color(0xFFF1F3F5),
      child: Center(
        child: Text(
          '预览\n暂不可用',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SaydianColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DeviceFeatureHeader extends StatelessWidget {
  const _DeviceFeatureHeader({required this.feature, required this.device});

  final DeviceFeature feature;
  final DeviceInfo? device;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: SaydianColors.blue.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_deviceFeatureIcon(feature), color: SaydianColors.blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _deviceFeatureDescription(feature),
                  style: const TextStyle(
                    color: SaydianColors.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EcgWaveformCard extends StatelessWidget {
  const _EcgWaveformCard({
    required this.samples,
    required this.sampleFrequency,
    required this.calibrated,
  });

  final List<num> samples;
  final int sampleFrequency;
  final bool calibrated;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('心电波形', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              FeatureStateCard(
                message: '手表未返回可用心电波形',
                detail: '本次同步的心率、HRV 和 QT 等指标仍可查看；App 不会根据无效采样生成波形。',
                icon: Icons.monitor_heart_outlined,
              ),
            ],
          ),
        ),
      );
    }
    if (!calibrated) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('心电波形', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              FeatureStateCard(
                message: '该记录未保存有效的波形增益信息',
                detail: '平均心率和 HRV 等结果仍可查看；请使用当前版本重新测量心电，以生成经过设备增益校准的波形。',
                icon: Icons.monitor_heart_outlined,
              ),
            ],
          ),
        ),
      );
    }
    final frequency = sampleFrequency.clamp(50, 1000);
    final usableSamples = selectUsableEcgTail(
      samples,
      sampleFrequency: frequency,
    );
    final displaySamples = usableSamples.isEmpty ? samples : usableSamples;
    final durationSeconds = displaySamples.length / frequency;
    final chartWidth = math.max(640.0, durationSeconds * 72.0);
    final waveform = prepareEcgDisplayWaveform(
      displaySamples,
      maximumPoints: math.max(2, (chartWidth * 2).round()),
      sampleFrequency: frequency,
      removeContactArtifacts: true,
    );
    final spots = waveform.samples
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('心电波形', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '共 ${durationSeconds.toStringAsFixed(1)} 秒 · 左右滑动查看完整记录',
              style: const TextStyle(color: SaydianColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (!waveform.hasVariation)
              const FeatureStateCard(
                message: '本次未返回有效心电波形',
                detail: '心率和 HRV 等结果仍可查看；下次测量时请持续接触手表电极。',
                icon: Icons.monitor_heart_outlined,
              )
            else
              Semantics(
                label: '设备记录的有效心电波形，共${displaySamples.length}个采样点',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minY: waveform.minimum,
                        maxY: waveform.maximum,
                        gridData: FlGridData(
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: SaydianColors.pink.withValues(alpha: 0.12),
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (_) => FlLine(
                            color: SaydianColors.pink.withValues(alpha: 0.08),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            color: SaydianColors.pink,
                            barWidth: 1.8,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FindWatchPanel extends StatelessWidget {
  const _FindWatchPanel({
    required this.finding,
    required this.busy,
    required this.supportsStop,
    required this.onPressed,
  });

  final bool finding;
  final bool busy;
  final bool supportsStop;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              finding
                  ? Icons.notifications_active_rounded
                  : Icons.watch_rounded,
              size: 68,
              color: finding ? SaydianColors.orange : SaydianColors.ink,
            ),
            const SizedBox(height: 14),
            Text(
              finding
                  ? (supportsStop ? '请留意附近响铃或振动的手表' : '查找指令已发送，请留意手表振动')
                  : '让手表响铃或振动，帮助你快速找到它',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy || (finding && !supportsStop)
                    ? null
                    : onPressed,
                child: Text(
                  finding ? (supportsStop ? '停止查找' : '正在查找') : '开始查找',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenSettingsPanel extends StatelessWidget {
  const _ScreenSettingsPanel({
    required this.settings,
    required this.busy,
    required this.onReload,
    required this.onChanged,
    required this.onSave,
  });

  final DeviceScreenSettings? settings;
  final bool busy;
  final VoidCallback onReload;
  final ValueChanged<DeviceScreenSettings> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final value = settings;
    if (value == null) {
      return FeatureStateCard(
        message: busy ? '正在读取手表设置' : '暂时未读取到屏幕设置',
        detail: '请保持手表靠近手机后重试。',
        icon: Icons.brightness_6_outlined,
        actionLabel: busy ? null : '重新读取',
        onAction: busy ? null : onReload,
      );
    }
    final maximum = value.maximumBrightness.clamp(1, 10);
    final current = value.brightness.clamp(1, maximum);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (value.brightnessSupported) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('自动调节亮度'),
                subtitle: const Text('由手表根据时间自动调节'),
                value: value.automaticBrightness,
                onChanged: busy
                    ? null
                    : (enabled) => onChanged(
                        value.copyWith(automaticBrightness: enabled),
                      ),
              ),
              const Divider(),
              const SizedBox(height: 12),
              Text('屏幕亮度  $current / $maximum'),
              Slider(
                value: current.toDouble(),
                min: 1,
                max: maximum.toDouble(),
                divisions: maximum > 1 ? maximum - 1 : 1,
                onChanged: busy
                    ? null
                    : (next) => onChanged(
                        value.copyWith(
                          brightness: next.round(),
                          automaticBrightness: false,
                        ),
                      ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SaydianColors.brandGoldSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '当前手表固件未开放 APP 亮度调节，请在手表的屏幕设置中调整亮度。',
                        style: TextStyle(fontSize: 14, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (value.durationSeconds != null &&
                value.minimumDurationSeconds != null &&
                value.maximumDurationSeconds != null) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text('亮屏时长  ${value.durationSeconds} 秒'),
              Slider(
                value: value.durationSeconds!.toDouble().clamp(
                  value.minimumDurationSeconds!.toDouble(),
                  value.maximumDurationSeconds!.toDouble(),
                ),
                min: value.minimumDurationSeconds!.toDouble(),
                max: value.maximumDurationSeconds!.toDouble(),
                divisions:
                    (value.maximumDurationSeconds! -
                            value.minimumDurationSeconds!) >
                        0
                    ? value.maximumDurationSeconds! -
                          value.minimumDurationSeconds!
                    : 1,
                onChanged: busy
                    ? null
                    : (next) => onChanged(
                        value.copyWith(durationSeconds: next.round()),
                      ),
              ),
            ],
            if (value.raiseToWakeSupported) ...[
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('抬腕亮屏'),
                subtitle: const Text('抬起手腕时自动点亮屏幕'),
                value: value.raiseToWakeEnabled,
                onChanged: busy
                    ? null
                    : (enabled) => onChanged(
                        value.copyWith(raiseToWakeEnabled: enabled),
                      ),
              ),
              if (value.raiseToWakeCustomTimeSupported) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('生效时间'),
                  subtitle: Text(
                    '${_timeLabel(value.raiseToWakeStartMinutes)}–${_timeLabel(value.raiseToWakeEndMinutes)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: busy
                      ? null
                      : () => _pickRaiseTime(context, value, onChanged),
                ),
                Text('抬腕灵敏度  ${value.raiseToWakeSensitivity} / 10'),
                Slider(
                  value: value.raiseToWakeSensitivity.toDouble().clamp(1, 10),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: busy
                      ? null
                      : (next) => onChanged(
                          value.copyWith(raiseToWakeSensitivity: next.round()),
                        ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onSave,
                child: const Text('保存设置'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRaiseTime(
    BuildContext context,
    DeviceScreenSettings value,
    ValueChanged<DeviceScreenSettings> onChanged,
  ) async {
    final start = await showTimePicker(
      context: context,
      helpText: '选择开始时间',
      initialTime: TimeOfDay(
        hour: value.raiseToWakeStartMinutes ~/ 60,
        minute: value.raiseToWakeStartMinutes % 60,
      ),
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: '选择结束时间',
      initialTime: TimeOfDay(
        hour: value.raiseToWakeEndMinutes ~/ 60,
        minute: value.raiseToWakeEndMinutes % 60,
      ),
    );
    if (end == null) return;
    onChanged(
      value.copyWith(
        raiseToWakeStartMinutes: start.hour * 60 + start.minute,
        raiseToWakeEndMinutes: end.hour * 60 + end.minute,
      ),
    );
  }

  String _timeLabel(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({this.controller, super.key});

  final AppController? controller;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _content = TextEditingController();
  final _contact = TextEditingController();
  String _category = '功能建议';
  String? _result;
  bool _submitting = false;

  @override
  void dispose() {
    _content.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_content.text.trim().length < 5) {
      setState(() => _result = '请至少填写 5 个字的问题说明');
      return;
    }
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _result = '此功能暂时无法使用，请稍后再试');
      return;
    }
    setState(() {
      _submitting = true;
      _result = null;
    });
    final success = await controller.submitFeedback(
      category: _category,
      content: _content.text,
      contact: _contact.text,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = success
          ? '反馈已提交，感谢你的建议'
          : controller.errorMessage ?? '反馈提交失败，请稍后重试';
      if (success) _content.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '问题反馈',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: '问题类型'),
            items: const [
              DropdownMenuItem(value: '功能建议', child: Text('功能建议')),
              DropdownMenuItem(value: '设备连接', child: Text('设备连接')),
              DropdownMenuItem(value: '数据问题', child: Text('数据问题')),
              DropdownMenuItem(value: '商城订单', child: Text('商城订单')),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('feedback-content'),
            controller: _content,
            minLines: 5,
            maxLines: 8,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: '问题说明',
              hintText: '请描述遇到的问题和出现步骤',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contact,
            decoration: const InputDecoration(
              labelText: '联系方式（选填）',
              hintText: '手机号或邮箱',
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            FeatureStateCard(message: _result!, icon: Icons.info_outline),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '正在提交…' : '提交反馈'),
          ),
          const SizedBox(height: 28),
          Text(
            '常见问题',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Card(
            child: Column(
              children: [
                ExpansionTile(
                  title: Text('如何连接手表？'),
                  childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [Text('打开“设备”页并选择添加设备。搜索时让手表保持亮屏、靠近手机，并在手表端确认配对。')],
                ),
                Divider(height: 1),
                ExpansionTile(
                  title: Text('为什么健康数据暂时为空？'),
                  childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text('请确认设备已连接并完成同步。设备不支持的项目不会开放入口；新测量数据同步后才会显示趋势。'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerServicePage extends StatelessWidget {
  const CustomerServicePage({super.key});

  static const _phone = '4006386738';
  static const _officialAccount = '赛电';

  Future<void> _call(BuildContext context) async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: _phone));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开拨号界面，请手动拨打 $_phone')));
    }
  }

  Future<void> _copyAccount(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _officialAccount));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('公众号“$_officialAccount”已复制，可前往微信搜索添加')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('联系客服')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.phone_outlined),
                  ),
                  title: const Text('联系电话'),
                  subtitle: const Text(_phone),
                  trailing: FilledButton.tonal(
                    onPressed: () => _call(context),
                    child: const Text('拨打电话'),
                  ),
                ),
                const Divider(indent: 72, height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.wechat_rounded),
                  ),
                  title: const Text('公众号'),
                  subtitle: const Text(_officialAccount),
                  trailing: FilledButton.tonal(
                    onPressed: () => _copyAccount(context),
                    child: const Text('添加客服'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const FeatureStateCard(
            message: '联系前请准备设备型号和问题发生时间',
            detail: '请勿向非官方账号发送验证码、密码或完整健康记录。',
            icon: Icons.privacy_tip_outlined,
          ),
        ],
      ),
    );
  }
}

class AboutSaydianPage extends StatefulWidget {
  const AboutSaydianPage({
    required this.controller,
    this.updateGateController,
    this.packageInfoLoader,
    super.key,
  });

  final AppController controller;
  final AppUpdateGateController? updateGateController;
  final Future<PackageInfo> Function()? packageInfoLoader;

  @override
  State<AboutSaydianPage> createState() => _AboutSaydianPageState();
}

class _AboutSaydianPageState extends State<AboutSaydianPage> {
  String _version = '--';
  String _build = '--';
  String _introduction = '记录日常健康趋势，连接家人与设备，让健康管理更简单。';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final package =
          await (widget.packageInfoLoader ?? PackageInfo.fromPlatform)();
      if (mounted) {
        setState(() {
          _version = package.version;
          _build = package.buildNumber;
        });
      }
    } catch (_) {
      // Version remains explicitly unavailable instead of being hard-coded.
    }
    final article = await widget.controller.loadSingleArticle(14);
    final raw = '${article['content'] ?? article['description'] ?? ''}';
    final plain = _aboutPlainText(raw);
    if (mounted && _isUsefulAboutIntroduction(plain)) {
      setState(() => _introduction = plain);
    }
  }

  void _openLegal(int id, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SingleArticlePage(
          controller: widget.controller,
          articleId: id,
          fallbackTitle: title,
        ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final gate =
          widget.updateGateController ?? AppUpdateGateScope.maybeOf(context);
      if (gate == null) {
        throw StateError('missing root update gate');
      }
      await gate.checkNow();
    } catch (_) {
      if (mounted) _message('暂时无法检查更新，请稍后再试');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于我们')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 38, 24, 24),
        children: [
          const Center(child: SaydianBrandLockup(width: 176)),
          const SizedBox(height: 26),
          const Text(
            '赛电健康',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _introduction,
            textAlign: TextAlign.center,
            style: TextStyle(color: SaydianColors.muted, height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            _build == '--' ? 'V$_version' : 'V$_version ($_build)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SaydianColors.muted),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('隐私政策'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openLegal(3, '隐私政策'),
                ),
                const Divider(indent: 56, height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('用户协议'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openLegal(2, '用户协议'),
                ),
                const Divider(indent: 56, height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_alt_rounded),
                  title: const Text('检查更新'),
                  subtitle: const Text('检查是否有新版本'),
                  trailing: _checking
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _checking ? null : _checkUpdate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const FeatureStateCard(
            message: '健康数据说明',
            detail: '测量结果仅供健康管理参考，不用于诊断或治疗。',
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _SingleArticlePage extends StatefulWidget {
  const _SingleArticlePage({
    required this.controller,
    required this.articleId,
    required this.fallbackTitle,
  });

  final AppController controller;
  final int articleId;
  final String fallbackTitle;

  @override
  State<_SingleArticlePage> createState() => _SingleArticlePageState();
}

class _SingleArticlePageState extends State<_SingleArticlePage> {
  Map<String, Object?>? _article;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await widget.controller.loadSingleArticle(widget.articleId);
    if (mounted) setState(() => _article = value);
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    final title = '${article?['title'] ?? widget.fallbackTitle}';
    final content = _aboutPlainText(
      '${article?['content'] ?? article?['description'] ?? ''}',
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: article == null
          ? const Center(child: CircularProgressIndicator())
          : content.isEmpty
          ? const Center(child: Text('内容暂时无法加载'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [Text(content, style: const TextStyle(height: 1.75))],
            ),
    );
  }
}

String _aboutPlainText(String raw) => raw
    .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
    .replaceAll(
      RegExp(r'</\s*(p|li|h[1-6]|div)\s*>', caseSensitive: false),
      '\n',
    )
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
    .trim();

bool _isUsefulAboutIntroduction(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  return compact.runes.length >= 8;
}

class SecurityCenterPage extends StatelessWidget {
  const SecurityCenterPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号与安全')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PasswordRecoveryPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('重置密码'),
                  subtitle: const Text('验证手机号后重新设置'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
                const ListTile(
                  leading: Icon(Icons.phonelink_lock_outlined),
                  title: Text('登录保护'),
                  subtitle: Text('此功能暂时无法使用，请稍后再试'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShoppingCartPage extends StatelessWidget {
  const ShoppingCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('购物车')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: FeatureStateCard(
          message: '购物车暂时无法使用',
          detail: '你可以从商品详情页直接选择规格并购买。',
          icon: Icons.shopping_cart_outlined,
        ),
      ),
    );
  }
}

class AfterSalesPage extends StatelessWidget {
  const AfterSalesPage({this.orderNumber, super.key});

  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('申请售后')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FeatureStateCard(
          message: '此功能暂时无法使用，请稍后再试',
          detail: orderNumber == null
              ? '售后服务开通后，可从订单详情提交申请。'
              : '订单 $orderNumber 的售后服务开通后，可在这里提交申请。',
          icon: Icons.support_agent_rounded,
        ),
      ),
    );
  }
}

class FeatureStateCard extends StatelessWidget {
  const FeatureStateCard({
    required this.message,
    required this.icon,
    this.detail,
    this.color = SaydianColors.blue,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? detail;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SaydianColors.muted, height: 1.5),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CityInputDialog extends StatefulWidget {
  const _CityInputDialog();

  @override
  State<_CityInputDialog> createState() => _CityInputDialogState();
}

class _CityInputDialogState extends State<_CityInputDialog> {
  final _city = TextEditingController();

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _city.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择城市'),
    content: TextField(
      controller: _city,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: '城市名称', hintText: '例如：深圳'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('确定')),
    ],
  );
}

class _ContactEditorDialog extends StatefulWidget {
  const _ContactEditorDialog();

  @override
  State<_ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<_ContactEditorDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    Navigator.pop(context, <String, Object?>{
      'operation': 'add',
      'name': name,
      'phone': phone,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加联系人'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(labelText: '姓名'),
        ),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: '电话号码'),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}

IconData _deviceFeatureIcon(DeviceFeature feature) => switch (feature) {
  DeviceFeature.watchFaces => Icons.watch_later_outlined,
  DeviceFeature.photoWatchFace => Icons.photo_outlined,
  DeviceFeature.findWatch => Icons.notifications_active_outlined,
  DeviceFeature.camera => Icons.camera_alt_outlined,
  DeviceFeature.phoneCalls => Icons.call_outlined,
  DeviceFeature.contacts => Icons.contacts_outlined,
  DeviceFeature.notifications => Icons.notifications_none_rounded,
  DeviceFeature.alarms => Icons.alarm_rounded,
  DeviceFeature.weather => Icons.cloud_outlined,
  DeviceFeature.worldClock => Icons.public_rounded,
  DeviceFeature.healthReminders => Icons.event_available_outlined,
  DeviceFeature.healthMonitoring => Icons.monitor_heart_outlined,
  DeviceFeature.healthAssessment => Icons.assignment_turned_in_outlined,
  DeviceFeature.screenDisplay => Icons.brightness_6_outlined,
};

String _deviceFeatureDescription(DeviceFeature feature) => switch (feature) {
  DeviceFeature.watchFaces => '选择并管理手表表盘',
  DeviceFeature.photoWatchFace => '用自己的照片制作表盘',
  DeviceFeature.findWatch => '让附近的手表响铃或振动',
  DeviceFeature.camera => '使用手表控制手机拍照',
  DeviceFeature.phoneCalls => '管理手表通话相关设置',
  DeviceFeature.contacts => '管理手表中的常用联系人',
  DeviceFeature.notifications => '选择需要在手表上提醒的消息',
  DeviceFeature.alarms => '管理手表闹钟和重复日期',
  DeviceFeature.weather => '把所在城市天气同步到手表',
  DeviceFeature.worldClock => '在手表上查看其他城市时间',
  DeviceFeature.healthReminders => '设置久坐、饮水和日常提醒',
  DeviceFeature.healthMonitoring => '设置自动检测和健康提醒',
  DeviceFeature.healthAssessment => '查看手表支持的辅助评估',
  DeviceFeature.screenDisplay => '调节亮度和亮屏方式',
};
