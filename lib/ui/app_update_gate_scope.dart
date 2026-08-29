import 'package:flutter/widgets.dart';

import '../services/app_update_service.dart';

typedef AppUpdateManualCheck = Future<void> Function();

/// Routes every manual update check through the root mandatory-update gate.
class AppUpdateGateController {
  AppUpdateManualCheck? _handler;

  bool get isAttached => _handler != null;

  void attach(AppUpdateManualCheck handler) => _handler = handler;

  void detach(AppUpdateManualCheck handler) {
    if (identical(_handler, handler)) _handler = null;
  }

  Future<void> checkNow() async {
    final handler = _handler;
    if (handler == null) {
      throw const AppUpdateException('在线更新服务暂时不可用');
    }
    await handler();
  }
}

class AppUpdateGateScope extends InheritedWidget {
  const AppUpdateGateScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final AppUpdateGateController controller;

  static AppUpdateGateController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppUpdateGateScope>()
      ?.controller;

  @override
  bool updateShouldNotify(AppUpdateGateScope oldWidget) =>
      oldWidget.controller != controller;
}
