import 'dart:math' as math;

/// ECG samples prepared for display without inventing waveform data.
///
/// The SDK can return a long, high-frequency series containing occasional
/// transport spikes. A fixed-stride sample can repeatedly hit the same phase
/// of a periodic signal and make a valid waveform look flat. This helper uses
/// ordered min/max buckets so short QRS peaks survive downsampling, while
/// robust display bounds keep isolated transport spikes from flattening the
/// rest of the chart.
class EcgDisplayWaveform {
  const EcgDisplayWaveform({
    required this.samples,
    required this.minimum,
    required this.maximum,
    required this.hasVariation,
  });

  final List<double> samples;
  final double minimum;
  final double maximum;

  final bool hasVariation;
}

EcgDisplayWaveform prepareEcgDisplayWaveform(
  Iterable<num> source, {
  required int maximumPoints,
  int? sampleFrequency,
  bool removeContactArtifacts = false,
}) {
  final finiteValues = source
      .where((value) => value.isFinite && value.toInt() != 0x7fffffff)
      .map((value) => value.toDouble())
      .toList();
  var firstSignal = 0;
  while (firstSignal < finiteValues.length && finiteValues[firstSignal] == 0) {
    firstSignal++;
  }
  var lastSignal = finiteValues.length;
  while (lastSignal > firstSignal && finiteValues[lastSignal - 1] == 0) {
    lastSignal--;
  }
  var values = finiteValues.sublist(firstSignal, lastSignal);
  if (removeContactArtifacts && values.isNotEmpty) {
    values = _removeContactArtifacts(
      values,
      sampleFrequency: sampleFrequency ?? 250,
    );
  }
  if (values.isEmpty) {
    return const EcgDisplayWaveform(
      samples: [],
      minimum: 0,
      maximum: 0,
      hasVariation: false,
    );
  }

  final sorted = [...values]..sort();
  // Some Veepoo firmware sends short bursts of transport noise alongside an
  // otherwise usable ECG stream. Keeping 99% of the numeric range lets those
  // bursts dominate the chart and compresses the actual ECG to a flat-looking
  // line. Prefer the central 90% for display, but fall back to the wider range
  // when the signal is mostly a constant baseline with narrow real peaks.
  final centralLower = _percentile(sorted, 0.05);
  final centralUpper = _percentile(sorted, 0.95);
  final quartileLower = _percentile(sorted, 0.25);
  final quartileUpper = _percentile(sorted, 0.75);
  final wideLower = _percentile(sorted, 0.005);
  final wideUpper = _percentile(sorted, 0.995);
  final rawMinimum = sorted.first;
  final rawMaximum = sorted.last;
  final quartileRange = quartileUpper - quartileLower;
  final centralRange = centralUpper - centralLower;
  final displayLower = quartileRange > 0 ? quartileLower : centralLower;
  final displayUpper = quartileRange > 0 ? quartileUpper : centralUpper;
  final displayRange = quartileRange > 0 ? quartileRange : centralRange;
  final robustMinimum = displayRange > 0
      ? math.max(wideLower, displayLower - displayRange * 4)
      : wideUpper > wideLower
      ? wideLower
      : rawMinimum;
  final robustMaximum = displayRange > 0
      ? math.min(wideUpper, displayUpper + displayRange * 4)
      : wideUpper > wideLower
      ? wideUpper
      : rawMaximum;
  final clipped = values
      .map((value) => value.clamp(robustMinimum, robustMaximum).toDouble())
      .toList(growable: false);

  final target = math.max(2, maximumPoints);
  final display = clipped.length <= target
      ? clipped
      : _orderedMinMaxBuckets(clipped, target);
  final minimum = display.reduce(math.min);
  final maximum = display.reduce(math.max);
  return EcgDisplayWaveform(
    samples: display,
    minimum: minimum,
    maximum: maximum,
    hasVariation: _hasRepeatedVariation(values),
  );
}

