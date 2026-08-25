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
}
