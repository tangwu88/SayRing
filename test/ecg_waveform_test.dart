import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/ecg_waveform.dart';

void main() {
  test('min/max bucket downsampling keeps narrow ECG peaks', () {
    final samples = List<num>.generate(
      5000,
      (index) => 10 + (index % 20 < 10 ? index % 10 : 20 - index % 20),
    );
    for (var index = 80; index < samples.length; index += 160) {
      samples[index] = 90;
      samples[index + 1] = -40;
    }

    final waveform = prepareEcgDisplayWaveform(samples, maximumPoints: 240);

    expect(waveform.samples.length, lessThanOrEqualTo(240));
    expect(waveform.maximum, greaterThan(20));
    expect(waveform.minimum, lessThan(10));
    expect(waveform.hasVariation, isTrue);
  });

  test('isolated transport spike does not flatten normal signal', () {
    final samples = <num>[
      for (var index = 0; index < 2000; index++) index.isEven ? 98 : 102,
      1000000,
    ];

    final waveform = prepareEcgDisplayWaveform(samples, maximumPoints: 300);

    expect(waveform.maximum, lessThan(1000000));
    expect(waveform.minimum, 98);
    expect(waveform.maximum, 102);
    expect(waveform.hasVariation, isTrue);
  });

  test('recurring transport bursts do not flatten the ECG trace', () {
    final samples = List<num>.generate(44000, (index) {
      if (index % 80 == 0) return 50000;
      final phase = index % 120;
      if (phase < 6) return 130 + phase * 12;
      if (phase < 12) return 202 - (phase - 6) * 12;
      return 100 + (index % 9) - 4;
    });

    final waveform = prepareEcgDisplayWaveform(samples, maximumPoints: 1200);

    expect(waveform.maximum, lessThan(50000));
    expect(waveform.maximum - waveform.minimum, greaterThan(5));
    expect(waveform.hasVariation, isTrue);
  });

  test('dense high-amplitude transport noise does not dominate the chart', () {
    final samples = List<num>.generate(44000, (index) {
      if (index % 10 == 0) {
        return index.isEven ? 200000 : -200000;
      }
      final phase = index % 100;
      return phase < 50 ? -500 + phase * 20 : 500 - (phase - 50) * 20;
    });

    final waveform = prepareEcgDisplayWaveform(samples, maximumPoints: 1200);

    expect(waveform.minimum, greaterThan(-10000));
    expect(waveform.maximum, lessThan(10000));
    expect(waveform.maximum - waveform.minimum, greaterThan(500));
    expect(waveform.hasVariation, isTrue);
  });

  test('calibrated contact-settling rails are removed from display', () {
    final samples = <num>[
      for (var index = 0; index < 500; index++) index.isEven ? -18.0 : 21.0,
      for (var index = 0; index < 2500; index++)
        0.08 * math.sin(index / 11) +
            (index % 250 >= 40 && index % 250 < 48 ? 1.25 : 0),
    ];

    final waveform = prepareEcgDisplayWaveform(
      samples,
      maximumPoints: 1200,
      sampleFrequency: 250,
      removeContactArtifacts: true,
    );

    expect(waveform.samples, isNotEmpty);
    expect(waveform.minimum, greaterThan(-1));
    expect(waveform.maximum, lessThan(2));
    expect(waveform.hasVariation, isTrue);
  });

  test('contact artefact-only stream stays blank', () {
    final waveform = prepareEcgDisplayWaveform(
      <num>[for (var index = 0; index < 1000; index++) index.isEven ? -20 : 20],
      maximumPoints: 400,
      sampleFrequency: 250,
      removeContactArtifacts: true,
    );

    expect(waveform.samples, isEmpty);
    expect(waveform.hasVariation, isFalse);
  });

  test('slow saturated trace with constant tail is not shown as ECG', () {
    const frequency = 250;
    final samples = <num>[
      for (var index = 0; index < frequency * 40; index++)
        1.8 * math.sin(index / (frequency * 1.5)) +
            (index % (frequency * 4) == 0 ? 1.2 : 0) +
            (index.isEven ? 0.08 : -0.08),
      ...List<num>.filled(frequency * 40, 0.75),
    ];

    final waveform = prepareEcgDisplayWaveform(
      samples,
      maximumPoints: 1200,
      sampleFrequency: frequency,
      removeContactArtifacts: true,
    );

    expect(waveform.hasVariation, isFalse);
  });

  test('repeated calibrated ECG beats pass signal quality screening', () {
    const frequency = 250;
    final samples = List<num>.generate(frequency * 20, (index) {
      final phase = index % frequency;
      final baseline = 0.025 * math.sin(index / 9);
      if (phase >= 48 && phase < 53) {
        return baseline + (phase - 48) * 0.28;
      }
      if (phase >= 53 && phase < 58) {
        return baseline + (58 - phase) * 0.28;
      }
      return baseline;
    });

    final waveform = prepareEcgDisplayWaveform(
      samples,
      maximumPoints: 1200,
      sampleFrequency: frequency,
      removeContactArtifacts: true,
    );

    expect(waveform.samples, isNotEmpty);
    expect(waveform.hasVariation, isTrue);
  });

  test('W9S rail saturation with internal zero gaps stays blank', () {
    const frequency = 500;
    List<num> saturated(int seconds) => List<num>.generate(
      frequency * seconds,
      (index) => 2.95 * math.sin(index / 5),
    );
    final samples = <num>[
      ...saturated(2),
      ...List<num>.filled(frequency * 26, 0),
      ...saturated(20),
      ...List<num>.filled(frequency * 5, 0),
      ...saturated(20),
    ];

    final waveform = prepareEcgDisplayWaveform(
      samples,
      maximumPoints: 1200,
      sampleFrequency: frequency,
      removeContactArtifacts: true,
    );

    expect(waveform.samples, isEmpty);
    expect(waveform.hasVariation, isFalse);
  });

  test('W9S clipped triangle with rail plateaus stays blank', () {
    const frequency = 500;
    final samples = List<num>.generate(frequency * 20, (index) {
      final phase = index % frequency;
      if (phase < 40) return 2.0;
      if (phase < 250) return 2.0 - (phase - 40) * 4.0 / 210;
      if (phase < 290) return -2.0;
      return -2.0 + (phase - 290) * 4.0 / 210;
    });

    final waveform = prepareEcgDisplayWaveform(
      samples,
      maximumPoints: 1200,
      sampleFrequency: frequency,
      removeContactArtifacts: true,
    );

    expect(waveform.samples, isEmpty);
    expect(waveform.hasVariation, isFalse);
  });

  test('long internal signal loss is not presented as continuous ECG', () {
    const frequency = 250;
    List<num> validSignal(int seconds) => List<num>.generate(
      frequency * seconds,
      (index) =>
          0.12 * math.sin(index / 9) +
          ((index % frequency) >= 48 && (index % frequency) < 58
              ? 1.1 * math.sin(((index % frequency) - 48) * math.pi / 10)
              : 0),
    );
    final samples = <num>[
      ...validSignal(20),
      ...List<num>.filled(frequency * 25, 0),
      ...validSignal(20),
    ];

    final waveform = prepareEcgDisplayWaveform(
      samples,
      maximumPoints: 1200,
      sampleFrequency: frequency,
      removeContactArtifacts: true,
    );

    expect(waveform.hasVariation, isFalse);
  });

  test('W9S ten-second internal dropout invalidates a 41-second trace', () {
    const frequency = 500;
    List<num> validSignal(int seconds) => List<num>.generate(
      frequency * seconds,
      (index) =>
          0.12 * math.sin(index / 9) +
          ((index % frequency) >= 95 && (index % frequency) < 115
              ? 1.1 * math.sin(((index % frequency) - 95) * math.pi / 20)
              : 0),
    );
    final samples = <num>[
      ...validSignal(5),
      ...List<num>.filled(frequency * 10, 0),
      ...validSignal(26),
    ];

    final waveform = prepareEcgDisplayWaveform(
      samples,
      maximumPoints: 1200,
      sampleFrequency: frequency,
      removeContactArtifacts: true,
    );

    expect(waveform.hasVariation, isFalse);
  });

  test('leading and trailing SDK zero padding is removed from display', () {
    final samples = <num>[
      ...List<num>.filled(5000, 0),
      for (var index = 0; index < 1000; index++) index.isEven ? 120 : -80,
      ...List<num>.filled(5000, 0),
    ];

    final waveform = prepareEcgDisplayWaveform(samples, maximumPoints: 2000);

    expect(waveform.samples, hasLength(1000));
    expect(waveform.samples.first, 120);
    expect(waveform.samples.last, -80);
    expect(waveform.hasVariation, isTrue);
  });

  test('narrow repeated peaks survive the central-range fallback', () {
    final samples = <num>[];
    for (var beat = 0; beat < 100; beat++) {
      samples.addAll(List<num>.filled(94, 100));
      samples.addAll(<num>[130, 160, 190, 160, 130, 70]);
    }

    final waveform = prepareEcgDisplayWaveform(samples, maximumPoints: 400);

    expect(waveform.minimum, lessThan(100));
    expect(waveform.maximum, greaterThan(100));
    expect(waveform.hasVariation, isTrue);
  });

  test('constant samples are identified as missing waveform variation', () {
    final waveform = prepareEcgDisplayWaveform(
      List<num>.filled(100, 7),
      maximumPoints: 40,
    );

    expect(waveform.hasVariation, isFalse);
  });

  test('a few isolated changes are not presented as a valid ECG trace', () {
    final samples = List<num>.filled(4000, 7);
    samples[100] = 9;
    samples[3800] = 5;

    final waveform = prepareEcgDisplayWaveform(samples, maximumPoints: 200);

    expect(waveform.hasVariation, isFalse);
  });

  test('sparse step changes across many windows are not an ECG trace', () {
    final samples = <num>[];
    for (var window = 0; window < 20; window++) {
      samples.addAll(List<num>.filled(200, window.isEven ? 7 : 8));
    }

    final waveform = prepareEcgDisplayWaveform(samples, maximumPoints: 200);

    expect(waveform.hasVariation, isFalse);
  });

  test('live ECG trace breaks contact rails instead of clipping them', () {
    final trace = prepareLiveEcgTrace(<num>[0, 0.1, 8, -8, 0.2, 0.15]);

    expect(trace[0], closeTo(-0.125, 0.0001));
    expect(trace[1], closeTo(-0.025, 0.0001));
    expect(trace[2], isNull);
    expect(trace[3], isNull);
    expect(trace[4], closeTo(0.075, 0.0001));
    expect(trace[5], closeTo(0.025, 0.0001));
  });

  test('usable ECG quality rejects a converter-rail stream', () {
    const frequency = 250;
    final invalid = List<num>.generate(
      frequency * 4,
      (index) => index.isEven ? -8 : 8,
    );
    final valid = List<num>.generate(
      frequency * 4,
      (index) =>
          0.08 * math.sin(index / 8) + (index % frequency == 40 ? 1.1 : 0),
    );

    expect(hasUsableEcgSignal(invalid, sampleFrequency: frequency), isFalse);
    expect(hasUsableEcgSignal(valid, sampleFrequency: frequency), isTrue);
  });
}