/// Removes lead-contact settling artefacts from calibrated mV values.
///
/// Veepoo starts streaming ADC values before the finger/electrode contact has
/// fully settled. Those samples can alternate between the converter rails and
/// look like an ECG even though they are only transport/contact artefacts. The
/// medical values and stored raw samples remain unchanged; this routine is
/// exclusively for displaying already calibrated data.
List<double> _removeContactArtifacts(
  List<double> values, {
  required int sampleFrequency,
}) {
  if (values.length < 16) return values;
  final sorted = [...values]..sort();
  final baseline = _percentile(sorted, 0.5);
  const maximumDisplayDeviationMv = 3.0;
  final valid = values
      .map((value) => (value - baseline).abs() <= maximumDisplayDeviationMv)
      .toList(growable: false);
  final window = math.min(
    values.length,
    math.max(16, (sampleFrequency.clamp(50, 1000) * 0.4).round()),
  );
  final minimumValid = math.max(1, (window * 0.95).ceil());

  int? stableStart;
  var validCount = 0;
  for (var index = 0; index < values.length; index++) {
    if (valid[index]) validCount++;
    if (index >= window && valid[index - window]) validCount--;
    if (index >= window - 1 && validCount >= minimumValid) {
      stableStart = index - window + 1;
      break;
    }
  }
  if (stableStart == null) return const [];

  int? stableEnd;
  validCount = 0;
  for (var index = values.length - 1; index >= stableStart; index--) {
    if (valid[index]) validCount++;
    final trailingIndex = index + window;
    if (trailingIndex < values.length && valid[trailingIndex]) validCount--;
    if (index + window <= values.length && validCount >= minimumValid) {
      stableEnd = index + window;
      break;
    }
  }
  if (stableEnd == null || stableEnd <= stableStart) return const [];

  final cleaned = values.sublist(stableStart, stableEnd);
  final cleanedValid = valid.sublist(stableStart, stableEnd);
  var index = 0;
  while (index < cleaned.length) {
    if (cleanedValid[index]) {
      index++;
      continue;
    }
    final runStart = index;
    while (index < cleaned.length && !cleanedValid[index]) {
      index++;
    }
    final previous = runStart > 0 ? cleaned[runStart - 1] : baseline;
    final next = index < cleaned.length ? cleaned[index] : previous;
    final runLength = index - runStart;
    for (var offset = 0; offset < runLength; offset++) {
      final fraction = (offset + 1) / (runLength + 1);
      cleaned[runStart + offset] = previous + (next - previous) * fraction;
    }
  }
  return cleaned;
}

bool _hasRepeatedVariation(List<double> values) {
  if (values.length < 2) return false;
  if (values.length < 16) {
    return values.reduce(math.max) != values.reduce(math.min);
  }
  final windowSize = math.max(8, (values.length / 20).ceil());
  var windows = 0;
  var varyingWindows = 0;
  var changedSamples = 0;
  for (var index = 1; index < values.length; index++) {
    if (values[index] != values[index - 1]) changedSamples++;
  }
  for (var start = 0; start < values.length; start += windowSize) {
    final end = math.min(values.length, start + windowSize);
    var minimum = values[start];
    var maximum = values[start];
    for (var index = start + 1; index < end; index++) {
      minimum = math.min(minimum, values[index]);
      maximum = math.max(maximum, values[index]);
    }
    windows++;
    if (maximum != minimum) varyingWindows++;
  }
  final changeRatio = changedSamples / (values.length - 1);
  return varyingWindows >= math.max(2, (windows * 0.2).ceil()) &&
      changeRatio >= 0.05;
}

List<double> _orderedMinMaxBuckets(List<double> values, int maximumPoints) {
  final bucketCount = math.max(1, maximumPoints ~/ 2);
  final bucketSize = values.length / bucketCount;
  final result = <double>[];
  for (var bucket = 0; bucket < bucketCount; bucket++) {
    final start = (bucket * bucketSize).floor();
    final end = math.min(values.length, ((bucket + 1) * bucketSize).ceil());
    if (start >= end) continue;
    var minimum = values[start];
    var maximum = values[start];
    var minimumIndex = start;
    var maximumIndex = start;
    for (var index = start + 1; index < end; index++) {
      final value = values[index];
      if (value < minimum) {
        minimum = value;
        minimumIndex = index;
      }
      if (value > maximum) {
        maximum = value;
        maximumIndex = index;
      }
    }
    if (minimumIndex <= maximumIndex) {
      result.add(minimum);
      if (maximumIndex != minimumIndex) result.add(maximum);
    } else {
      result.add(maximum);
      result.add(minimum);
    }
  }
  return result;
}

double _percentile(List<double> sorted, double percentile) {
  if (sorted.length == 1) return sorted.single;
  final position = (sorted.length - 1) * percentile;
  final lowerIndex = position.floor();
  final upperIndex = position.ceil();
  if (lowerIndex == upperIndex) return sorted[lowerIndex];
  final fraction = position - lowerIndex;
  return sorted[lowerIndex] * (1 - fraction) + sorted[upperIndex] * fraction;
}
