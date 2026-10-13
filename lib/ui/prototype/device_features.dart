part of '../prototype_pages.dart';

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
  bool _cameraSuspending = false;
  bool _cameraPermissionRequesting = false;
  bool _cameraPermissionPermanentlyDenied = false;
  bool _galleryPermissionDenied = false;
  int _cameraGeneration = 0;
  late int _cameraRemoteStopSequence;
  String? _cameraOwner;
  late final CameraRemoteShutterGate _cameraShutterGate;
  XFile? _dialPhoto;
  int _dialTimePosition = 0;
  final DeviceWeatherService _weatherService = DeviceWeatherService();
  final DeviceWatchFaceMarketService _watchFaceMarketService =
      DeviceWatchFaceMarketService();
  bool _weatherRefreshing = false;
  String? _weatherMessage;
  bool _openingWatchFaceMarket = false;
  int _featureReadGeneration = 0;
  bool get _availableInRelease =>
      !widget.controller.isWellnessOnly ||
      !const {
        DeviceFeature.healthMonitoring,
        DeviceFeature.healthAssessment,
        DeviceFeature.healthReminders,
      }.contains(widget.feature);
  late String _featureContext;
  String get _currentFeatureContext =>
      '${widget.controller.session?.accountKey}|${widget.controller.isLocalMode}|${widget.controller.connectedDevice?.id}|${widget.controller.availabilityFor(widget.feature).isReady}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _featureContext = _currentFeatureContext;
    _cameraRemoteStopSequence = widget.controller.cameraRemoteStopSequence;
    _cameraShutterGate = CameraRemoteShutterGate(
      initialSequence: widget.controller.cameraShutterSequence,
    );
    widget.controller.addListener(_handleControllerEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_availableInRelease ||
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
    final context = _currentFeatureContext;
    if (context != _featureContext) {
      _featureContext = context;
      _featureReadGeneration++;
      _featureData = {};
      if (widget.feature == DeviceFeature.camera) {
        unawaited(_suspendCamera(message: '连接已改变，请重新打开相机'));
        return;
      }
      if ((widget.feature == DeviceFeature.gestureControl ||
              widget.feature == DeviceFeature.callReminder) &&
          widget.controller.availabilityFor(widget.feature).isReady) {
        unawaited(_loadFeature());
      }
    }
    if (widget.feature == DeviceFeature.findWatch &&
        !widget.controller.availabilityFor(widget.feature).isReady &&
        _finding) {
      _findResetTimer?.cancel();
      setState(() => _finding = false);
    }
    if (widget.feature == DeviceFeature.camera) {
      if (_cameraRemoteStopSequence !=
          widget.controller.cameraRemoteStopSequence) {
        _cameraRemoteStopSequence = widget.controller.cameraRemoteStopSequence;
        _cameraRemoteStarted = false;
        _cameraShutterGate.disarm(
          currentSequence: widget.controller.cameraShutterSequence,
        );
        setState(() => _cameraMessage = '遥控已停止，可点击手机快门');
      }
      final availability = widget.controller.availabilityFor(widget.feature);
      if (!availability.isReady) {
        _cameraShutterGate.disarm(
          currentSequence: widget.controller.cameraShutterSequence,
        );
        if (_camera != null || _cameraRemoteStarted || _cameraInitializing) {
          unawaited(_suspendCamera(message: '戒指已断开，请重新连接后使用'));
        }
        return;
      }
      if (_camera == null &&
          !_cameraInitializing &&
          !_cameraSuspending &&
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
    if (!_availableInRelease) return;
    final generation = ++_featureReadGeneration;
    final context = _currentFeatureContext;
    final value = await widget.controller.readDeviceFeature(widget.feature);
    if (mounted &&
        generation == _featureReadGeneration &&
        context == _currentFeatureContext &&
        (value.isNotEmpty ||
            widget.feature == DeviceFeature.gestureControl ||
            widget.feature == DeviceFeature.callReminder)) {
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
    final contextKey = _currentFeatureContext;
    if (widget.feature == DeviceFeature.gestureControl) {
      setState(() => _featureData = {});
    }
    final saved = await widget.controller.writeDeviceFeature(
      widget.feature,
      values,
    );
    if (!mounted || contextKey != _currentFeatureContext) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? successMessage
              : widget.controller.errorMessage ?? '保存失败，请稍后重试',
        ),
      ),
    );
    if (reload && (saved || widget.feature == DeviceFeature.gestureControl)) {
      await _loadFeature();
    }
    return saved;
  }

  Future<void> _initializeCamera() async {
    if (_cameraInitializing ||
        _cameraSuspending ||
        _cameraPermissionRequesting ||
        _camera != null) {
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
      _cameraOwner = _currentFeatureContext;
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
            ? '摇动戴戒指的手，或点击快门'
            : widget.controller.errorMessage ?? '戒指相机遥控暂时无法开启';
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
    if (_camera != null && !_cameraRemoteStarted) {
      await _suspendCamera(message: '正在重新开启相机遥控');
    }
    if (mounted) setState(() => _cameraMessage = null);
    await _initializeCamera();
  }

  Future<void> _suspendCamera({String message = '返回 App 后将重新打开相机'}) async {
    if (widget.feature != DeviceFeature.camera) return;
    if (_cameraSuspending) return;
    _cameraSuspending = true;
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
    _cameraSuspending = false;
    if (generation != _cameraGeneration) return;
  }

  Future<void> _resumeCamera() async {
    if (!mounted || widget.feature != DeviceFeature.camera) return;
    _cameraShutterGate.setLifecycleState(
      AppLifecycleState.resumed,
      currentSequence: widget.controller.cameraShutterSequence,
    );
    if (!widget.controller.availabilityFor(widget.feature).isReady) {
      if (mounted) setState(() => _cameraMessage = '戒指已断开，请重新连接后使用');
      return;
    }
    await _initializeCamera();
  }

  Future<void> _stopCameraRemoteIgnoringErrors() async {
    final controller = widget.controller;
    final owner = _cameraOwner;
    _cameraOwner = null;
    // `dispose` runs while Flutter has the element tree locked. The controller
    // publishes its busy state synchronously, so defer that notification to
    // the next event turn instead of rebuilding listeners during unmount.
    await Future<void>.delayed(Duration.zero);
    if (owner == null || owner != _currentFeatureContext) return;
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
          _galleryPermissionDenied = false;
          _cameraMessage = '照片已保存到手机相册';
        });
      }
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _cameraMessage = '拍照失败（${error.code}），请稍后重试');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _galleryPermissionDenied = error.code == 'PHOTO_PERMISSION_DENIED';
          _cameraMessage = error.message ?? '照片保存失败，请检查相册权限后重试';
        });
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _toggleFind() async {
    final source = widget.controller.connectedDevice?.sdkSource;
    final isOneShot =
        source == WearableSdkSource.yucheng ||
        (source == WearableSdkSource.coolwear &&
            defaultTargetPlatform != TargetPlatform.iOS);
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
              ? (source == WearableSdkSource.coolwear
                    ? (next ? '查找指令已发送' : '停止指令已发送')
                    : (isOneShot
                          ? '已发送查找指令，请留意戒指振动'
                          : (next ? '戒指正在响铃或振动' : '已停止查找')))
              : widget.controller.errorMessage ?? '暂时无法查找戒指',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_availableInRelease) return const WellnessReleaseUnavailablePage();
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final availability = widget.controller.availabilityFor(widget.feature);
        final busy = widget.controller.deviceFeatureBusy.contains(
          widget.feature,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.deviceFeatureName(widget.feature)),
          ),
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
                      !{
                        WearableSdkSource.yucheng,
                        WearableSdkSource.coolwear,
                      }.contains(
                        widget.controller.connectedDevice?.sdkSource,
                      ) ||
                      (widget.controller.connectedDevice?.sdkSource ==
                              WearableSdkSource.coolwear &&
                          defaultTargetPlatform == TargetPlatform.iOS),
                  commandOnly:
                      widget.controller.connectedDevice?.sdkSource ==
                      WearableSdkSource.coolwear,
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
    DeviceFeature.gestureControl => _buildGesturePanel(busy),
    DeviceFeature.callReminder => _buildCallReminderPanel(busy),
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
      message: '当前戒指暂不支持在 App 中设置',
      detail: _deviceFeatureDescription(widget.feature),
      icon: _deviceFeatureIcon(widget.feature),
    ),
  };

  Widget _buildGesturePanel(bool busy) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('选择戒指手势模式。系统控制效果取决于戒指固件和手机配对。'),
          const RingGestureGuide(),
          if (_featureData['requiresReconnect'] == true)
            const Text('重新连接后再设置手势'),
          const SizedBox(height: 12),
          for (final entry in const [
            (0, '关闭'),
            (1, '短视频'),
            (2, '音乐'),
            (3, '阅读'),
            (4, '拍照'),
            (5, '电话'),
          ])
            ListTile(
              title: Text(entry.$2),
              subtitle: Text(RingGestureGuide.modeHint(entry.$1)),
              trailing: _featureData['confirmedMode'] == entry.$1
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: busy || _featureData['requiresReconnect'] == true
                  ? null
                  : () => _saveFeature({'mode': entry.$1}, '手势模式指令已确认'),
            ),
          const Text(
            '勾选表示本次连接已确认的指令，不代表已执行手势。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _buildCallReminderPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '来电提醒');
    return Card(
      child: Column(
        children: [
          _featureSwitch(
            title: '来电提醒',
            subtitle: '在戒指提醒手机来电',
            keyName: 'incomingCall',
            busy: busy,
          ),
          ListTile(
            title: Text(
              _featureData['systemNotificationAuthorized'] == true
                  ? '蓝牙通知已授权'
                  : '蓝牙通知未授权',
            ),
            subtitle: const Text('在 iPhone 设置 → 蓝牙 → 戒指中允许共享系统通知。'),
            trailing: TextButton(
              onPressed: busy ? null : _loadFeature,
              child: const Text('刷新'),
            ),
          ),
        ],
      ),
    );
  }

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
    detail: '请保持戒指靠近手机后重试。',
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
              title: Text(
                context.l10n.watchFaceShop,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
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
              title: Text(context.l10n.installedWatchFaces),
              subtitle: Text(context.l10n.switchInstalledWatchFace),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '戒指中的显示样式',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        if (busy && progress != null && progress > 0) ...[
          LinearProgressIndicator(value: progress.clamp(0, 100) / 100),
          const SizedBox(height: 10),
          Text('正在读取显示样式 $progress%'),
          const SizedBox(height: 12),
        ],
        if (noLocalData)
          _loadingCard(busy, '戒指中的显示样式')
        else
          Card(
            child: faces.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('戒指中暂未读取到可切换的显示样式')),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < faces.length; index++) ...[
                        ListTile(
                          minLeadingWidth: 64,
                          leading: _WatchFaceThumbnail(face: faces[index]),
                          title: Text('${faces[index]['name'] ?? '戒指显示样式'}'),
                          subtitle: Text(
                            faces[index]['isCurrent'] == true
                                ? '当前使用'
                                : '${faces[index]['status'] ?? '戒指显示样式'}',
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
                                  child: Text(
                                    context.l10n.useSelectedWatchFace,
                                  ),
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
              label: Text(context.l10n.refreshWatchFaces),
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
        throw const DeviceWatchFaceMarketException('连接设备已变化，请重新进入显示样式页面');
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
    }, '显示样式已切换');
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
                          Text(
                            context.l10n.photoWatchFace,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.photoWatchFaceHint,
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
                      progress > 0 ? '正在传送到戒指 $progress%' : '正在准备照片显示',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _dialTimePosition,
                  decoration: InputDecoration(
                    labelText: context.l10n.timeDisplayPosition,
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
                    label: Text(context.l10n.transferSetWatchFace),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.watchTransferKeepNear,
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
      '照片显示已设置',
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
                        '可点击手机快门，也可摇动戒指触发拍照；照片会保存到手机相册。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SaydianColors.muted),
                      ),
                    ),
                  ],
                ),
                if (_galleryPermissionDenied) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const ValueKey('camera-photo-settings-button'),
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('允许保存照片'),
                  ),
                ],
                if (_cameraMessage != null &&
                    (camera == null || !_cameraRemoteStarted)) ...[
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
            title: Text(context.l10n.callMediaAudio),
            subtitle: Text(
              _featureData['audioEnabled'] == true ? '戒指媒体声音已连接' : '媒体声音尚未连接',
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
    subtitle: Text(supported ? subtitle : '当前戒指不支持此项'),
    value: _featureData[keyName] == true,
    onChanged: busy || !supported
        ? null
        : (value) =>
              _saveFeature({..._featureData, keyName: value}, '$title已保存'),
  );

  Widget _buildNotificationsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '消息通知设置');
    final supported =
        (_featureData['supportedKeys'] as List?)
            ?.map((value) => '$value')
            .toSet() ??
        const <String>{};
    final entries = <(String, String, String)>[
      ('incomingCall', '来电提醒', '有电话时在戒指提醒'),
      ('sms', '短信', '收到短信时由戒指提醒'),
      ('wechat', '微信', '收到微信消息时由戒指提醒'),
      ('qq', 'QQ', '收到 QQ 消息时由戒指提醒'),
      ('whatsapp', 'WhatsApp', '收到 WhatsApp 消息时由戒指提醒'),
      ('dingtalk', '钉钉', '收到钉钉消息时由戒指提醒'),
      ('wecom', '企业微信', '收到企业微信消息时由戒指提醒'),
      ('tiktok', '抖音', '收到抖音消息时由戒指提醒'),
      ('telegram', 'Telegram', '收到 Telegram 消息时由戒指提醒'),
      ('otherApps', '其他应用', '接收其他已允许应用的消息提醒'),
    ];
    final visibleEntries = entries
        .where((entry) => supported.contains(entry.$1))
        .toList(growable: false);
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
            subtitle: Text(access ? '已开启的应用消息可以发送到戒指' : '允许后，戒指才能提醒手机收到的应用消息'),
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
        if (visibleEntries.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < visibleEntries.length; index++) ...[
                  _featureSwitch(
                    keyName: visibleEntries[index].$1,
                    title: visibleEntries[index].$2,
                    subtitle: visibleEntries[index].$3,
                    busy: busy,
                  ),
                  if (index != visibleEntries.length - 1)
                    const Divider(indent: 56),
                ],
              ],
            ),
          ),
        ],
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
                title: '在戒指显示天气',
                subtitle: '开启后可在戒指查看天气信息',
                busy: busy || _weatherRefreshing,
              ),
              const Divider(indent: 56),
              SwitchListTile(
                title: Text(context.l10n.useCelsius),
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
                        : '已同步到戒指',
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
                        label: Text(context.l10n.selectCity),
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
      final saved = await _saveFeature(values, '天气已同步到戒指', reload: false);
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
                  child: Center(child: Text('戒指中还没有闹钟')),
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
            label: Text(context.l10n.addAlarm),
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
                  title: Text(context.l10n.alarmTime),
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
                  title: Text(context.l10n.enableAlarm),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                TextFormField(
                  initialValue: label,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: context.l10n.reminderName,
                    hintText: '例如：吃药、起床',
                  ),
                  onChanged: (value) => label = value.trim(),
                ),
                const SizedBox(height: 8),
                Text(context.l10n.repeat),
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
              child: Text(context.l10n.cancel),
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
              child: Text(context.l10n.save),
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
            title: Text(
              context.l10n.emergencyContact,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              emergency == null
                  ? '尚未设置，戒指触发 SOS 时将无法快速联系家人'
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
                  child: Center(child: Text('戒指中还没有常用联系人')),
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
    final confirmed = await _confirm('删除联系人', '确定从戒指删除这个联系人吗？');
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
      ).showSnackBar(const SnackBar(content: Text('当前戒指不支持设置 SOS 联系人')));
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
                Text(
                  context.l10n.selectEmergencyContact,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.sosContactHint,
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
                  label: Text(context.l10n.confirmEmergencyContact),
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
                  child: Center(child: Text('戒指中还没有世界时钟')),
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
          title: Text(context.l10n.addWorldClock),
          content: DropdownButtonFormField<(String, int)>(
            initialValue: selected,
            decoration: InputDecoration(labelText: context.l10n.city),
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
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, <String, Object?>{
                'operation': 'add',
                'city': selected.$1,
                'utcOffsetMinutes': selected.$2,
                'enabled': true,
              }),
              child: Text(context.l10n.add),
            ),
          ],
        ),
      ),
    );
    if (values != null) await _saveFeature(values, '世界时钟已添加');
  }

  Future<void> _deleteWorldClock(Map<String, Object?> clock) async {
    final confirmed = await _confirm('删除世界时钟', '确定从戒指删除这个城市吗？');
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
              child: Center(child: Text('当前戒指没有可设置的健康提醒')),
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
                      '${_minutesLabel((reminders[index]['endMinutes'] as num?)?.toInt() ?? 0)}'
                      '${reminders[index]['canEditInterval'] == false ? '' : '，每 ${(reminders[index]['intervalMinutes'] as num?)?.toInt() ?? 60} 分钟'}',
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
    final reportedInterval =
        (reminder['intervalMinutes'] as num?)?.toInt() ?? 60;
    var interval = reportedInterval >= 15 && reportedInterval <= 240
        ? reportedInterval
        : 60;
    final reportedOptions = (reminder['intervalChoices'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt())
        .toList();
    final intervalOptions = <int>{
      if (reportedOptions != null)
        ...reportedOptions
      else ...[
        15,
        30,
        45,
        60,
        90,
        120,
        180,
        240,
      ],
      interval,
    }.toList(growable: false)..sort();
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
                title: Text(context.l10n.startTime),
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
                title: Text(context.l10n.endTime),
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
              if (reminder['canEditInterval'] != false)
                DropdownButtonFormField<int>(
                  initialValue: interval,
                  decoration: InputDecoration(
                    labelText: context.l10n.reminderInterval,
                  ),
                  items: intervalOptions
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
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, <String, Object?>{
                ...reminder,
                'startMinutes': startMinutes,
                'endMinutes': endMinutes,
                'intervalMinutes': interval,
              }),
              child: Text(context.l10n.save),
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
      return FeatureStateCard(
        message: context.l10n.noHealthAssessments,
        detail: context.l10n.modelFeaturesVary,
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
                  subtitle: Text(context.l10n.assessmentEnabledHint),
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
        Text(
          context.l10n.assessmentSafety,
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
        icon: Icons.monitor_heart_outlined,
        actionLabel: '重新读取',
        onAction: widget.controller.refreshDeviceSettings,
      );
    }
    const labels = <String, String>{
      'heartRate': '心率自动检测',
      'bloodOxygen': '血氧自动检测',
      'hrv': '心率变异性（HRV）自动检测',
      'stress': '压力自动检测',
      'bloodPressure': '血压自动检测',
      'bloodGlucose': '血糖自动检测',
      'bodyTemperature': '皮肤温度自动检测',
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
                  subtitle: Text(context.l10n.autoMonitorIntervalHint),
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
              title: Text(context.l10n.watchHeartRateAlert),
              subtitle: Text(context.l10n.sustainedLimitWatchAlert),
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
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ) ??
      false;
}
