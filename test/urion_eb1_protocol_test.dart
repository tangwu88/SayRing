import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/urion_eb1_protocol.dart';

void main() {
  test('short frame uses additive checksum, not sample annotation', () {
    final frame = Eb1Frame.request(0x16, [1]);
    expect(frame.bytes, [0x16, 1, ...List.filled(13, 0), 0x17]);
    expect(Eb1Frame.parse(frame.bytes), isNotNull);
    final wrong = [...frame.bytes]..[15] = 0x0a;
    expect(Eb1Frame.parse(wrong), isNull);
  });

  test('fragmented and joined notifications preserve 16-byte boundaries', () {
    final buffer = Eb1FrameBuffer();
    final first = Eb1Frame.request(0x03, [82]).bytes;
    final second = Eb1Frame.request(0x73, [2]).bytes;
    expect(buffer.add(first.sublist(0, 7)), isEmpty);
    expect(buffer.add([...first.sublist(7), ...second]).map((f) => f.command), [
      0x03,
      0x73,
    ]);
    final bad = [...first]..[15] = 0;
    expect(buffer.add(bad), isEmpty);
    expect(buffer.rejectedFrames, 1);
  });

  test('daily pair combines low/high calories and watch local date', () {
    final first = Eb1Frame.request(0x07, [
      0,
      0,
      0x25,
      0x01,
      0x21,
      0,
      0,
      0x59,
      0x0c,
      0x2b,
      0x03,
      0,
      0,
      0,
    ]);
    final second = Eb1Frame.request(0x07, [
      1,
      0,
      0x25,
      0x01,
      0x21,
      0x01,
      0xd5,
      0,
      0x6d,
      0x01,
      0x56,
      0,
      0x03,
      0,
    ]);
    final snapshot = Eb1DailySnapshot.parse(first, second);
    expect(snapshot.localDate, DateTime.utc(2025, 1, 21));
    expect(snapshot.steps, 89);
    expect(snapshot.sleepMinutes, 469);
    expect(snapshot.caloriesRaw, 3115);
    expect(snapshot.deepMinutes, 109);
    expect(snapshot.lightMinutes, 342);
    expect(snapshot.standingHours, 3);
  });

  test('blood pressure sentinel is not a zero-value measurement', () {
    final sentinel = Eb1Frame.request(0x14, [255, 255, 255, 255]);
    expect(Eb1BloodPressureSample.parse(sentinel), isNull);
    final sample = Eb1Frame.request(0x14, [
      0xf3,
      0xb5,
      0x8e,
      0x67,
      97,
      134,
      115,
    ]);
    expect(Eb1BloodPressureSample.parse(sample)?.systolic, 134);
    expect(Eb1BloodPressureSample.parse(sample)?.diastolic, 97);
  });

  test('pulse history validates scores, sentinel, and packet count', () {
    final sample = Eb1Frame.request(0x34, [1, 2, 3, 4, 3, 6, 2]);
    expect(Eb1PulseSample.parse(sample)?.bloodStasis, 3);
    expect(Eb1PulseSample.parse(sample)?.qiBlood, 6);
    expect(Eb1PulseSample.parse(sample)?.dampness, 2);
    expect(
      Eb1PulseSample.parse(Eb1Frame.request(0x34, [255, 255, 255, 255])),
      isNull,
    );
    expect(
      () =>
          Eb1PulseSample.parse(Eb1Frame.request(0x34, [1, 2, 3, 4, 11, 0, 0])),
      throwsFormatException,
    );
    final collector = Eb1ResponseCollector(0x34, count: 2);
    expect(collector.add(sample), isNull);
    expect(
      collector.add(Eb1Frame.request(0x34, [255, 255, 255, 255])),
      hasLength(1),
    );
  });

  test('dynamic pressure read and unsolicited change use the same layout', () {
    final read = Eb1DynamicBloodPressureSettings.parse(
      Eb1Frame.request(0x36, [1, 8, 60, 90]),
    );
    expect(read.enabled, isTrue);
    expect(read.startHour, 8);
    expect(read.dayIntervalMinutes, 60);
    expect(read.nightIntervalMinutes, 90);
    expect(read.payload, [1, 8, 60, 90]);
    expect(
      Eb1DynamicBloodPressureSettings.parse(
        Eb1Frame.request(0x37, [0, 8, 60, 90]),
      ).enabled,
      isFalse,
    );
    expect(
      () => Eb1DynamicBloodPressureSettings.parse(
        Eb1Frame.request(0x36, [1, 24, 60, 90]),
      ),
      throwsFormatException,
    );
    expect(
      () => Eb1DynamicBloodPressureSettings.parse(
        Eb1Frame.request(0x36, [1, 8, 0, 90]),
      ),
      throwsFormatException,
    );
  });

  test('five-packet oxygen layout cannot be decoded as hourly scalars', () {
    final frames = [
      Eb1Frame.request(0x2d, [0, 5, 60]),
      for (var index = 1; index < 5; index++)
        Eb1Frame.request(0x2d, [index, ...List.filled(13, 98)]),
    ];
    expect(
      () => Eb1IndexedDay(
        0x2d,
        frames,
      ).decodeHourlyOrFiveMinuteValues(expectedInterval: 60),
      throwsFormatException,
    );
  });

  test('BP count is bounded and its no-data sentinel ends a short history', () {
    final collector = Eb1ResponseCollector(0x14, count: 50);
    final sample = Eb1Frame.request(0x14, [1, 2, 3, 4, 80, 120, 65]);
    expect(collector.add(sample), isNull);
    final result = collector.add(Eb1Frame.request(0x14, [255, 255, 255, 255]));
    expect(result, hasLength(1));
    expect(Eb1ResponseCollector(0x14).add(sample), hasLength(1));
    expect(() => Eb1ResponseCollector(0x14, count: 51), throwsRangeError);
  });

  test(
    'indexed responses follow the header count and ignore exact repeats',
    () {
      final collector = Eb1ResponseCollector(0x2d);
      final header = Eb1Frame.request(0x2d, [0, 4, 60]);
      final first = Eb1Frame.request(0x2d, [
        1,
        1,
        2,
        3,
        4,
        ...List.filled(9, 98),
      ]);
      expect(collector.add(header), isNull);
      expect(collector.add(first), isNull);
      expect(collector.add(first), isNull);
      expect(
        collector.add(Eb1Frame.request(0x2d, [2, ...List.filled(13, 97)])),
        isNull,
      );
      final frames = collector.add(Eb1Frame.request(0x2d, [3, 96, 95]));
      expect(frames, hasLength(4));
      final values = Eb1IndexedDay(
        0x2d,
        frames!,
      ).decodeHourlyOrFiveMinuteValues(expectedInterval: 60);
      expect(values, hasLength(24));
      expect(values.take(9), everyElement(98));
      expect(values.sublist(22), [96, 95]);
    },
  );

  test(
    'indexed no-data completes while missing or conflicting packets fail',
    () {
      final noData = Eb1ResponseCollector(
        0x15,
      ).add(Eb1Frame.request(0x15, [255]));
      expect(
        Eb1IndexedDay(
          0x15,
          noData!,
        ).decodeHourlyOrFiveMinuteValues(expectedInterval: 5),
        isEmpty,
      );
      final missing = Eb1ResponseCollector(0x15);
      missing.add(Eb1Frame.request(0x15, [0, 24, 5]));
      expect(
        () => missing.add(Eb1Frame.request(0x15, [2])),
        throwsFormatException,
      );
      final conflicting = Eb1ResponseCollector(0x15);
      conflicting.add(Eb1Frame.request(0x15, [0, 24, 5]));
      expect(
        () => conflicting.add(Eb1Frame.request(0x15, [0, 24, 60])),
        throwsFormatException,
      );
    },
  );

  test(
    'a fresh timestamp proves its interpretation, not a fixed timezone shift',
    () {
      final start = DateTime.utc(2026, 9, 28, 12);
      final end = start.add(const Duration(minutes: 2));
      final raw =
          start.add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000;
      DateTime decode(int seconds, Eb1TimestampEncoding encoding) {
        final instant = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        );
        return encoding == Eb1TimestampEncoding.utc
            ? instant
            : instant.add(const Duration(hours: 4));
      }

      final proof = eb1MatchMeasurementTimestamp(
        raw,
        startedAt: start,
        endedAt: end,
        decode: decode,
      );
      expect(proof?.encoding, Eb1TimestampEncoding.utc);
      expect(proof?.measuredAt, start.add(const Duration(minutes: 1)));
      expect(
        eb1MatchMeasurementTimestamp(
          raw - 3600,
          startedAt: start,
          endedAt: end,
          decode: decode,
        ),
        isNull,
      );
      expect(
        eb1MatchMeasurementTimestamp(
          raw,
          startedAt: start,
          endedAt: end.add(const Duration(hours: 4)),
          decode: decode,
        ),
        isNull,
      );
    },
  );

  test('equal clock interpretations prove an instant but not an encoding', () {
    final now = DateTime.utc(2026, 9, 28, 12);
    final proof = eb1MatchMeasurementTimestamp(
      now.millisecondsSinceEpoch ~/ 1000,
      startedAt: now,
      endedAt: now.add(const Duration(seconds: 1)),
      decode: (seconds, _) =>
          DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    );
    expect(proof?.measuredAt, now);
    expect(proof?.encoding, isNull);
  });
}
