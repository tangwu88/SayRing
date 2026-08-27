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

/// Centers live calibrated ECG samples without smoothing them and marks
/// converter/contact excursions as gaps. Breaking the path at an invalid point
/// is important: clipping it to the chart edge creates a tall vertical line
/// that looks like a heartbeat even though the device did not report one.
List<double?> prepareLiveEcgTrace(
  Iterable<num> source, {
  double maximumDeviationMv = 2.5,
}) {
  final raw = source.toList(growable: false);
  final finite = raw
      .where((value) => value.isFinite && value.toInt() != 0x7fffffff)
      .map((value) => value.toDouble())
      .toList(growable: false);
  if (finite.isEmpty) return List<double?>.filled(raw.length, null);

  final sorted = [...finite]..sort();
  final middle = sorted.length ~/ 2;
  final baseline = sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
  return raw
      .map<double?>((sample) {
        if (!sample.isFinite || sample.toInt() == 0x7fffffff) return null;
        final centered = sample.toDouble() - baseline;
        return centered.abs() <= maximumDeviationMv ? centered : null;
      })
      .toList(growable: false);
}

/// Whether a calibrated wearable ECG contains a continuous, varying signal.
/// This reuses the report-quality checks so live completion and persisted
/// history never accept converter rails as a successful ECG trace.
bool hasUsableEcgSignal(Iterable<num> source, {required int sampleFrequency}) =>
    prepareEcgDisplayWaveform(
      source,
      maximumPoints: 1200,
      sampleFrequency: sampleFrequency,
      removeContactArtifacts: true,
    ).hasVariation;

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
  final effectiveSampleFrequency = (sampleFrequency ?? 250)
      .clamp(50, 1000)
      .toInt();
  if (removeContactArtifacts && values.isNotEmpty) {
    values = _removeContactArtifacts(
      values,
      sampleFrequency: effectiveSampleFrequency,
    );
    values = _trimConstantPadding(
      values,
      sampleFrequency: effectiveSampleFrequency,
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
    hasVariation: _hasRepeatedVariation(
      values,
      sampleFrequency: removeContactArtifacts ? effectiveSampleFrequency : null,
    ),
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
  const maximumDisplayDeviationMv = 2.5;
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
  final invalidCount = cleanedValid.where((sample) => !sample).length;
  if (invalidCount / cleanedValid.length > 0.05) return const [];
  if (_hasClippedRailPlateau(cleaned, sampleFrequency)) return const [];
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
  if (_hasImplausibleEcgJumps(cleaned)) return const [];
  if (_hasLongEcgRamp(cleaned, sampleFrequency)) return const [];
  return cleaned;
}

/// Rejects repeated sample-to-sample jumps that are too large for a calibrated
/// single-lead ECG. One isolated transport sample may still occur, but two or
/// more jumps above 2.0 mV indicate a broken/contact-saturated stream.
bool _hasImplausibleEcgJumps(List<double> values) {
  if (values.length < 3) return false;
  var implausibleJumps = 0;
  for (var index = 1; index < values.length; index++) {
    if ((values[index] - values[index - 1]).abs() > 2.0) {
      implausibleJumps++;
      if (implausibleJumps >= 2) return true;
    }
  }
  return false;
}

/// Detects the multi-hundred-millisecond triangular ramps produced by W9S
/// contact/converter artefacts. Quality analysis uses 20 ms block means only;
/// the stored and displayed samples are never smoothed or synthesized.
bool _hasLongEcgRamp(List<double> values, int sampleFrequency) {
  if (values.length < 32) return false;
  final frequency = sampleFrequency.clamp(50, 1000);
  final blockSize = math.max(1, frequency ~/ 50);
  final blocks = <double>[];
  for (var start = 0; start < values.length; start += blockSize) {
    final end = math.min(values.length, start + blockSize);
    var total = 0.0;
    for (var index = start; index < end; index++) {
      total += values[index];
    }
    blocks.add(total / (end - start));
  }
  if (blocks.length < 3) return false;

  final sorted = [...blocks]..sort();
  final centralSpan = _percentile(sorted, 0.95) - _percentile(sorted, 0.05);
  if (centralSpan <= 0) return false;
  final minimumDelta = math.max(0.002, centralSpan * 0.002);
  final maximumRampDelta = math.max(0.15, centralSpan * 0.15);
  final minimumSwing = math.max(0.8, centralSpan * 0.35);
  const minimumRampBlocks = 18; // 18 x 20 ms = 360 ms.
  var direction = 0;
  var runBlocks = 0;
  var runStart = blocks.first;
  for (var index = 1; index < blocks.length; index++) {
    final delta = blocks[index] - blocks[index - 1];
    if (delta.abs() > maximumRampDelta) {
      direction = 0;
      runBlocks = 0;
      runStart = blocks[index];
      continue;
    }
    final nextDirection = delta.abs() < minimumDelta ? 0 : (delta > 0 ? 1 : -1);
    if (nextDirection == 0) {
      direction = 0;
      runBlocks = 0;
      runStart = blocks[index];
      continue;
    }
    if (nextDirection != direction) {
      direction = nextDirection;
      runBlocks = 1;
      runStart = blocks[index - 1];
    } else {
      runBlocks++;
    }
    if (runBlocks >= minimumRampBlocks &&
        (blocks[index] - runStart).abs() >= minimumSwing) {
      return true;
    }
  }
  return false;
}

/// Detects converter clipping without treating a normal, flat ECG baseline as
/// saturation. A clipped W9S stream stays almost unchanged at its numeric
/// maximum or minimum for tens of milliseconds; a physiological peak normally
/// changes continuously even when it is visually rounded.
bool _hasClippedRailPlateau(List<double> values, int sampleFrequency) {
  if (values.length < 16) return false;
  final sorted = [...values]..sort();
  final lowerRail = _percentile(sorted, 0.01);
  final upperRail = _percentile(sorted, 0.99);
  final span = upperRail - lowerRail;
  if (span <= 0) return false;

  final railBand = math.max(1e-6, span * 0.01);
  final flatTolerance = math.max(1e-7, span * 0.0001);
  final minimumRun = math.max(
    6,
    (sampleFrequency.clamp(50, 1000) * 0.03).round(),
  );
  var upperRun = 0;
  var lowerRun = 0;
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    final isFlat =
        index == 0 || (value - values[index - 1]).abs() <= flatTolerance;
    upperRun = isFlat && value >= upperRail - railBand ? upperRun + 1 : 0;
    lowerRun = isFlat && value <= lowerRail + railBand ? lowerRun + 1 : 0;
    if (upperRun >= minimumRun || lowerRun >= minimumRun) return true;
  }
  return false;
}

