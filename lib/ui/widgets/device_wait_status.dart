import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Shows only evidence from the current connection/read operation. The orbit
/// indicates work, never a timer-derived percentage or estimated completion.
class DeviceWaitStatus extends StatelessWidget {
  const DeviceWaitStatus({
    super.key,
    required this.connected,
    this.receivedRecords = 0,
    this.progress,
    this.connectionMessage = '正在重新连接',
  });

  final bool connected;
  final int receivedRecords;
  final double? progress;
  final String connectionMessage;

  @override
  Widget build(BuildContext context) {
    final value = progress;
    final confirmedProgress =
        connected && value != null && value.isFinite && value > 0 && value <= 1
        ? value
        : null;
    final title = connected ? '正在同步戒指数据' : connectionMessage;
    final detail = !connected
        ? '保持蓝牙开启，将戒指放在手机附近'
        : receivedRecords > 0
        ? '已接收 $receivedRecords 条记录'
        : '正在读取活动与睡眠记录';
    return Semantics(
      liveRegion: true,
      label:
          '$title，$detail'
          '${confirmedProgress == null ? '' : '，${(confirmedProgress * 100).round()}%'}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _WaitingOrbit(connected: connected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: SaydianColors.techBlue,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (confirmedProgress != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              key: const Key('device-confirmed-sync-progress'),
                              value: confirmedProgress,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(3),
                              color: SaydianColors.techBlue,
                              backgroundColor: SaydianColors.line,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(confirmedProgress * 100).round()}%',
                            style: const TextStyle(
                              color: SaydianColors.techBlue,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (connected) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '可先浏览其他页面',
                        style: TextStyle(
                          color: SaydianColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingOrbit extends StatefulWidget {
  const _WaitingOrbit({required this.connected});

  final bool connected;

  @override
  State<_WaitingOrbit> createState() => _WaitingOrbitState();
}

class _WaitingOrbitState extends State<_WaitingOrbit>
    with SingleTickerProviderStateMixin {
  late final _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _rotation.stop();
    } else if (!_rotation.isAnimating) {
      _rotation.repeat();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 36,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: SaydianColors.techBlue.withValues(alpha: 0.16),
              width: 2,
            ),
          ),
        ),
        Icon(
          widget.connected ? Icons.sync_rounded : Icons.bluetooth_rounded,
          size: 17,
          color: SaydianColors.techBlue,
        ),
        RotationTransition(
          key: const Key('device-wait-orbit'),
          turns: _rotation,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: SaydianColors.techBlue,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
