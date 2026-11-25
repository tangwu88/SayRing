import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/cardiovascular_model.dart';
import 'app_theme.dart';
import 'ring_share_page.dart';

class CardiovascularModelPanel extends StatefulWidget {
  const CardiovascularModelPanel({
    super.key,
    this.analyze,
    this.needsMoreDays = false,
  });
  final Future<CardiovascularModelReply> Function()? analyze;
  final bool needsMoreDays;

  @override
  State<CardiovascularModelPanel> createState() =>
      _CardiovascularModelPanelState();
}

class _CardiovascularModelPanelState extends State<CardiovascularModelPanel> {
  late Future<CardiovascularModelReply>? response = widget.analyze?.call();
  String? selectedMetric;

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c).textTheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: const Color(0xFFEDF4F3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.insights_outlined,
                  color: SaydianColors.techBlue,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ringText(c, 'AI 趋势解读', 'AI trend analysis'),
                    style: theme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (widget.needsMoreDays)
              Text(
                ringText(
                  c,
                  '多记录几天血压，再看趋势解读。',
                  'Record a few more days to see a trend.',
                ),
              )
            else if (widget.analyze == null)
              Text(ringText(c, '登录后可查看解读。', 'Sign in to see your analysis.'))
            else
              FutureBuilder<CardiovascularModelReply>(
                future: response,
                builder: (c, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Text(
                      ringText(
                        c,
                        '正在分析这段时间的记录…',
                        'Analyzing this period’s readings…',
                      ),
                    );
                  }
                  final result = snapshot.data;
                  if (result == null) {
                    final error = snapshot.error;
                    final expired =
                        error is ApiException && error.statusCode == 401;
                    return Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          expired
                              ? ringText(c, '请重新登录。', 'Please sign in again.')
                              : ringText(
                                  c,
                                  '解读暂不可用。',
                                  'Analysis is unavailable.',
                                ),
                        ),
                        if (!expired)
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 17),
                            label: Text(ringText(c, '重新分析', 'Retry analysis')),
                            onPressed: () => setState(() {
                              response = widget.analyze!();
                            }),
                          ),
                      ],
                    );
                  }
                  final observations = result.observations;
                  final active = observations.containsKey(selectedMetric)
                      ? selectedMetric
                      : observations.keys.firstOrNull;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        result.highlight ?? result.summary,
                        key: const Key('cardio-model-summary'),
                        style: theme.bodyLarge,
                      ),
                      if (active != null)
                        ExpansionTile(
                          key: const Key('cardio-model-details'),
                          tilePadding: EdgeInsets.zero,
                          dense: true,
                          minTileHeight: 48,
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(
                            ringText(c, '查看分项解读', 'Explore comparisons'),
                            style: theme.labelMedium,
                          ),
                          expandedCrossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            if (result.highlight != null &&
                                result.highlight != result.summary)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(result.summary),
                              ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final key in observations.keys)
                                  ChoiceChip(
                                    showCheckmark: false,
                                    label: Text(switch (key) {
                                      'heartRate' => ringText(
                                        c,
                                        '心率',
                                        'Heart rate',
                                      ),
                                      'sleep' => ringText(c, '睡眠', 'Sleep'),
                                      _ => ringText(c, '步数', 'Steps'),
                                    }),
                                    selected: active == key,
                                    onSelected: (_) =>
                                        setState(() => selectedMetric = key),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Semantics(
                              liveRegion: true,
                              child: Text(observations[active]!),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
