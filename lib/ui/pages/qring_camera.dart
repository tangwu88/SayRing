part of '../pages.dart';

/// QRing photo control is a ring HID mode, not CoolWear's in-App camera flow.
class QRingCameraPage extends StatefulWidget {
  const QRingCameraPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<QRingCameraPage> createState() => _QRingCameraPageState();
}

class _QRingCameraPageState extends State<QRingCameraPage> {
  Map<String, Object?>? _snapshot;
  String? _error;
  bool _busy = false;
  int _operation = 0;
  late (bool, String?, String?) _owner;

  bool get _supported =>
      widget.controller.connectedDevice?.sdkSource == WearableSdkSource.qring &&
      widget.controller.deviceCapabilityState == DeviceCapabilityState.ready &&
      widget.controller.capabilities?.features.contains(DeviceFeature.camera) ==
          true;

  @override
  void initState() {
    super.initState();
    _owner = healthUiOwnerKey(widget.controller);
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _read();
    });
  }

  void _onControllerChanged() {
    final owner = healthUiOwnerKey(widget.controller);
    if (_owner != owner || !_supported) {
      _operation++;
      _owner = owner;
      _snapshot = null;
      _error = null;
      _busy = false;
    }
    if (mounted) setState(() {});
  }

  bool _current(int operation) =>
      mounted && operation == _operation && _supported;

  bool _valid(Map<String, Object?> value) =>
      value['enabled'] is bool &&
      value['mode'] is int &&
      (value['mode']! as int) >= 0 &&
      (value['mode']! as int) <= 9 &&
      value['enabled'] == (value['mode'] == 5) &&
      value['touch'] is bool;

  Future<void> _read() async {
    if (!_supported || _busy) return;
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _snapshot = null;
      _error = null;
    });
    final value = await widget.controller.readDeviceFeature(
      DeviceFeature.camera,
    );
    if (!_current(operation)) return;
    setState(() {
      _busy = false;
      _snapshot = _valid(value) ? value : null;
      _error = _snapshot == null
          ? widget.controller.errorMessage ?? '拍照状态未确认，重试'
          : null;
    });
  }

  Future<void> _write(bool enabled) async {
    if (!_supported || _busy || _snapshot == null) return;
    final ownerOperation = _operation;
    final mode = _snapshot!['mode'];
    if (enabled && mode != 0 && mode != 5) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('切换为拍照控制？'),
          content: const Text('将替换戒指当前的控制模式。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('切换'),
            ),
          ],
        ),
      );
      if (confirmed != true || !_current(ownerOperation)) return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
      _snapshot = null;
    });
    final success = await widget.controller.writeDeviceFeature(
      DeviceFeature.camera,
      {'enabled': enabled, 'expectedMode': mode},
    );
    if (!_current(operation)) return;
    final value = success
        ? await widget.controller.readDeviceFeature(DeviceFeature.camera)
        : const <String, Object?>{};
    if (!_current(operation)) return;
    setState(() {
      _busy = false;
      _snapshot = _valid(value) && value['enabled'] == enabled ? value : null;
      _error = _snapshot == null
          ? widget.controller.errorMessage ?? '拍照状态未确认，重试'
          : null;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('遥控拍照')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('qring-camera-enabled'),
                title: const Text('拍照控制'),
                subtitle: Text(
                  !_supported
                      ? '请连接支持拍照的 QRing 戒指'
                      : _busy
                      ? '正在确认'
                      : _snapshot == null
                      ? '状态未知'
                      : _snapshot!['enabled'] == true
                      ? '已开启'
                      : '未开启',
                ),
                value: _snapshot?['enabled'] == true,
                onChanged: _supported && !_busy && _snapshot != null
                    ? _write
                    : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextButton.icon(
                key: const Key('qring-camera-refresh'),
                onPressed: _supported && !_busy ? _read : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新状态'),
              ),
            ],
          ),
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '使用说明\n\n'
              '1. 开启拍照控制。\n'
              '2. 如系统提示蓝牙配对，请完成配对。\n'
              '3. 打开手机相机，使用戒指支持的触摸或手势拍照。\n\n'
              '具体动作以设备说明为准；不拍照时可关闭此模式。',
            ),
          ),
        ),
      ],
    ),
  );
}