/// Removes the constant padding that some W9S ECG callbacks append before or
/// after the measured signal. The retained samples are never synthesized or
/// rescaled; only a long unchanged edge run is discarded for display.
List<double> _trimConstantPadding(
  List<double> values, {
  required int sampleFrequency,
}) {
  if (values.length < 16) return values;
  final sorted = [...values]..sort();
  final centralSpan = _percentile(sorted, 0.95) - _percentile(sorted, 0.05);
  final tolerance = math.max(1e-6, centralSpan.abs() * 0.001);
  final minimumRun = math.max(16, (sampleFrequency * 0.5).round());

  var leadingRun = 1;
  while (leadingRun < values.length &&
      (values[leadingRun] - values[leadingRun - 1]).abs() <= tolerance) {
    leadingRun++;
  }
  var trailingRun = 1;
  while (trailingRun < values.length &&
      (values[values.length - trailingRun] -
                  values[values.length - trailingRun - 1])
              .abs() <=
          tolerance) {
    trailingRun++;
  }

  final start = leadingRun >= minimumRun ? leadingRun - 1 : 0;
  final end = trailingRun >= minimumRun
      ? values.length - trailingRun + 1
      : values.length;
  if (end - start < 16) return const [];
  return values.sublist(start, end);
}

bool _hasRepeatedVariation(List<double> values, {int? sampleFrequency}) {
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
  final hasDistributedChanges =
      varyingWindows >= math.max(2, (windows * 0.2).ceil()) &&
      changeRatio >= 0.05;
  if (!hasDistributedChanges || sampleFrequency == null) {
    return hasDistributedChanges;
  }
  if (!_hasContinuousSignal(values, sampleFrequency)) return false;
  return _significantTurnsPerSecond(values, sampleFrequency) >= 0.8;
}

bool _hasContinuousSignal(List<double> values, int sampleFrequency) {
  if (values.length < sampleFrequency) return true;
  final sorted = [...values]..sort();
  final centralSpan = _percentile(sorted, 0.95) - _percentile(sorted, 0.05);
  if (centralSpan <= 0) return false;
  final minimumRange = math.max(0.01, centralSpan * 0.05);
  final minimumWindowSamples = math.max(16, sampleFrequency ~/ 2);
  var windows = 0;
  var activeWindows = 0;
  for (var start = 0; start < values.length; start += sampleFrequency) {
    final end = math.min(values.length, start + sampleFrequency);
    if (end - start < minimumWindowSamples) continue;
    var minimum = values[start];
    var maximum = values[start];
    for (var index = start + 1; index < end; index++) {
      minimum = math.min(minimum, values[index]);
      maximum = math.max(maximum, values[index]);
    }
    windows++;
    if (maximum - minimum >= minimumRange) activeWindows++;
  }
  return windows == 0 || activeWindows >= (windows * 0.9).ceil();
}

double _significantTurnsPerSecond(List<double> values, int sampleFrequency) {
  if (values.length < 3) return 0;
  final sorted = [...values]..sort();
  final centralSpan = _percentile(sorted, 0.95) - _percentile(sorted, 0.05);
  if (centralSpan <= 0) return 0;
  final minimumSwing = math.max(0.002, centralSpan * 0.12);
  var pivot = values.first;
  var direction = 0;
  var turns = 0;
  for (var index = 1; index < values.length; index++) {
    final value = values[index];
    if (direction >= 0) {
      if (value > pivot) {
        pivot = value;
      } else if (pivot - value >= minimumSwing) {
        if (direction > 0) turns++;
        direction = -1;
        pivot = value;
      }
    } else if (value < pivot) {
      pivot = value;
    } else if (value - pivot >= minimumSwing) {
      turns++;
      direction = 1;
      pivot = value;
    }
  }
  final durationSeconds = (values.length - 1) / sampleFrequency;
  return durationSeconds > 0 ? turns / durationSeconds : 0;
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
