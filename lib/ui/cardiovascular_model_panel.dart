import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/cardiovascular_model.dart';
import 'ring_share_page.dart';

class CardiovascularModelPanel extends StatefulWidget {
  const CardiovascularModelPanel({super.key, this.analyze});
  final Future<CardiovascularModelReply> Function()? analyze;

  @override
  State<CardiovascularModelPanel> createState() =>
      _CardiovascularModelPanelState();
}

class _CardiovascularModelPanelState extends State<CardiovascularModelPanel> {
  late Future<CardiovascularModelReply>? response = widget.analyze?.call();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ringText(context, 'AI 趋势解读', 'AI trend analysis'),
              style: text.titleMedium,
            ),
            const SizedBox(height: 8),
            if (widget.analyze == null)
              Text(
                ringText(
                  context,
                  '登录后可查看 AI 趋势解读。',
                  'Sign in to see AI trend analysis.',
                ),
              )
            else
              FutureBuilder<CardiovascularModelReply>(
                future: response,
                builder: (c, snapshot) {
                  final result = snapshot.data;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Text(
                      ringText(
                        c,
                        '正在分析这段时间的记录…',
                        'Analyzing this period’s readings…',
                      ),
                    );
                  }
                  if (result == null) {
                    final error = snapshot.error;
                    final expired =
                        error is ApiException && error.statusCode == 401;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expired
                              ? ringText(
                                  c,
                                  '登录已过期，请重新登录。',
                                  'Your session expired. Please sign in again.',
                                )
                              : ringText(
                                  c,
                                  '暂时未取得 AI 解读。',
                                  'AI analysis is temporarily unavailable.',
                                ),
                        ),
                        if (!expired)
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: Text(ringText(c, '重新分析', 'Retry analysis')),
                            onPressed: () => setState(() {
                              response = widget.analyze!();
                            }),
                          ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.summary,
                        key: const Key('cardio-model-summary'),
                      ),
                      for (final entry in result.observations.entries) ...[
                        const SizedBox(height: 10),
                        Text(switch (entry.key) {
                          'heartRate' => ringText(
                            c,
                            '心率与血压',
                            'Heart rate and blood pressure',
                          ),
                          'sleep' => ringText(
                            c,
                            '睡眠与血压',
                            'Sleep and blood pressure',
                          ),
                          _ => ringText(c, '步数与血压', 'Steps and blood pressure'),
                        }, style: text.labelLarge),
                        Text(entry.value),
                      ],
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
