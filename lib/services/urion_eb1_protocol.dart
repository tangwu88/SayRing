import 'dart:typed_data';

/// The EB1 short packet is 15 data bytes followed by an additive check byte.
/// It is not a CRC, despite the name used in parts of the supplier document.
class Eb1Frame {
  Eb1Frame._(this.bytes);

  static const length = 16;
  final Uint8List bytes;

  int get command => bytes[0];
  int operator [](int index) => bytes[index];

  static Eb1Frame request(int command, [List<int> payload = const []]) {
    if (command < 0 ||
        command > 255 ||
        payload.length > 14 ||
        payload.any((value) => value < 0 || value > 255)) {
      throw RangeError('Invalid EB1 request');
    }
    final bytes = Uint8List(length)..[0] = command;
    for (var index = 0; index < payload.length; index++) {
      bytes[index + 1] = payload[index];
    }
    bytes[15] = checksum(bytes);
    return Eb1Frame._(bytes);
  }

  static Eb1Frame? parse(List<int> raw) {
    if (raw.length != length || raw.any((value) => value < 0 || value > 255)) {
      return null;
    }
    if (checksum(raw) != raw[15]) return null;
    return Eb1Frame._(Uint8List.fromList(raw));
  }

  static int checksum(List<int> bytes) {
    if (bytes.length != length) throw RangeError('Invalid EB1 frame length');
    var sum = 0;
    for (var index = 0; index < 15; index++) {
      sum = (sum + bytes[index]) & 0xff;
    }
    return sum;
  }

  bool get isError => command >= 0x80 && command != 0xff;
  bool get isUnsupported => isError && bytes[1] == 0xee;
}

/// Notifications usually contain one frame, but neither notification
/// fragmentation nor coalescing may change the command stream's boundaries.
class Eb1FrameBuffer {
  final List<int> _pending = [];
  int rejectedFrames = 0;

  List<Eb1Frame> add(List<int> bytes) {
    _pending.addAll(bytes);
    final frames = <Eb1Frame>[];
    while (_pending.length >= Eb1Frame.length) {
      final frame = Eb1Frame.parse(_pending.sublist(0, Eb1Frame.length));
      _pending.removeRange(0, Eb1Frame.length);
      if (frame == null) {
        rejectedFrames++;
      } else {
        frames.add(frame);
      }
    }
    return frames;
  }

  void reset() => _pending.clear();
}

int eb1UnsignedLittle(Eb1Frame frame, int start, int count) {
  var value = 0;
  for (var offset = 0; offset < count; offset++) {
    value |= frame[start + offset] << (offset * 8);
  }
  return value;
}

int eb1UnsignedBig(Eb1Frame frame, int start, int count) {
  var value = 0;
  for (var offset = 0; offset < count; offset++) {
    value = (value << 8) | frame[start + offset];
  }
  return value;
}

int eb1Bcd(int byte) {
  final high = byte >> 4;
  final low = byte & 0x0f;
  if (high > 9 || low > 9) throw const FormatException('Invalid EB1 date');
  return high * 10 + low;
}

int eb1EncodeBcd(int value) {
  if (value < 0 || value > 99) throw RangeError('Invalid EB1 BCD value');
  return ((value ~/ 10) << 4) | value % 10;
}

/// One complete pair of 0x07 packets.  The date belongs to the watch, not to
/// the phone time at which this pair happened to be read.
class Eb1DailySnapshot {
  const Eb1DailySnapshot({
    required this.localDate,
    required this.daysAgo,
    required this.steps,
    required this.caloriesRaw,
    required this.standingHours,
    required this.distanceMeters,
    required this.sleepMinutes,
    required this.deepMinutes,
    required this.lightMinutes,
    required this.exerciseMinutes,
  });

  final DateTime localDate;
  final int daysAgo;
  final int steps;
  final int caloriesRaw;
  final int standingHours;
  final int distanceMeters;
  final int sleepMinutes;
  final int deepMinutes;
  final int lightMinutes;
  final int exerciseMinutes;

  static Eb1DailySnapshot parse(Eb1Frame first, Eb1Frame second) {
    if (first.command != 0x07 ||
        second.command != 0x07 ||
        first[1] != 0 ||
        second[1] != 1 ||
        first[2] != second[2] ||
        first[3] != second[3] ||
        first[4] != second[4] ||
        first[5] != second[5]) {
      throw const FormatException('Incomplete EB1 daily pair');
    }
    final year = 2000 + eb1Bcd(first[3]);
    final month = eb1Bcd(first[4]);
    final day = eb1Bcd(first[5]);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Invalid EB1 daily date');
    }
    return Eb1DailySnapshot(
      localDate: date,
      daysAgo: first[2],
      steps: eb1UnsignedBig(first, 6, 3),
      caloriesRaw: (second[14] << 16) | eb1UnsignedBig(first, 9, 2),
      standingHours: first[11],
      distanceMeters: eb1UnsignedBig(first, 12, 3),
      sleepMinutes: eb1UnsignedBig(second, 6, 2),
      deepMinutes: eb1UnsignedBig(second, 8, 2),
      lightMinutes: eb1UnsignedBig(second, 10, 2),
      exerciseMinutes: eb1UnsignedBig(second, 12, 2),
    );
  }
}

