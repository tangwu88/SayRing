import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../domain/global_care.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';
import '../services/api_client.dart' show ApiException;
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
  bool _received = false;
  BuildContext? _activeDialog;
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
    final dialog = _activeDialog;
    _activeDialog = null;
    if (dialog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dialog.mounted && ModalRoute.of(dialog)?.isCurrent == true) {
          Navigator.of(dialog).pop();
        }
      });
    }
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
    final generation = _generation;
    setState(() => _working = true);
    try {
      await action();
      if (!mounted || !_sameOwner || generation != _generation) return;
      await _load();
      unawaited(widget.controller.refreshCare());
      unawaited(widget.controller.refreshCareInvitations());
    } catch (error) {
      if (mounted && _sameOwner && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException && error.statusCode == 429
                  ? context.l10n.tooManyAttempts
                  : context.l10n.serviceUnavailable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _invite() async {
    final generation = _generation;
    final input = TextEditingController();
    final form = GlobalKey<FormState>();
    var method = CareInvitationMethod.contact;
    CareInvitationTarget target() => method == CareInvitationMethod.memberId
        ? CareInvitationTarget.memberId(input.text)
        : CareInvitationTarget.contact(input.text);
    final value = await showDialog<CareInvitationTarget>(
      context: context,
      builder: (dialog) {
        _activeDialog = dialog;
        return StatefulBuilder(
          builder: (dialog, update) => AlertDialog(
            title: Text(dialog.l10n.addCare),
            content: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in CareInvitationMethod.values)
                          ChoiceChip(
                            key: Key('care-invite-${option.name}'),
                            label: Text(
                              option == CareInvitationMethod.memberId
                                  ? dialog.l10n.careMemberIdLabel
                                  : dialog.l10n.careContactLabel,
                            ),
                            selected: method == option,
                            onSelected: (_) => update(() {
                              method = option;
                              input.clear();
                              form.currentState?.reset();
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: input,
                      key: Key(
                        method == CareInvitationMethod.memberId
                            ? 'global-care-member-no'
                            : 'global-care-contact',
                      ),
                      keyboardType: method == CareInvitationMethod.memberId
                          ? TextInputType.number
                          : TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: method == CareInvitationMethod.memberId
                            ? dialog.l10n.careMemberIdLabel
                            : dialog.l10n.emailOrPhone,
                        helperText: method == CareInvitationMethod.memberId
                            ? dialog.l10n.careMemberIdHint
                            : null,
                        helperMaxLines: 2,
                      ),
                      validator: (value) {
                        try {
                          target();
                          return null;
                        } catch (_) {
                          return method == CareInvitationMethod.memberId
                              ? dialog.l10n.careInvalidMemberId
                              : dialog.l10n.invalidCareContact;
                        }
                      },
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
                onPressed: () {
                  if (form.currentState?.validate() == true) {
                    Navigator.pop(dialog, target());
                  }
                },
                child: Text(dialog.l10n.send),
              ),
            ],
          ),
        );
      },
    );
    _activeDialog = null;
    // Dialog animations can still refer to this controller until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
    if (value == null || !mounted || !_sameOwner || generation != _generation) {
      return;
    }
    await _operate(() async {
      await widget.controller.globalInviteCareTarget(value);
      if (mounted && _sameOwner && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.careRequestSubmitted)),
        );
      }
    });
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
        title: Text(
          row.status == 'pending'
              ? dialog.l10n.careCancelInvitation
              : dialog.l10n.stopSharing,
        ),
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
    final visible = _relationships
        .where((row) => row.received == _received)
        .toList();
    return Scaffold(
      key: const Key('global-care-page'),
      appBar: AppBar(
        title: Text(l.remoteCare),
        actions: [
          IconButton(
            key: const Key('global-care-add'),
            tooltip: l.addCare,
            onPressed: _working || !_sameOwner ? null : _invite,
            icon: const Icon(Icons.person_add_outlined),
          ),
        ],
      ),
      body: !_sameOwner
          ? Center(child: Text(l.signInCloudHint))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.careSummaryHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final received in [false, true])
                        ChoiceChip(
                          key: Key(
                            received
                                ? 'care-direction-followers'
                                : 'care-direction-following',
                          ),
                          label: Text(
                            '${received ? l.careFollowers : l.careFollowing} (${_relationships.where((r) => r.received == received).length})',
                          ),
                          selected: _received == received,
                          onSelected: (_) =>
                              setState(() => _received = received),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading || _working) const LinearProgressIndicator(),
                  if (_failed) ...[
                    Text(l.serviceUnavailable),
                    TextButton(onPressed: _load, child: Text(l.retry)),
                  ],
                  if (!_loading && !_failed && visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            _received ? l.careNoFollowers : l.careNoFollowing,
                          ),
                          if (!_received)
                            TextButton(
                              onPressed: _working ? null : _invite,
                              child: Text(l.addCare),
                            ),
                        ],
                      ),
                    ),
                  for (final row in visible) _memberCard(row),
                ],
              ),
            ),
    );
  }

  Widget _memberCard(GlobalCareRelationship row) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final name = row.name.trim().isEmpty ? l.defaultUser : row.name.trim();
    final pending = row.status == 'pending' && !row.expired;
    final status = row.active
        ? l.careActive
        : pending
        ? (row.received ? l.careAwaitingYourReview : l.careAwaitingTheirReview)
        : l.careClosed;
    return Card(
      key: ValueKey('care-member-${row.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Text(name.characters.first),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (row.memberNo != null)
                        Text(
                          'ID ${row.memberNo}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: row.active
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (row.received && pending) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _working
                        ? null
                        : () => _operate(
                            () => widget.controller.globalRespondCare(
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
                            () => widget.controller.globalRespondCare(
                              row.id,
                              false,
                            ),
                          ),
                    child: Text(l.decline),
                  ),
                ],
              ),
            ],
            if (row.active) ...[
              const SizedBox(height: 12),
              if (row.received)
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _permissions(row),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(l.sharedMeasurements),
                )
              else if (row.metrics.isEmpty)
                Text(
                  l.carePermissionDenied,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: ValueKey('care-view-${row.id}'),
                    onPressed: _working
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GlobalCareDashboard(
                                controller: widget.controller,
                                relationship: row,
                                owner: _owner!,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.favorite_outline_rounded),
                    label: Text(l.careViewHealth),
                  ),
                ),
            ],
            if (row.active || (pending && !row.received))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _working ? null : () => _revoke(row),
                  child: Text(pending ? l.careCancelInvitation : l.stopSharing),
                ),
              ),
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
