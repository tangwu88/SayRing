import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../domain/global_account.dart';
import '../domain/global_care.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';
import 'global_care_dashboard.dart';

const _serverCareMetrics = <String>{
  'sleep',
  'steps',
  'distance',
  'calories',
  'heart_rate',
  'blood_oxygen',
  'blood_pressure',
  'blood_glucose',
  'temperature',
  'hrv',
  'ecg',
  'body_composition',
  'blood_composition',
};

Set<String> supportedCareMetrics(Iterable<HealthMetric> metrics) => metrics
    .map(
      (metric) => metric.wireName == 'body_temperature'
          ? 'temperature'
          : metric.wireName,
    )
    .where(_serverCareMetrics.contains)
    .toSet();

class GlobalCarePage extends StatefulWidget {
  const GlobalCarePage({super.key, required this.controller});
  final AppController controller;
  @override
  State<GlobalCarePage> createState() => _GlobalCarePageState();
}

class _GlobalCarePageState extends State<GlobalCarePage> {
  List<GlobalCareRelationship> _relationships = const [];
  bool _loading = true;
  bool _working = false;
  bool _failed = false;
  int _generation = 0;
  late String? _owner;
  bool get _sameOwner =>
      _owner != null && _owner == widget.controller.session?.accountKey;

  @override
  void initState() {
    super.initState();
    _owner = widget.controller.session?.accountKey;
    widget.controller.addListener(_accountChanged);
    unawaited(_load());
  }

  void _accountChanged() {
    if (_sameOwner || !mounted) return;
    _generation++;
    setState(() {
      _relationships = const [];
      _loading = false;
      _failed = false;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_accountChanged);
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (!_sameOwner) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await widget.controller.globalCareRelationships();
      if (mounted && generation == _generation && _sameOwner) {
        setState(() => _relationships = rows);
      }
    } catch (_) {
      if (mounted && generation == _generation && _sameOwner) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _operate(Future<void> Function() action) async {
    if (_working || !_sameOwner) return;
    setState(() => _working = true);
    try {
      await action();
      if (!mounted || !_sameOwner) return;
      await _load();
      unawaited(widget.controller.refreshCare());
      unawaited(widget.controller.refreshCareInvitations());
    } catch (_) {
      if (mounted && _sameOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.serviceUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _invite() async {
    final input = TextEditingController();
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(dialog.l10n.addCare),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dialog.l10n.careInviteHint),
              const SizedBox(height: 12),
              TextFormField(
                controller: input,
                key: const Key('global-care-contact'),
                decoration: InputDecoration(
                  labelText: dialog.l10n.emailOrPhone,
                ),
                validator: (value) {
                  try {
                    GlobalAccountIdentity.parse(value ?? '');
                    return null;
                  } catch (_) {
                    return dialog.l10n.invalidCareContact;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(dialog.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() == true) {
                Navigator.pop(dialog, input.text);
              }
            },
            child: Text(dialog.l10n.send),
          ),
        ],
      ),
    );
    // Dialog animations can still refer to this controller until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
    if (value == null || !mounted || !_sameOwner) return;
    await _operate(() => widget.controller.globalInviteCare(value));
  }

  Future<void> _permissions(GlobalCareRelationship row) async {
    final supported = widget.controller.isWellnessOnly
        ? supportedCareMetrics(
            HealthMetric.values.where(
              widget.controller.isMetricAvailableInRelease,
            ),
          )
        : _serverCareMetrics;
    final selected = Set<String>.of(row.metrics);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: Text(dialog.l10n.sharedMeasurements),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dialog.l10n.careSharingHint),
                  if (supported.isEmpty) Text(dialog.l10n.connectForWorkout),
                  for (final entry in _metricLabels(
                    dialog,
                  ).entries.where((entry) => supported.contains(entry.key)))
                    CheckboxListTile(
                      title: Text(entry.value),
                      value: selected.contains(entry.key),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => update(() {
                        if (checked == true) {
                          selected.add(entry.key);
                        } else {
                          selected.remove(entry.key);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(dialog.l10n.cancel),
            ),
            FilledButton(
              onPressed: supported.isEmpty
                  ? null
                  : () => Navigator.pop(dialog, selected),
              child: Text(dialog.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted || !_sameOwner) return;
    await _operate(() => widget.controller.globalShareCare(row.id, result));
  }

  Future<void> _revoke(GlobalCareRelationship row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(dialog.l10n.stopSharing),
        content: Text(row.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(dialog.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(dialog.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && _sameOwner) {
      await _operate(() => widget.controller.globalRevokeCare(row.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      key: const Key('global-care-page'),
      appBar: AppBar(title: Text(l.remoteCare)),
      body: !_sameOwner
          ? Center(child: Text(l.signInCloudHint))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('仅查看已授权的数据'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _working ? null : _invite,
                    icon: const Icon(Icons.person_add_outlined),
                    label: Text(l.addCare),
                  ),
                  if (_loading || _working) const LinearProgressIndicator(),
                  if (_failed) ...[
                    Text(l.serviceUnavailable),
                    TextButton(onPressed: _load, child: Text(l.retry)),
                  ],
                  if (!_loading && !_failed && _relationships.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(l.noData)),
                    ),
                  for (final received in [false, true]) ...[
                    if (_relationships.any((row) => row.received == received))
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          received ? '关注我的' : '我关注的',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    for (final row in _relationships.where(
                      (row) => row.received == received,
                    ))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.name.isEmpty ? l.defaultUser : row.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                row.active
                                    ? l.careActive
                                    : row.status == 'pending'
                                    ? l.carePending
                                    : l.careClosed,
                              ),
                              if (row.received && row.status == 'pending')
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton(
                                      onPressed: _working
                                          ? null
                                          : () => _operate(
                                              () => widget.controller
                                                  .globalRespondCare(
                                                    row.id,
                                                    true,
                                                  ),
                                            ),
                                      child: Text(l.accept),
                                    ),
                                    TextButton(
                                      onPressed: _working
                                          ? null
                                          : () => _operate(
                                              () => widget.controller
                                                  .globalRespondCare(
                                                    row.id,
                                                    false,
                                                  ),
                                            ),
                                      child: Text(l.decline),
                                    ),
                                  ],
                                ),
                              if (row.active && row.received)
                                TextButton(
                                  onPressed: _working
                                      ? null
                                      : () => _permissions(row),
                                  child: Text(l.sharedMeasurements),
                                ),
                              if (row.active && !row.received) ...[
                                if (row.metrics.isEmpty)
                                  Text(l.carePermissionDenied),
                                if (row.metrics.isNotEmpty)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('查看健康数据'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: _working
                                        ? null
                                        : () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  GlobalCareDashboard(
                                                    controller:
                                                        widget.controller,
                                                    relationship: row,
                                                    owner: _owner!,
                                                  ),
                                            ),
                                          ),
                                  ),
                              ],
                              if (row.active || row.status == 'pending')
                                TextButton(
                                  onPressed: _working
                                      ? null
                                      : () => _revoke(row),
                                  child: Text(l.stopSharing),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

Map<String, String> _metricLabels(BuildContext context) {
  final l = context.l10n;
  return {
    'steps': l.steps,
    'distance': l.distance,
    'calories': l.calories,
    'sleep': l.sleep,
    'heart_rate': l.heartRate,
    'blood_oxygen': l.bloodOxygen,
    'blood_pressure': l.bloodPressure,
    'blood_glucose': l.bloodGlucose,
    'temperature': l.bodyTemperature,
    'hrv': l.hrv,
    'ecg': l.ecg,
    'body_composition': l.bodyComposition,
    'blood_composition': l.bloodComposition,
  };
}
