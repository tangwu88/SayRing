import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  appendSportRoutePoint, emptySportSession, routeDistanceKilometers,
  sportCapabilityFromFeatureList, sportModeFromProtocolValue, sportModeLabel,
  sportModeProtocolValue, sportRoutePolyline,
} from '../entry/src/main/ets/model/WearableContracts.ts';

test('sport capability keeps legacy mode control and enables pause only for realtime control', () => {
  assert.deepEqual(sportCapabilityFromFeatureList({ sportModeCount: 20 }), {
    modes: ['running'], supportsPause: false, protocol: 'mode',
  });
  assert.deepEqual(sportCapabilityFromFeatureList({ sportModeCount: 20, sportModeType: 1 }), {
    modes: ['running', 'walking', 'cycling', 'hiking'], supportsPause: false, protocol: 'mode',
  });
  assert.deepEqual(sportCapabilityFromFeatureList({ sportModeCount: 2, sportModeType: 1 }), {
    modes: ['running', 'walking'], supportsPause: false, protocol: 'mode',
  });
  assert.deepEqual(sportCapabilityFromFeatureList({ sportModeCount: 0, daSportControl: 1 }), {
    modes: [], supportsPause: false, protocol: 'none',
  });
  assert.deepEqual(sportCapabilityFromFeatureList({ sportModeCount: 20, sportModeType: 1, daSportControl: 1 }), {
    modes: ['running', 'walking', 'cycling', 'hiking'], supportsPause: true, protocol: 'realtime',
  });
});

test('Harmony sport types match the verified Veepoo values used by Android and iOS parity', () => {
  const modes = [['running', 1], ['walking', 2], ['hiking', 5], ['cycling', 7]];
  for (const [mode, value] of modes) {
    assert.equal(sportModeProtocolValue(mode), value);
    assert.equal(sportModeFromProtocolValue(value), mode);
    assert.notEqual(sportModeLabel(mode), '运动');
  }
  assert.equal(sportModeFromProtocolValue(99), '');
});

test('foreground route keeps only usable ordered points and computes a real shape', () => {
  const first = { latitude: 22.5431, longitude: 114.0579, timestamp: 1000, accuracy: 12 };
  let points = appendSportRoutePoint([], first);
  points = appendSportRoutePoint(points, { latitude: 22.5432, longitude: 114.0582, timestamp: 4000, accuracy: 15 });
  assert.equal(points.length, 2);
  assert.ok(routeDistanceKilometers(points) > 0);
  assert.equal(sportRoutePolyline(points, 280, 150).length, 2);
  assert.equal(appendSportRoutePoint(points, { latitude: 22.6, longitude: 114.1, timestamp: 3000, accuracy: 10 }), points);
  assert.equal(appendSportRoutePoint(points, { latitude: 22.6, longitude: 114.1, timestamp: 5000, accuracy: 200 }), points);
  assert.equal(appendSportRoutePoint(points, { latitude: 23.6, longitude: 115.1, timestamp: 5000, accuracy: 10 }), points);
});

test('empty sport state contains no fabricated watch or route values', () => {
  assert.deepEqual(emptySportSession(), {
    phase: 'idle', mode: '', startedAt: 0, observedAt: 0, durationSeconds: 0,
    distanceKm: 0, routeDistanceKm: 0, steps: 0, calories: 0, heartRate: 0,
    route: [], locationStatus: '', status: '',
  });
});

test('production service serializes sport commands and saves completed data once', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  assert.match(source, /sportService\.setControl\(sportModeProtocolValue\(mode\), code\)/);
  assert.match(source, /sportService\.setMode\(control, sportModeProtocolValue\(mode\)\)/);
  assert.match(source, /private sportSaved: boolean = false/);
  assert.match(source, /save && !this\.sportSaved/);
  assert.match(source, /record\.sport = \{/);
  assert.match(source, /geoLocationManager\.on\('locationChange'/);
  assert.match(source, /运动进行中，请先结束运动再操作手表/);
});
