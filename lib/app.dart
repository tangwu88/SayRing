import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:country_picker/country_picker.dart';

import 'l10n/generated/app_localizations.dart';
import 'l10n/global_locale_controller.dart';

import 'services/app_controller.dart';
import 'services/notification_route_service.dart';
import 'services/app_update_service.dart';
import 'ui/app_theme.dart';
import 'ui/app_update_gate_scope.dart';
import 'ui/pages.dart';
import 'ui/prototype_pages.dart';
import 'ui/global_code_login_page.dart';
import 'ui/review_demo_page.dart';

class DismissKeyboardOnBackgroundTap extends StatefulWidget {
  const DismissKeyboardOnBackgroundTap({required this.child, super.key});

  final Widget child;

  @override
  State<DismissKeyboardOnBackgroundTap> createState() =>
      _DismissKeyboardOnBackgroundTapState();
}

class _DismissKeyboardOnBackgroundTapState
    extends State<DismissKeyboardOnBackgroundTap> {
  final Map<int, _KeyboardDismissPointer> _pointers = {};

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton == 0) return;
    final focus = FocusManager.instance.primaryFocus;
    if (!_isEditableFocus(focus)) return;
    _pointers[event.pointer] = _KeyboardDismissPointer(
      startPosition: event.position,
      focus: focus!,
      startedInsideFocusedEditable: _containsGlobalPosition(
        focus,
        event.position,
      ),
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final pointer = _pointers[event.pointer];
    if (pointer == null || pointer.moved) return;
    if ((event.position - pointer.startPosition).distanceSquared >
        kTouchSlop * kTouchSlop) {
      pointer.moved = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final pointer = _pointers.remove(event.pointer);
    if (pointer == null ||
        pointer.moved ||
        pointer.startedInsideFocusedEditable) {
      return;
    }

    // Listener observes without joining the gesture arena, so child buttons,
    // links and fields still receive their normal tap. Defer the focus check
    // until their handlers have run: a newly focused EditableText must keep
    // focus, while a non-editable tap dismisses the original keyboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentFocus = FocusManager.instance.primaryFocus;
      if (identical(currentFocus, pointer.focus) && currentFocus!.hasFocus) {
        currentFocus.unfocus();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
  }

  bool _isEditableFocus(FocusNode? focus) {
    final context = focus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _containsGlobalPosition(FocusNode focus, Offset globalPosition) {
    final renderObject = focus.context?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return false;
    }
    final localPosition = renderObject.globalToLocal(globalPosition);
    return (Offset.zero & renderObject.size).contains(localPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const Key('global-keyboard-dismiss'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}

class _KeyboardDismissPointer {
  _KeyboardDismissPointer({
    required this.startPosition,
    required this.focus,
    required this.startedInsideFocusedEditable,
  });

  final Offset startPosition;
  final FocusNode focus;
  final bool startedInsideFocusedEditable;
  bool moved = false;
}

class SaydianApp extends StatefulWidget {
  const SaydianApp({
    required this.controller,
    this.updateService,
    this.updateCheckStore,
    this.updateGateController,
    this.localeController,
    super.key,
  });

  final AppController controller;
  final AppUpdateService? updateService;
  final AppUpdateCheckStore? updateCheckStore;
  final AppUpdateGateController? updateGateController;
  final GlobalLocaleController? localeController;

  @override
  State<SaydianApp> createState() => _SaydianAppState();
}

class _SaydianAppState extends State<SaydianApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppUpdateService _updateService;
  late final AppUpdateCoordinator _updateCoordinator;
  late final AndroidApkUpdateInstaller _apkInstaller;
  late AppUpdateGateController _updateGateController;
  late final AppUpdateManualCheck _manualUpdateCheck = _checkUpdateNow;
  AppUpdateInfo? _requiredUpdate;
  bool _requiredUpdateGateResolved = false;
  bool _updateCheckRunning = false;
  bool _notificationRouteRunning = false;
  bool _permissionPromptRunning = false;
  late final GlobalLocaleController _localeController;
  late final bool _ownsLocaleController;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ownsLocaleController =
        widget.localeController == null && !controller.isGlobalEdition;
    _localeController =
        widget.localeController ??
        (controller.isGlobalEdition
            ? GlobalLocaleController.instance
            : GlobalLocaleController(
                initialLocale: const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hans',
                ),
              ));
    if (controller.isGlobalEdition || widget.localeController != null) {
      unawaited(_localeController.load());
    }
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_handleControllerState);
    _updateService =
        widget.updateService ??
        (controller.isGlobalEdition
            ? GlobalAppUpdateService()
            : AppUpdateService());
    _updateCoordinator = AppUpdateCoordinator(
      _updateService,
      store: widget.updateCheckStore,
    );
    _apkInstaller = AndroidApkUpdateInstaller.global();
    _updateGateController =
        widget.updateGateController ?? AppUpdateGateController();
    _updateGateController.attach(_manualUpdateCheck);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreRequiredUpdateGate());
      _handleControllerState();
    });
  }

  @override
  void didUpdateWidget(covariant SaydianApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updateGateController == widget.updateGateController) return;
    _updateGateController.detach(_manualUpdateCheck);
    _updateGateController =
        widget.updateGateController ?? AppUpdateGateController();
    _updateGateController.attach(_manualUpdateCheck);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.handleAppResumed());
      unawaited(_checkUpdateIfDue());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      controller.setAppForeground(false);
    }
  }

  void _handleControllerState() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openPendingNotificationRoute());
      unawaited(_showNotificationPermissionExplanation());
    });
  }

  Future<void> _openPendingNotificationRoute() async {
    if (kDebugMode && controller.pendingNotificationRoute != null) {
      debugPrint(
        '[push-navigation] queued=true running=$_notificationRouteRunning '
        'gateResolved=$_requiredUpdateGateResolved '
        'updateRequired=${_requiredUpdate != null} '
        'authenticated=${controller.isAuthenticated}',
      );
    }
    if (_notificationRouteRunning ||
        !_requiredUpdateGateResolved ||
        _requiredUpdate != null ||
        !controller.isAuthenticated) {
      return;
    }
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final intent = controller.consumePendingNotificationRoute();
    if (intent == null) return;
    _notificationRouteRunning = true;
    if (kDebugMode) {
      debugPrint(
        '[push-navigation] consumed=true target=${intent.target.name}',
      );
    }
    try {
      final page = switch (intent.target) {
        NotificationRouteTarget.careInvitationReview => CareInvitationsPage(
          controller: controller,
          targetInvitationId: intent.entityId,
        ),
        NotificationRouteTarget.healthWarningHistory => HealthWarningPage(
          controller: controller,
        ),
        NotificationRouteTarget.notificationInbox => NotificationsPage(
          controller: controller,
        ),
      };
      await navigator.push(MaterialPageRoute<void>(builder: (_) => page));
    } finally {
      _notificationRouteRunning = false;
    }
  }

  Future<void> _showNotificationPermissionExplanation() async {
    if (_permissionPromptRunning ||
        !_requiredUpdateGateResolved ||
        _requiredUpdate != null ||
        !controller.isAuthenticated ||
        !controller.notificationServiceConfigured ||
        controller.notificationPermissionEnabled) {
      return;
    }
    _permissionPromptRunning = true;
    try {
      if (!await controller.shouldExplainNotificationPermission()) return;
      if (!mounted || !_requiredUpdateGateResolved || _requiredUpdate != null) {
        return;
      }
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final allowed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.l10n.enableNotifications),
          content: Text(dialogContext.l10n.notificationExplanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.l10n.allowNotifications),
            ),
          ],
        ),
      );
      await controller.markNotificationPermissionExplanationShown();
      if (allowed == true) await controller.requestNotificationPermission();
    } finally {
      _permissionPromptRunning = false;
    }
  }

  Future<void> _checkUpdateIfDue() async {
    if (_updateCheckRunning || !mounted || !_requiredUpdateGateResolved) return;
    final wasRequired = _requiredUpdate != null;
    _updateCheckRunning = true;
    try {
      final info = await _updateCoordinator.checkIfDue();
      if (!mounted) return;
      if (info == null) {
        if (wasRequired) _leaveRequiredUpdate();
        return;
      }
      if (info.forceUpdate) {
        _enterRequiredUpdate(info);
        return;
      }
      if (wasRequired) _leaveRequiredUpdate();
      await _showOptionalUpdate(info);
    } on AppUpdatePersistenceException catch (error) {
      if (mounted) _enterRequiredUpdate(error.info);
    } on AppUpdateException {
      // A failed or unavailable manifest never creates a mandatory update.
    } finally {
      _updateCheckRunning = false;
    }
  }

  Future<void> _checkUpdateNow() async {
    if (_updateCheckRunning || !mounted || !_requiredUpdateGateResolved) return;
    _updateCheckRunning = true;
    try {
      final info = await _updateCoordinator.checkNow();
      if (!mounted) return;
      if (info.forceUpdate) {
        _enterRequiredUpdate(info);
      } else if (info.hasUpdate) {
        if (_requiredUpdate != null) _leaveRequiredUpdate();
        await _showOptionalUpdate(info);
      } else {
        if (_requiredUpdate != null) _leaveRequiredUpdate();
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.latestVersion(info.currentVersion)),
            ),
          );
        }
      }
    } on AppUpdatePersistenceException catch (error) {
      if (mounted) _enterRequiredUpdate(error.info);
    } on AppUpdateException catch (error) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      _updateCheckRunning = false;
    }
  }

  Future<void> _showOptionalUpdate(AppUpdateInfo info) async {
    // Locale delegates may still be mounting the first Navigator when a fast
    // manifest response arrives. Do not silently discard the optional update.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_requiredUpdateGateResolved || _requiredUpdate != null) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          info.title.isNotEmpty ? info.title : dialogContext.l10n.updateReady,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dialogContext.l10n.versionBuild(
                info.currentVersion,
                info.currentBuild,
              ),
            ),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(info.releaseNotes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.notNow),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              final pageContext = _navigatorKey.currentContext;
              if (pageContext == null) return;
              Navigator.of(pageContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => _UpdateActionPage(
                    info: info,
                    service: _updateService,
                    installer: _apkInstaller,
                    required: false,
                  ),
                ),
              );
            },
            child: Text(dialogContext.l10n.updateNow),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreRequiredUpdateGate() async {
    try {
      final info = await _updateCoordinator.restoreRequiredUpdate();
      if (!mounted) return;
      setState(() {
        _requiredUpdate = info;
        _requiredUpdateGateResolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _requiredUpdateGateResolved = true);
    }
    if (_requiredUpdate == null) {
      _handleControllerState();
    }
    // A persisted gate is shown immediately, then refreshed without the daily
    // throttle so a corrected server manifest can safely release the user.
    unawaited(_checkUpdateIfDue());
  }

  void _enterRequiredUpdate(AppUpdateInfo info) {
    if (!mounted) return;
    setState(() => _requiredUpdate = info);
    // Updating MaterialApp.home rebuilds the first route but does not remove
    // pages or dialogs that have already been pushed above it. Collapse the
    // stack so the mandatory update page cannot be bypassed by a notification
    // deep link or a page that was open while the network check completed.
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _leaveRequiredUpdate() {
    if (!mounted || _requiredUpdate == null) return;
    setState(() => _requiredUpdate = null);
    _handleControllerState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_handleControllerState);
    // The controller is injected and may outlive this widget, but foreground
    // polling must not outlive the app shell that owns the lifecycle observer.
    controller.setAppForeground(false);
    _updateGateController.detach(_manualUpdateCheck);
    if (_ownsLocaleController) _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlobalLocaleScope(
      controller: _localeController,
      child: ListenableBuilder(
        listenable: _localeController,
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          title: controller.isGlobalEdition ? 'Say Ring' : 'Saydian赛电',
          debugShowCheckedModeBanner: false,
          theme: buildSaydianTheme(),
          locale: _localeController.locale,
          supportedLocales: GlobalLocaleController.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            CountryLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => DismissKeyboardOnBackgroundTap(
            child: AppUpdateGateScope(
              controller: _updateGateController,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final alert = controller.activeHealthWarningAlert;
                  final careAlert = controller.activeCareInvitationAlert;
                  return Stack(
                    children: [
                      child ?? const SizedBox.shrink(),
                      if (alert != null)
                        Positioned(
                          left: 12,
                          right: 12,
                          top: MediaQuery.paddingOf(context).top + 10,
                          child: Material(
                            key: const Key('global-health-warning'),
                            elevation: 10,
                            color: const Color(0xFFFFF1EE),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      color: SaydianColors.danger,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          alert.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: SaydianColors.danger,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(alert.message),
                                        const SizedBox(height: 3),
                                        Text(
                                          context.l10n.healthSafetyAdvice,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: context.l10n.dismissHealthAlert,
                                    child: IconButton(
                                      key: const Key('dismiss-health-warning'),
                                      onPressed:
                                          controller.dismissHealthWarningAlert,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (careAlert != null &&
                          controller.isAuthenticated &&
                          _requiredUpdateGateResolved &&
                          _requiredUpdate == null)
                        Positioned(
                          left: 12,
                          right: 12,
                          top: MediaQuery.paddingOf(context).top + 10,
                          child: Material(
                            key: const Key('global-care-invitation'),
                            elevation: 10,
                            color: const Color(0xFFFFF1EE),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.favorite_border_rounded,
                                    color: SaydianColors.danger,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.l10n.newCareRequest,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    key: const Key('open-care-invitation'),
                                    onPressed:
                                        controller.openCareInvitationAlert,
                                    child: Text(context.l10n.view),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: context.l10n.dismissCareAlert,
                                    child: IconButton(
                                      key: const Key('dismiss-care-invitation'),
                                      onPressed:
                                          controller.dismissCareInvitationAlert,
                                      icon: const Icon(Icons.close_rounded),
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
            ),
          ),
          home: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (!_requiredUpdateGateResolved) {
                return const _BootPage();
              }
              if (_requiredUpdate case final info?) {
                return _UpdateActionPage(
                  info: info,
                  service: _updateService,
                  installer: _apkInstaller,
                  required: true,
                );
              }
              if (controller.isBooting) {
                return const _BootPage();
              }
              if (!controller.isAuthenticated &&
                  !controller.isPreviewMode &&
                  !controller.isLocalMode) {
                return controller.isGlobalEdition
                    ? GlobalCodeLoginPage(controller: controller)
                    : LoginPage(controller: controller);
              }
              if (controller.isPreviewMode) {
                return ReviewDemoPage(onExit: controller.exitPreview);
              }
              return AppShell(controller: controller);
            },
          ),
        ),
      ),
    );
  }
}

class _UpdateActionPage extends StatefulWidget {
  const _UpdateActionPage({
    required this.info,
    required this.service,
    required this.installer,
    required this.required,
  });

  final AppUpdateInfo info;
  final AppUpdateService service;
  final AndroidApkUpdateInstaller installer;
  final bool required;

  @override
  State<_UpdateActionPage> createState() => _UpdateActionPageState();
}

class _UpdateActionPageState extends State<_UpdateActionPage> {
  bool _busy = false;
  double _progress = 0;
  String? _error;

  Future<void> _update() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      if (widget.service.opensProductDownloadPage) {
        await widget.service.openDestination(widget.info);
      } else if (widget.info.destinationType ==
          AppUpdateDestinationType.androidApk) {
        await widget.installer.downloadAndInstall(
          widget.info,
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
        );
      } else {
        await widget.service.openDestination(widget.info);
      }
    } on AppUpdateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      appBar: widget.required
          ? null
          : AppBar(title: Text(context.l10n.onlineUpdate)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    widget.required
                        ? Icons.system_update_alt_rounded
                        : Icons.new_releases_outlined,
                    size: 64,
                    color: SaydianColors.techBlue,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.info.title.isNotEmpty
                        ? widget.info.title
                        : widget.required
                        ? context.l10n.updateRequired
                        : context.l10n.updateReady,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.versionBuild(
                      widget.info.latestVersion,
                      widget.info.latestBuild,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.info.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(widget.info.releaseNotes),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: _progress > 0 && _progress < 1 ? _progress : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _progress < 1
                          ? context.l10n.preparingUpdate
                          : context.l10n.openingUpdate,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SaydianColors.danger),
                    ),
                    if (_error!.contains('未知来源'))
                      TextButton(
                        onPressed: widget.installer.openUnknownSourcesSettings,
                        child: Text(context.l10n.goToSettings),
                      ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _update,
                    child: Text(
                      widget.service.opensProductDownloadPage
                          ? '前往 APP 下载页'
                          : widget.info.destinationType ==
                                AppUpdateDestinationType.appStore
                          ? context.l10n.updateAppStore
                          : widget.info.destinationType ==
                                AppUpdateDestinationType.testFlight
                          ? context.l10n.openTestFlight
                          : widget.info.destinationType ==
                                AppUpdateDestinationType.androidStore
                          ? context.l10n.updateStore
                          : context.l10n.downloadAndInstall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return widget.required ? PopScope(canPop: false, child: body) : body;
  }
}

class _BootPage extends StatelessWidget {
  const _BootPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BootLogo(),
              const SizedBox(height: 26),
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: 14),
              Text(context.l10n.gettingReady),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootLogo extends StatelessWidget {
  const _BootLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/logo_en.jpg',
      width: 320,
      fit: BoxFit.contain,
      semanticLabel: '赛电',
    );
  }
}
