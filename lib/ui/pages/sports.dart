part of '../pages.dart';

Map<HealthMetric, num> _todayActivityValues(
  Iterable<HealthRecord> records,
  DateTime now,
) {
  final day = now.toLocal();
  final result = <HealthMetric, num>{};
  for (final record in records) {
    if (!hasSaneWearableTransportValues(record)) continue;
    if (record.metric != HealthMetric.steps &&
        record.metric != HealthMetric.distance &&
        record.metric != HealthMetric.calories) {
      continue;
    }
    final measured = record.measuredAt.toLocal();
    if (measured.year != day.year ||
        measured.month != day.month ||
        measured.day != day.day) {
      continue;
    }
    final value = record.values['value'];
    if (value == null || !value.isFinite || value < 0) continue;
    result.update(
      record.metric,
      (current) => current + value,
      ifAbsent: () => value,
    );
  }
  return result;
}

class SportOverviewPage extends StatefulWidget {
  const SportOverviewPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<SportOverviewPage> createState() => _SportOverviewPageState();
}

class _SportOverviewPageState extends State<SportOverviewPage> {
  Map<HealthMetric, num> _activityValues = const {};
  bool _loading = true;
  bool _loadFailed = false;
  int _loadGeneration = 0;
  bool _wasDeviceSyncing = false;