class Eb1BloodPressureSample {
  const Eb1BloodPressureSample({
    required this.rawTimestamp,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
  });

  final int rawTimestamp;
  final int systolic;
  final int diastolic;
  final int pulse;

  String get fingerprint => '$rawTimestamp|$systolic|$diastolic|$pulse';

  static Eb1BloodPressureSample? parse(Eb1Frame frame) {
    if (frame.command != 0x14) {
      throw const FormatException('Not an EB1 blood pressure packet');
    }
    final timestamp = eb1UnsignedLittle(frame, 1, 4);
    if (timestamp == 0xffffffff) return null;
    final diastolic = frame[5];
    final systolic = frame[6];
    final pulse = frame[7];
    if (timestamp == 0 ||
        diastolic == 0 ||
        systolic == 0 ||
        diastolic >= systolic ||
        pulse == 0) {
      throw const FormatException('Invalid EB1 blood pressure values');
    }
    return Eb1BloodPressureSample(
      rawTimestamp: timestamp,
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
    );
  }
}

class Eb1PulseSample {
  const Eb1PulseSample({
    required this.rawTimestamp,
    required this.bloodStasis,
    required this.qiBlood,
    required this.dampness,
  });

  final int rawTimestamp;
  final int bloodStasis;
  final int qiBlood;
  final int dampness;

  String get fingerprint => '$rawTimestamp|$bloodStasis|$qiBlood|$dampness';

  static Eb1PulseSample? parse(Eb1Frame frame) {
    if (frame.command != 0x34) {
      throw const FormatException('Not an EB1 pulse packet');
    }
    final timestamp = eb1UnsignedLittle(frame, 1, 4);
    if (timestamp == 0xffffffff) return null;
    if (timestamp == 0 || frame[5] > 10 || frame[6] > 10 || frame[7] > 10) {
      throw const FormatException('Invalid EB1 pulse values');
    }
    return Eb1PulseSample(
      rawTimestamp: timestamp,
      bloodStasis: frame[5],
      qiBlood: frame[6],
      dampness: frame[7],
    );
  }
}

class Eb1DynamicBloodPressureSettings {
  const Eb1DynamicBloodPressureSettings({
    required this.enabled,
    required this.startHour,
    required this.dayIntervalMinutes,
    required this.nightIntervalMinutes,
  });

  final bool enabled;
  final int startHour;
  final int dayIntervalMinutes;
  final int nightIntervalMinutes;

  static Eb1DynamicBloodPressureSettings parse(Eb1Frame frame) {
    if (frame.command != 0x36 && frame.command != 0x37) {
      throw const FormatException('Not an EB1 dynamic pressure packet');
    }
    if (frame[1] > 1 ||
        frame[2] > 23 ||
        (frame[1] == 1 && (frame[3] == 0 || frame[4] == 0))) {
      throw const FormatException('Invalid EB1 dynamic pressure settings');
    }
    return Eb1DynamicBloodPressureSettings(
      enabled: frame[1] == 1,
      startHour: frame[2],
      dayIntervalMinutes: frame[3],
      nightIntervalMinutes: frame[4],
    );
  }

  Map<String, Object?> toMap() => {
    'enabled': enabled,
    'startHour': startHour,
    'dayIntervalMinutes': dayIntervalMinutes,
    'nightIntervalMinutes': nightIntervalMinutes,
  };

  List<int> get payload => [
    enabled ? 1 : 0,
    startHour,
    dayIntervalMinutes,
    nightIntervalMinutes,
  ];
}

class Eb1IndexedDay {
  Eb1IndexedDay(this.command, this.frames);

  final int command;
  final List<Eb1Frame> frames;

  bool get hasNoData =>
      frames.length == 1 &&
      frames.single.command == command &&
      frames.single[1] == 0xff;

  int? get rawTimestamp => hasNoData || frames.length < 2
      ? null
      : eb1UnsignedLittle(frames[1], 2, 4);

