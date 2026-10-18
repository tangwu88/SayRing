import 'package:flutter/material.dart';
import '../domain/module_visibility.dart';
import '../services/app_controller.dart';
import 'wellness_release.dart';

/// Reuses the existing page; closed/expired grants immediately hide its body.
class ModuleContentGate extends StatefulWidget {
  const ModuleContentGate({
    required this.controller,
    required this.module,
    required this.builder,
    this.onOpened,
    this.onClosed,
    this.unavailableKey = const Key('module-unavailable'),
    super.key,
  });
  final AppController controller;
  final SayRingModule module;
  final WidgetBuilder builder;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;
  final Key unavailableKey;

  @override
  State<ModuleContentGate> createState() => _ModuleContentGateState();
}

class _ModuleContentGateState extends State<ModuleContentGate> {
  bool? _wasVisible;
  bool get _visible => widget.module == SayRingModule.healthLibrary
      ? widget.controller.healthLibraryVisible
      : widget.controller.mallVisible;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final visible = _visible;
      final previous = _wasVisible;
      _wasVisible = visible;
      if (previous != null && previous != visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _visible != visible) return;
          (visible ? widget.onOpened : widget.onClosed)?.call();
        });
      }
      // Preserve the existing closed destination for legacy, unconfigured
      // releases. Remote module grants only apply to the new iOS controller.
      if (!visible &&
          widget.module == SayRingModule.healthLibrary &&
          widget.controller.moduleVisibility == null) {
        return const WellnessReleaseUnavailablePage();
      }
      return visible
          ? widget.builder(context)
          : Scaffold(
              key: widget.unavailableKey,
              appBar: AppBar(),
              body: const Center(child: Text('此功能暂未开放')),
            );
    },
  );
}
