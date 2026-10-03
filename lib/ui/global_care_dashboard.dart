import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/global_care.dart';
import '../domain/models.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';
import '../services/health_view_data_source.dart';
import 'health_trend_page.dart';
import 'pages.dart' show HealthMetricCard;

class GlobalCareDashboard extends StatefulWidget {
  const GlobalCareDashboard({
    required this.controller,
    required this.relationship,
    required this.owner,
    super.key,
  });
  final AppController controller;
  final GlobalCareRelationship relationship;
  final String owner;
  @override
  State<GlobalCareDashboard> createState() => _GlobalCareDashboardState();
}

class _GlobalCareDashboardState extends State<GlobalCareDashboard> {
  late final CareHealthDataSource _source;
  DateTime _day = DateTime.now();
  Map<HealthMetric, List<HealthRecord>> _records = const {};
  bool _loading = true;
  bool _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _source = CareHealthDataSource(
      controller: widget.controller,
      owner: widget.owner,
      relationshipId: widget.relationship.id,
      label: widget.relationship.name,
    );
    _source.addListener(_changed);
    unawaited(_load());
  }

  void _changed() {
    if (!mounted || _source.valid) return;
    _generation++;
    setState(() {
      _records = const {};
      _loading = false;
    });
  }

  @override
  void dispose() {
    _generation++;
    _source.removeListener(_changed);
    _source.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _records = const {};
    });
    try {
      await _source.revalidate();
      final metrics = HealthMetric.values
          .where(
            (metric) => _source.metrics.contains(
              metric == HealthMetric.bodyTemperature
                  ? 'temperature'
                  : metric.wireName,
            ),
          )
          .toList();
      final start = DateTime(_day.year, _day.month, _day.day);
      final end = DateTime(_day.year, _day.month, _day.day + 1);
      final lists = await Future.wait(
        metrics.map((metric) => _source.load(metric, start, end)),
      );
      if (!mounted || generation != _generation || !_source.valid) return;
      setState(() {
        _records = {
          for (var i = 0; i < metrics.length; i++)
            metrics[i]: lists[i]
              ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt)),
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _records = const {};
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      key: const Key('global-care-dashboard'),
      appBar: AppBar(title: Text('${_source.label} · 健康')),
      body: !_source.valid
          ? Center(child: Text(l.carePermissionDenied))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(_day),
                    ),
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _day,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (!mounted || selected == null || !_source.valid) {
                        return;
                      }
                      setState(() => _day = selected);
                      await _load();
                    },
                  ),
                  if (_loading) const LinearProgressIndicator(),
                  if (_failed)
                    TextButton(onPressed: _load, child: const Text('加载失败，重试')),
                  if (!_loading && !_failed && _records.isEmpty)
                    Text(l.carePermissionDenied),
                  for (final entry in _records.entries) ...[
                    HealthMetricCard(
                      controller: widget.controller,
                      metric: entry.key,
                      record: entry.value.isEmpty ? null : entry.value.first,
                      records: entry.value,
                      readOnly: true,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HealthTrendPage(
                            controller: widget.controller,
                            metric: entry.key,
                            initialDate: _day,
                            dataSource: _source,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    l.healthDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}