  List<int> decodeHourlyOrFiveMinuteValues({required int expectedInterval}) {
    if (hasNoData) return const [];
    if (frames.isEmpty ||
        frames.first.command != command ||
        frames.first[1] != 0 ||
        frames.first[3] != expectedInterval) {
      throw const FormatException('Invalid EB1 indexed header');
    }
    final total = frames.first[2];
    if (total < 2 || total > 32 || frames.length != total) {
      throw const FormatException('Incomplete EB1 indexed day');
    }
    // A second five-packet oxygen layout is documented with different values.
    // Do not silently treat those min/max pairs as the hourly scalar layout.
    if (command == 0x2d && (expectedInterval != 60 || total != 4)) {
      throw const FormatException('Unverified EB1 oxygen layout');
    }
    final values = <int>[];
    for (var index = 1; index < total; index++) {
      final frame = frames[index];
      if (frame.command != command || frame[1] != index) {
        throw const FormatException('Out-of-order EB1 indexed packet');
      }
      values.addAll(frame.bytes.sublist(index == 1 ? 6 : 2, 15));
    }
    final expectedSlots = 1440 ~/ expectedInterval;
    if (values.length < expectedSlots) {
      throw const FormatException('Short EB1 indexed day');
    }
    return values.take(expectedSlots).toList(growable: false);
  }
}

/// Collects an entire response before releasing the single-command channel.
/// BP ends at the requested count or its sentinel; indexed data declares its
/// own packet count in the header. Repeated identical indexed packets are safe.
class Eb1ResponseCollector {
  Eb1ResponseCollector(this.command, {this.count = 1}) {
    if (count < 1 || count > 50) throw RangeError('Invalid EB1 response count');
  }

  final int command;
  final int count;
  final List<Eb1Frame> _frames = [];
  int? _indexedTotal;
  bool _complete = false;

  List<Eb1Frame>? add(Eb1Frame frame) {
    if (_complete) return null;
    if (frame.command != command) {
      throw const FormatException('Wrong EB1 response');
    }
    if (command == 0x14 || command == 0x34) {
      final sample = command == 0x14
          ? Eb1BloodPressureSample.parse(frame)
          : Eb1PulseSample.parse(frame);
      if (sample == null) return _finish();
      _frames.add(frame);
      return _frames.length == count ? _finish() : null;
    }
    final indexed = command == 0x15 || command == 0x2d;
    if (indexed && _frames.isEmpty) {
      if (frame[1] == 0xff) {
        _frames.add(frame);
        return _finish();
      }
      if (frame[1] != 0 || frame[2] < 2 || frame[2] > 32) {
        throw const FormatException('Invalid EB1 response header');
      }
      _indexedTotal = frame[2];
    }
    if (indexed || count > 1) {
      final index = frame[1];
      if (index < _frames.length) {
        final previous = _frames[index].bytes;
        if (List.generate(
          16,
          (i) => previous[i] == frame[i],
        ).every((same) => same)) {
          return null;
        }
        throw const FormatException('Conflicting EB1 repeated packet');
      }
      if (index != _frames.length) {
        throw const FormatException('Missing EB1 response packet');
      }
    }
    _frames.add(frame);
    return _frames.length == (_indexedTotal ?? count) ? _finish() : null;
  }

  List<Eb1Frame> _finish() {
    _complete = true;
    return List.unmodifiable(_frames);
  }
}

enum Eb1TimestampEncoding { utc, localWallClock }

DateTime eb1DecodeTimestamp(int seconds, Eb1TimestampEncoding encoding) {
  final raw = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  if (encoding == Eb1TimestampEncoding.utc) return raw;
  return DateTime(
    raw.year,
    raw.month,
    raw.day,
    raw.hour,
    raw.minute,
    raw.second,
  ).toUtc();
}

class Eb1TimestampMatch {
  const Eb1TimestampMatch(this.measuredAt, this.encoding);
  final DateTime measuredAt;
  final Eb1TimestampEncoding? encoding;
}

/// A new measurement is the only clock proof. Do not guess using old history
/// or apply a fixed timezone correction. At UTC both interpretations can name
/// the same instant: that instant is proven, but the encoding remains unknown.
Eb1TimestampMatch? eb1MatchMeasurementTimestamp(
  int rawTimestamp, {
  required DateTime startedAt,
  required DateTime endedAt,
  DateTime Function(int, Eb1TimestampEncoding) decode = eb1DecodeTimestamp,
}) {
  final firstSecond = DateTime.fromMillisecondsSinceEpoch(
    startedAt.millisecondsSinceEpoch ~/ 1000 * 1000,
    isUtc: true,
  );
  final matches = <Eb1TimestampEncoding, DateTime>{};
  for (final encoding in Eb1TimestampEncoding.values) {
    final instant = decode(rawTimestamp, encoding).toUtc();
    if (!instant.isBefore(firstSecond) && !instant.isAfter(endedAt.toUtc())) {
      matches[encoding] = instant;
    }
  }
  if (matches.isEmpty || matches.values.toSet().length != 1) return null;
  return Eb1TimestampMatch(
    matches.values.first,
    matches.length == 1 ? matches.keys.single : null,
  );
}