  @override
  void initState() {
    super.initState();
    _wasDeviceSyncing = widget.controller.isDeviceSyncing;
    widget.controller.addListener(_onDeviceSyncChanged);
    unawaited(_refreshActivity());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDeviceSyncChanged);
    super.dispose();
  }

  void _onDeviceSyncChanged() {
    final syncing = widget.controller.isDeviceSyncing;
    if (_wasDeviceSyncing && !syncing) unawaited(_loadActivity());
    _wasDeviceSyncing = syncing;
  }

  Future<void> _refreshActivity() async {
    // Show already saved activity immediately. HR05 history can wait for a
    // vendor completion event that some firmware never sends.
    await _loadActivity();
    try {
      if (widget.controller.connectedDevice != null &&
          !widget.controller.isDeviceSyncing) {
        await widget.controller.syncDeviceData();
      }
      await widget.controller.refreshSportRecords(includeDevice: false);
    } catch (_) {
      // A failed remote sync must not hide already saved local activity.
    } finally {
      await _loadActivity();
    }
  }

  Future<void> _loadActivity() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);
    try {
      final batches = await Future.wait([
        for (final metric in const [
          HealthMetric.steps,
          HealthMetric.distance,
          HealthMetric.calories,
        ])
          widget.controller.loadHealthRecords(
            metric: metric,
            start: start,
            end: end,
          ),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _activityValues = _todayActivityValues(
          batches.expand((batch) => batch),
          now,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _activityValues = const {};
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('sport-overview-page'),
    appBar: AppBar(title: const Text('运动')),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _refreshActivity,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_loadFailed)
              InlineNotice(
                message: '今日活动读取失败，请下拉重试',
                icon: Icons.refresh_rounded,
                color: SaydianColors.orange,
                onTap: _loadActivity,
              ),
            _SportEntryPanel(
              controller: widget.controller,
              latest: _activityValues,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SportEntryPanel extends StatelessWidget {
  const _SportEntryPanel({required this.controller, required this.latest});

  final AppController controller;
  final Map<HealthMetric, num> latest;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('health-sport-entries'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x26316EF5)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          _TodayHealthOverview(
            latest: latest,
            stepTarget: controller.stepGoal.toDouble(),
            distanceTarget: controller.distanceGoal,
            calorieTarget: controller.calorieGoal.toDouble(),
            onSetGoal: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'activity-goals'),
                builder: (_) => GoalSettingsPage(controller: controller),
              ),
            ),
            onOpenMetric: (metric) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: RouteSettings(name: 'activity-${metric.wireName}'),
                builder: (_) =>
                    HealthTrendPage(controller: controller, metric: metric),
              ),
            ),
          ),
          if (latest.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                controller.isDeviceSyncing
                    ? '正在读取戒指活动数据，已保存的记录仍可查看'
                    : controller.syncStatus.contains('失败') ||
                          controller.syncStatus.contains('未确认')
                    ? '戒指尚未返回完整活动数据，请保持连接后重试'
                    : '暂无今日活动数据，下拉可同步戒指',
                style: const TextStyle(color: SaydianColors.muted),
              ),
            ),
          const SizedBox(height: 14),
          Visibility(
            visible: true,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: SaydianColors.brandRedSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        color: SaydianColors.brandRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.startWorkoutToday,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            context.l10n.selectWorkoutPhoneHint,
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final modes = controller.availableSportModes;
                    if (modes.isEmpty) {
                      return InlineNotice(
                        message: context.l10n.workoutStartOnWatch,
                        icon: Icons.circle_outlined,
                        color: SaydianColors.orange,
                      );
                    }
                    const previewCount = 4;
                    final hasMore = modes.length > previewCount;
                    final visibleModes = modes
                        .take(previewCount)
                        .toList(growable: false);
                    final width = constraints.maxWidth / previewCount;
                    return Column(
                      children: [
                        Wrap(
                          key: const Key('sport-mode-grid'),
                          children: [
                            for (final mode in visibleModes)
                              SizedBox(
                                width: width,
                                child: _SportEntry(
                                  mode: mode,
                                  onTap: () => _openSportSession(
                                    context,
                                    controller,
                                    mode,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (hasMore) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              key: const Key('sport-mode-more'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: const RouteSettings(
                                    name: 'sport-mode-selection',
                                  ),
                                  builder: (_) => SportModeSelectionPage(
                                    controller: controller,
                                  ),
                                ),
                              ),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: Text(context.l10n.showMoreSports),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Material(
            color: SaydianColors.brandRedSoft,
            borderRadius: BorderRadius.circular(17),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SportRecordsPage(controller: controller),
                ),
              ),
              leading: const _SettingsIcon(
                icon: Icons.history_rounded,
                color: SaydianColors.brandRed,
              ),
              title: Text(
                context.l10n.workoutRecords,
                style: TextStyle(
                  color: SaydianColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                controller.connectedDevice == null
                    ? '连接戒指后读取运动记录'
                    : '已读取 ${controller.sportRecords.length} 条记录',
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: SaydianColors.brandRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openSportSession(
  BuildContext context,
  AppController controller,
  SportMode mode,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'sport-session-${mode.name}'),
      builder: (_) => SportSessionPage(controller: controller, mode: mode),
    ),
  );
}

class SportModeSelectionPage extends StatelessWidget {
  const SportModeSelectionPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('sport-mode-selection-page'),
      appBar: AppBar(title: Text(context.l10n.allSports)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final modes = controller.availableSportModes;
          if (modes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InlineNotice(
                  message: context.l10n.workoutStartOnWatch,
                  icon: Icons.circle_outlined,
                  color: SaydianColors.orange,
                ),
              ),
            );
          }
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.crossAxisExtent >= 720
                        ? 6
                        : constraints.crossAxisExtent >= 480
                        ? 4
                        : 3;
                    return SliverGrid.builder(
                      key: const Key('all-sport-mode-grid'),
                      itemCount: modes.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 108 + (textScale - 1).clamp(0, 1) * 30,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final mode = modes[index];
                        return _SportEntry(
                          key: ValueKey('all-sport-mode-${mode.name}'),
                          mode: mode,
                          onTap: () =>
                              _openSportSession(context, controller, mode),
                        );
                      },
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverToBoxAdapter(
                  child: Material(
                    color: SaydianColors.brandRedSoft,
                    borderRadius: BorderRadius.circular(17),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: const Key('all-sport-records'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SportRecordsPage(controller: controller),
                        ),
                      ),
                      leading: const Icon(
                        Icons.history_rounded,
                        color: SaydianColors.brandRed,
                      ),
                      title: Text(
                        context.l10n.workoutRecords,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SportEntry extends StatelessWidget {
  const _SportEntry({required this.mode, required this.onTap, super.key});

  final SportMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode) {
      SportMode.running => Icons.directions_run_rounded,
      SportMode.indoorRunning => Icons.directions_run_rounded,
      SportMode.walking => Icons.directions_walk_rounded,
      SportMode.cycling => Icons.directions_bike_rounded,
      SportMode.indoorCycling => Icons.pedal_bike_rounded,
      SportMode.basketball => Icons.sports_basketball_rounded,
      SportMode.football => Icons.sports_soccer_rounded,
      SportMode.badminton => Icons.sports_tennis_rounded,
      SportMode.swimming => Icons.pool_rounded,
      SportMode.jumpRope => Icons.sync_rounded,
      SportMode.yoga => Icons.self_improvement_rounded,
      SportMode.hiking => Icons.hiking_rounded,
      SportMode.mountaineering => Icons.landscape_rounded,
    };
    final color = switch (mode) {
      SportMode.running => SaydianColors.brandRed,
      SportMode.indoorRunning => SaydianColors.techIndigo,
      SportMode.walking => SaydianColors.brandGoldDark,
      SportMode.cycling => SaydianColors.techCyan,
      SportMode.indoorCycling => const Color(0xFF397AC7),
      SportMode.basketball => const Color(0xFF6373D9),
      SportMode.football => const Color(0xFF3E9663),
      SportMode.badminton => const Color(0xFF4285B8),
      SportMode.swimming => const Color(0xFF2B9EB3),
      SportMode.jumpRope => const Color(0xFF8B5CB5),
      SportMode.yoga => SaydianColors.techViolet,
      SportMode.hiking => const Color(0xFF338C82),
      SportMode.mountaineering => const Color(0xFF536C9F),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.sportModeName(mode),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class SportSessionPage extends StatefulWidget {
  const SportSessionPage({
    required this.controller,
    required this.mode,
    super.key,
  });

  final AppController controller;
  final SportMode mode;

  @override
  State<SportSessionPage> createState() => _SportSessionPageState();
}

String _sportPaceLabel(int durationSeconds, double distanceKm) {
  if (durationSeconds <= 0 || distanceKm <= 0) return '--';
  final seconds = (durationSeconds / distanceKm).round();
  if (seconds <= 0 || seconds > 3599) return '--';
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')} /公里';
}

class _SportSessionPageState extends State<SportSessionPage> {
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  int _elapsedSeconds = 0;
  DateTime? _startedAt;
  final List<SportRoutePoint> _routePoints = [];
  final List<SportHeartRateSample> _heartRateSamples = [];
  double _routeDistanceKm = 0;
  String _locationStatus = '开始后可记录前台户外轨迹';
  bool _allowPop = false;
  bool _finalizingSport = false;
  int _trackingGeneration = 0;

  @override
  void initState() {
    super.initState();
    _locationStatus = _usesPhoneRoute ? '开始后可记录前台户外轨迹' : '本运动由戒指记录，不启用手机轨迹';
    widget.controller.addListener(_handleControllerChange);
  }

  bool get _usesPhoneRoute => switch (widget.mode) {
    SportMode.running ||
    SportMode.walking ||
    SportMode.cycling ||
    SportMode.hiking ||
    SportMode.mountaineering => true,
    _ => false,
  };

  void _handleControllerChange() {
    if (_startedAt != null &&
        widget.controller.activeSport == widget.mode &&
        !widget.controller.sportPaused) {
      final bpm = (widget.controller.liveSportData['heartRate'] ?? 0).toInt();
      if (bpm >= 20 &&
          bpm <= 250 &&
          (_heartRateSamples.isEmpty ||
              _elapsedSeconds - _heartRateSamples.last.elapsedSeconds >= 10 ||
              _heartRateSamples.last.bpm != bpm)) {
        _heartRateSamples.add(
          SportHeartRateSample(elapsedSeconds: _elapsedSeconds, bpm: bpm),
        );
      }
    }
    if (_startedAt != null &&
        widget.controller.activeSport != widget.mode &&
        !_finalizingSport) {
      _finalizingSport = true;
      unawaited(_finalizeSport(requestDeviceStop: false));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _timer?.cancel();
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  Future<void> _toggleSport() async {
    if (widget.controller.activeSport == widget.mode) {
      await _stopAndSaveSport();
      return;
    }
    if (widget.controller.activeSport != null) return;
    final started = await widget.controller.startSport(widget.mode);
    if (!started || !mounted) return;
    _timer?.cancel();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _startedAt = DateTime.now();
    _elapsedSeconds = 0;
    _routePoints.clear();
    _heartRateSamples.clear();
    _routeDistanceKm = 0;
    _locationStatus = _usesPhoneRoute ? '正在准备前台户外轨迹' : '本运动由戒指记录，不启用手机轨迹';
    final trackingGeneration = ++_trackingGeneration;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          widget.controller.activeSport == widget.mode &&
          !widget.controller.sportPaused) {
        setState(() => _elapsedSeconds += 1);
      }
    });
    setState(() {});
    if (_usesPhoneRoute) {
      unawaited(_startLocationTracking(trackingGeneration));
    }
  }

  Future<void> _stopAndSaveSport() async {
    if (_finalizingSport) return;
    _finalizingSport = true;
    await _finalizeSport(requestDeviceStop: true);
  }

  Future<void> _finalizeSport({required bool requestDeviceStop}) async {
    final startedAt = _startedAt;
    final previousLocationStatus = _locationStatus;
    var recordSaved = false;
    if (mounted) {
      setState(() {
        _locationStatus = requestDeviceStop ? '正在结束运动并保存记录' : '戒指已结束运动，正在保存记录';
      });
    }
    try {
      if (requestDeviceStop) {
        await widget.controller.stopSport();
        if (widget.controller.activeSport == widget.mode) {
          _locationStatus = previousLocationStatus;
          return;
        }
      }

      _timer?.cancel();
      _timer = null;
      _trackingGeneration++;
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      final watchData = Map<String, num>.from(widget.controller.liveSportData);
      final watchDuration = (watchData['durationSeconds'] ?? 0).toInt();
      final watchDistanceMeters = (watchData['distanceMeters'] ?? 0).toDouble();
      final durationSeconds = watchDuration > 0
          ? watchDuration
          : _elapsedSeconds;
      if (startedAt != null && durationSeconds > 0) {
        await widget.controller.saveLocalSportRecord(
          SportRecord(
            id: 'local:${startedAt.toUtc().toIso8601String()}',
            mode: widget.mode,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            distanceKm: watchDistanceMeters > 0
                ? watchDistanceMeters / 1000
                : _routeDistanceKm,
            calories: (watchData['calories'] ?? 0).toDouble(),
            steps: (watchData['steps'] ?? 0).toInt(),
            heartRate:
                (watchData['heartRate'] ??
                        (_heartRateSamples.isEmpty
                            ? 0
                            : _heartRateSamples.last.bpm))
                    .toInt(),
            routePoints: List.unmodifiable(_routePoints),
            heartRateSamples: List.unmodifiable(_heartRateSamples),
          ),
        );
        recordSaved = true;
        _elapsedSeconds = durationSeconds;
      }
      _startedAt = null;
      _locationStatus = recordSaved
          ? requestDeviceStop
                ? '本次运动已结束，记录已保存'
                : '戒指已结束本次运动，记录已保存'
          : '本次运动已结束';
    } finally {
      _finalizingSport = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _togglePause() async {
    await widget.controller.setSportPaused(!widget.controller.sportPaused);
  }

  Future<void> _confirmExit() async {
    if (widget.controller.activeSport != widget.mode) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.finishWorkoutConfirm),
        content: Text(context.l10n.finishLeaveWorkoutHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.resumeWorkout),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.finishAndLeave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _stopAndSaveSport();
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  bool _isCurrentTrackingGeneration(int generation) =>
      mounted && generation == _trackingGeneration && _startedAt != null;

  Future<void> _startLocationTracking(int generation) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (_isCurrentTrackingGeneration(generation)) {
        setState(() => _locationStatus = '定位服务未开启，仍会记录戒指运动数据');
      }
      return;
    }
    if (!_isCurrentTrackingGeneration(generation)) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!_isCurrentTrackingGeneration(generation)) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _locationStatus = '未允许位置权限，仍会记录戒指运动数据');
      return;
    }
    setState(() => _locationStatus = '正在记录前台户外轨迹');
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (position) {
            if (position.accuracy > 80 ||
                !_isCurrentTrackingGeneration(generation) ||
                widget.controller.sportPaused) {
              return;
            }
            final point = SportRoutePoint(
              latitude: position.latitude,
              longitude: position.longitude,
              recordedAt: position.timestamp,
              accuracy: position.accuracy,
            );
            if (_routePoints.isNotEmpty) {
              final previous = _routePoints.last;
              final meters = Geolocator.distanceBetween(
                previous.latitude,
                previous.longitude,
                point.latitude,
                point.longitude,
              );
              if (meters >= 500) return;
              _routeDistanceKm += meters / 1000;
            }
            setState(() => _routePoints.add(point));
          },
          onError: (_) {
            if (_isCurrentTrackingGeneration(generation)) {
              setState(() => _locationStatus = '轨迹读取中断，戒指运动仍在继续');
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller.activeSport == widget.mode;
    final anotherSportActive = widget.controller.activeSport != null && !active;
    final paused = active && widget.controller.sportPaused;
    final liveData = widget.controller.liveSportData;
    final watchDistanceKm = (liveData['distanceMeters'] ?? 0).toDouble() / 1000;
    final liveDistanceKm = watchDistanceKm > 0
        ? watchDistanceKm
        : _routeDistanceKm;
    final pace = _sportPaceLabel(_elapsedSeconds, liveDistanceKm);
    final duration = Duration(seconds: _elapsedSeconds);
    final time = [
      duration.inHours,
      duration.inMinutes.remainder(60),
      duration.inSeconds.remainder(60),
    ].map((value) => value.toString().padLeft(2, '0')).join(':');
    return PopScope(
      canPop: _allowPop || !active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && active) unawaited(_confirmExit());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.sportModeName(widget.mode))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D3B6F), Color(0xFF385D9C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Icon(
                    active ? Icons.directions_run_rounded : Icons.route_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    time,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    active
                        ? (paused
                              ? context.l10n.workoutPaused(
                                  context.l10n.sportModeName(widget.mode),
                                )
                              : context.l10n.workoutInProgress(
                                  context.l10n.sportModeName(widget.mode),
                                ))
                        : context.l10n.workoutReady(
                            context.l10n.sportModeName(widget.mode),
                          ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (active) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SportLiveMetric(
                    label: '运动距离',
                    value: liveDistanceKm > 0
                        ? '${liveDistanceKm.toStringAsFixed(2)} km'
                        : '--',
                  ),
                  _SportLiveMetric(
                    label: context.l10n.watchSteps,
                    value: liveData['steps'] == null
                        ? '--'
                        : context.l10n.stepCount(liveData['steps']!.toInt()),
                  ),
                  _SportLiveMetric(
                    label: context.l10n.liveHeartRate,
                    value: (liveData['heartRate'] ?? 0) > 0
                        ? '${(liveData['heartRate'] ?? 0).toInt()} bpm'
                        : '--',
                  ),
                  _SportLiveMetric(label: '平均配速', value: pace),
                  _SportLiveMetric(
                    label: context.l10n.watchCalories,
                    value: liveData['calories'] == null
                        ? '--'
                        : '${liveData['calories']!.toDouble().toStringAsFixed(1)} kcal',
                  ),
                ],
              ),
              if (liveData['calories'] == null &&
                  widget.controller.connectedDevice?.model == 'HR05') ...[
                const SizedBox(height: 8),
                const Text(
                  'HR05 运动实时协议未回传热量；结束后同步戒指记录查看，不显示估算值。',
                  style: TextStyle(color: SaydianColors.muted, fontSize: 12),
                ),
              ],
            ],
            const SizedBox(height: 18),
            InlineNotice(
              message: widget.controller.connectedDevice == null
                  ? context.l10n.connectForWorkout
                  : '已连接 ${widget.controller.connectedDevice!.name}。$_locationStatus',
              icon: Icons.watch_rounded,
              color: SaydianColors.blue,
            ),
            if (_routePoints.isNotEmpty) ...[
              const SizedBox(height: 14),
              SportRoutePreview(
                points: _routePoints,
                distanceKm: _routeDistanceKm,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Row(
            children: [
              if (active &&
                  widget.controller.capabilities?.supportsSportPause ==
                      true) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('sport-session-pause'),
                    onPressed: _togglePause,
                    icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                    label: Text(
                      paused
                          ? context.l10n.resumeWorkout
                          : context.l10n.pauseWorkout,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const Key('sport-session-toggle'),
                    onPressed:
                        widget.controller.connectedDevice == null ||
                            anotherSportActive ||
                            _finalizingSport
                        ? null
                        : _toggleSport,
                    style: FilledButton.styleFrom(
                      backgroundColor: active
                          ? SaydianColors.danger
                          : SaydianColors.techBlue,
                    ),
                    icon: Icon(
                      _finalizingSport
                          ? Icons.hourglass_top_rounded
                          : active
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _finalizingSport
                          ? context.l10n.saving
                          : anotherSportActive
                          ? context.l10n.finishOtherWorkout(
                              context.l10n.sportModeName(
                                widget.controller.activeSport!,
                              ),
                            )
                          : active
                          ? context.l10n.finishWorkout
                          : context.l10n.startWorkout(
                              context.l10n.sportModeName(widget.mode),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportLiveMetric extends StatelessWidget {
  const _SportLiveMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: (MediaQuery.sizeOf(context).width - 50) / 2,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7FC),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: SaydianColors.muted)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class SportRecordsPage extends StatefulWidget {
  const SportRecordsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<SportRecordsPage> createState() => _SportRecordsPageState();
}

class _SportRecordsPageState extends State<SportRecordsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshSportRecords());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.workoutRecords)),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final records = widget.controller.sportRecords;
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.controller.connectedDevice == null
                      ? '请先连接戒指后读取运动记录'
                      : '戒指中暂无运动记录',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SaydianColors.muted),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.controller.refreshSportRecords,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _SportRecordTile(
                controller: widget.controller,
                record: records[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SportRecordTile extends StatelessWidget {
  const _SportRecordTile({required this.controller, required this.record});

  final AppController controller;
  final SportRecord record;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: record.durationSeconds);
    final durationText = duration.inHours > 0
        ? '${duration.inHours}小时${duration.inMinutes.remainder(60)}分钟'
        : duration.inMinutes > 0
        ? '${duration.inMinutes}分钟${duration.inSeconds.remainder(60) > 0 ? '${duration.inSeconds.remainder(60)}秒' : ''}'
        : '${duration.inSeconds}秒';
    final usesMiles = controller.distanceUnit == '英里';
    final distance = usesMiles
        ? record.distanceKm * 0.621371
        : record.distanceKm;
    final distanceUnit = usesMiles ? '英里' : '公里';
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SportRecordDetailPage(controller: controller, record: record),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F1FF),
          foregroundColor: Color(0xFF1D3B6F),
          child: Icon(Icons.route_rounded),
        ),
        title: Text(
          context.l10n.sportModeName(record.mode),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${distance.toStringAsFixed(2)} $distanceUnit · '
          '${record.calories.toStringAsFixed(1)} 千卡 · $durationText',
        ),
        trailing: Text(
          record.startedAt == null
              ? '--'
              : DateFormat('MM/dd').format(record.startedAt!.toLocal()),
          style: const TextStyle(color: SaydianColors.muted),
        ),
      ),
    );
  }
}

class SportRecordDetailPage extends StatelessWidget {
  const SportRecordDetailPage({
    required this.controller,
    required this.record,
    super.key,
  });

  final AppController controller;
  final SportRecord record;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: record.durationSeconds);
    final distance = controller.distanceUnit == '英里'
        ? record.distanceKm * 0.621371
        : record.distanceKm;
    final unit = controller.distanceUnit == '英里' ? '英里' : '公里';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.workoutDetails(context.l10n.sportModeName(record.mode)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (record.routePoints.length >= 2)
            SportRoutePreview(
              points: record.routePoints,
              distanceKm: record.distanceKm,
              controller: controller,
            )
          else
            InlineNotice(
              message: context.l10n.workoutRouteMissing,
              icon: Icons.route_outlined,
              color: SaydianColors.orange,
            ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(context.l10n.workoutDuration),
                  trailing: Text(
                    '${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                  ),
                ),
                const Divider(indent: 16),
                ListTile(
                  title: Text(context.l10n.distance),
                  trailing: Text('${distance.toStringAsFixed(2)} $unit'),
                ),
                if (record.calories > 0) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: Text(context.l10n.calories),
                    trailing: Text('${record.calories.toStringAsFixed(1)} 千卡'),
                  ),
                ],
                if (record.steps > 0) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: Text(context.l10n.steps),
                    trailing: Text('${record.steps} 步'),
                  ),
                ],
                if (record.heartRate > 0) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: Text(context.l10n.workoutWatchHeartRate),
                    trailing: Text('${record.heartRate} bpm'),
                  ),
                ],
                if (record.paceSecondsPerKm != null) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: const Text('平均配速'),
                    trailing: Text(
                      _sportPaceLabel(
                        record.durationSeconds,
                        record.distanceKm,
                      ),
                    ),
                  ),
                ],
                if (record.heartRateSamples.isNotEmpty) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: const Text('心率记录'),
                    subtitle: Text(
                      record.heartRateSamples
                          .map(
                            (sample) =>
                                '${(sample.elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(sample.elapsedSeconds % 60).toString().padLeft(2, '0')}  ${sample.bpm} bpm',
                          )
                          .join(' · '),
                    ),
                  ),
                ],
                if (record.startedAt != null) ...[
                  const Divider(indent: 16),
                  ListTile(
                    title: Text(context.l10n.startTime),
                    trailing: Text(
                      DateFormat(
                        'yyyy-MM-dd HH:mm',
                      ).format(record.startedAt!.toLocal()),
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
}

class SportRoutePreview extends StatefulWidget {
  const SportRoutePreview({
    required this.points,
    required this.distanceKm,
    this.controller,
    super.key,
  });

  final List<SportRoutePoint> points;
  final double distanceKm;
  final AppController? controller;

  @override
  State<SportRoutePreview> createState() => _SportRoutePreviewState();
}

class _SportRoutePreviewState extends State<SportRoutePreview> {
  Future<Uint8List?>? _map;

  @override
  void initState() {
    super.initState();
    _map = widget.controller?.loadSportRouteMap(widget.points);
  }

  @override
  void didUpdateWidget(covariant SportRoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.points != widget.points) {
      _map = widget.controller?.loadSportRouteMap(widget.points);
    }
  }

  @override
  Widget build(BuildContext context) => _map == null
      ? _content(null)
      : FutureBuilder<Uint8List?>(
          future: _map,
          builder: (context, snapshot) => _content(snapshot.data),
        );

  Widget _content(Uint8List? mapImage) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 210,
          width: double.infinity,
          child: mapImage == null
              ? CustomPaint(
                  painter: _RoutePainter(widget.points),
                  child: const SizedBox.expand(),
                )
              : Image.memory(mapImage, fit: BoxFit.contain),
        ),
        Padding(
          padding: const EdgeInsets.all(13),
          child: Text(
            '${widget.points.length} 个定位点 · ${widget.distanceKm.toStringAsFixed(2)} 公里\n'
            '${mapImage == null ? '轨迹示意（未加载地图底图）' : '地图来源：高德地图'}',
            style: const TextStyle(
              color: SaydianColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.points);

  final List<SportRoutePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF0F4F3),
    );
    if (points.length < 2) return;
    final minLat = points.map((point) => point.latitude).reduce(math.min);
    final maxLat = points.map((point) => point.latitude).reduce(math.max);
    final minLng = points.map((point) => point.longitude).reduce(math.min);
    final maxLng = points.map((point) => point.longitude).reduce(math.max);
    final latSpan = math.max(maxLat - minLat, 0.00001);
    final lngSpan = math.max(maxLng - minLng, 0.00001);
    const padding = 24.0;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x =
          padding +
          (point.longitude - minLng) / lngSpan * (size.width - padding * 2);
      final y =
          size.height -
          padding -
          (point.latitude - minLat) / latSpan * (size.height - padding * 2);
      index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = SaydianColors.blue
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.points != points;
}
