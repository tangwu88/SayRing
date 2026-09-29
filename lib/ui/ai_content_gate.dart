import 'package:flutter/material.dart';

import '../services/app_controller.dart';

/// Keeps already-open pages and their dialogs in step with the product setting.
class AiContentGate extends StatefulWidget {
  const AiContentGate({
    required this.controller,
    required this.builder,
    super.key,
  });

  final AppController controller;
  final WidgetBuilder builder;

  @override
  State<AiContentGate> createState() => _AiContentGateState();
}

class _AiContentGateState extends State<AiContentGate> {
  bool _closeScheduled = false;

  void _closeHiddenRoute() {
    if (_closeScheduled) return;
    _closeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeScheduled = false;
      if (!mounted || !widget.controller.hideAiContent) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isActive || route.isFirst) return;
      final navigator = Navigator.of(context);
      navigator.popUntil(
        (candidate) => candidate == route || candidate.isFirst,
      );
      if (mounted && route.isCurrent && navigator.canPop()) navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      if (!widget.controller.hideAiContent) return widget.builder(context);
      _closeHiddenRoute();
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('此功能暂未开放')),
      );
    },
  );
}
