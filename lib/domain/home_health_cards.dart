import 'models.dart';

/// Display preferences only. Never changes records or device capabilities.
class HomeHealthCardLayout {
  HomeHealthCardLayout({
    Iterable<HealthMetric> order = defaultOrder,
    Iterable<HealthMetric> hidden = const [],
  }) : order = List.unmodifiable({
         ...order.where(defaultOrder.contains),
         ...defaultOrder,
       }),
       hidden = Set.unmodifiable(hidden.where(defaultOrder.contains));

  static const defaultOrder = [
    HealthMetric.bloodPressure,
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
    HealthMetric.bloodGlucose,
    HealthMetric.bodyTemperature,
    HealthMetric.ecg,
    HealthMetric.hrv,
    HealthMetric.stress,
    HealthMetric.bodyComposition,
    HealthMetric.bloodComposition,
    HealthMetric.sleep,
  ];

  final List<HealthMetric> order;
  final Set<HealthMetric> hidden;

  List<HealthMetric> get visible =>
      order.where((metric) => !hidden.contains(metric)).toList(growable: false);

  HomeHealthCardLayout setVisible(HealthMetric metric, bool show) =>
      HomeHealthCardLayout(
        order: order,
        hidden: show ? (hidden.toSet()..remove(metric)) : {...hidden, metric},
      );

  /// Reorder only this device's visible subset, preserving all other positions.
  HomeHealthCardLayout reorderVisible(List<HealthMetric> reordered) {
    final selected = reordered.toSet();
    if (selected.length != reordered.length ||
        selected.any((metric) => !visible.contains(metric))) {
      return this;
    }
    var index = 0;
    return HomeHealthCardLayout(
      order: order.map(
        (metric) => selected.contains(metric) ? reordered[index++] : metric,
      ),
      hidden: hidden,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'order': order.map((metric) => metric.wireName).toList(),
    'hidden': hidden.map((metric) => metric.wireName).toList(),
  };

  factory HomeHealthCardLayout.fromJson(Object? input) {
    if (input is! Map || input['schemaVersion'] != 1) {
      return HomeHealthCardLayout();
    }
    Iterable<HealthMetric> parse(Object? values) => values is List
        ? defaultOrder.where((metric) => values.contains(metric.wireName))
        : const [];
    final rawOrder = input['order'];
    final byName = {for (final metric in defaultOrder) metric.wireName: metric};
    return HomeHealthCardLayout(
      order: rawOrder is List
          ? rawOrder
                .whereType<String>()
                .where(byName.containsKey)
                .map((name) => byName[name]!)
          : defaultOrder,
      hidden: parse(input['hidden']),
    );
  }
}
