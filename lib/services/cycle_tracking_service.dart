import '../l10n/global_locale_controller.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../domain/cycle_tracking.dart';
import '../domain/models.dart';
import 'local_health_store.dart';

bool _sameCycleData(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length &&
    a.keys.every(
      (k) =>
          b.containsKey(k) &&
          (a[k] is List && b[k] is List
              ? listEquals(a[k] as List, b[k] as List)
              : a[k] == b[k]),
    );

abstract interface class CycleRemote {
  Future<Map<String, Object?>> cycleRequest(
    String owner,
    String method,
    String path, {
    Map<String, Object?> body = const {},
  });
}

/// 普通日程，与红屏/报警音/戒指振动的异常提醒通道完全独立。
class CycleNotifications {
  static const channel = MethodChannel('cn.saydian.ring/cycle');
  Future<void> owner(String? value) async {
    try {
      await channel.invokeMethod<void>('owner', {'owner': value});
    } on MissingPluginException {
      /* 宿主没有通知能力。 */
    }
  }

  Future<bool> schedule(
    String owner,
    List<Map<String, Object?>> plans, {
    bool request = false,
  }) async {
    try {
      return await channel.invokeMethod<bool>('schedule', {
            'owner': owner,
            'plans': plans,
            'request': request,
            'locale': GlobalLocaleController.instance.locale.toLanguageTag(),
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> opened(String owner) async {
    try {
      return await channel.invokeMethod<bool>('consumeOpen', {
            'owner': owner,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

class CycleTrackingService extends ChangeNotifier {
  CycleTrackingService(
    this.store, {
    this.remote,
    CycleNotifications? notifications,
    DateTime Function()? clock,
  }) : notifications = notifications ?? CycleNotifications(),
       clock = clock ?? DateTime.now;
  final CycleStore? store;
  final CycleRemote? remote;
  final CycleNotifications notifications;
  final DateTime Function() clock;
  String? _owner;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _queue = Future.value();
  final Map<String, CycleEntry> _rows = {};
  int _cursor = 0;
  int _epoch = 0;
  int _cursorSchema = 1;
  bool _symptomSync = false;
  bool busy = false,
      loaded = false,
      notificationAccepted = false,
      notificationOptIn = false;
  String status = '';
  List<CycleNightFeature> nights = [];
  Map<String, Object?>? report, availability;
  String get today => cycleDate(clock());
  String? get owner => _owner;
  int get contextRevision => _generation;
  bool get available => _owner != null && store != null;
  CycleSettings get settings => _rows['settings']?.deleted == false
      ? CycleSettings.fromJson(_rows['settings']!.data)
      : const CycleSettings();
  List<CycleEntry> get entries =>
      _rows.values.where((e) => e.kind != 'settings' && !e.deleted).toList()
        ..sort((a, b) => b.start.compareTo(a.start));
  List<CycleEntry> get conflicts =>
      _rows.values.where((e) => e.conflict != null).toList();
  CyclePrediction get prediction => cyclePrediction(entries, settings, today);
  int get pendingCount => _rows.values.where((r) => r.pending).length;
  List<String> get explanation {
    final lines = cycleExplanation(
      prediction,
      nights.map((n) => n.date).toSet().length,
    );
    if (report?['sourceHash'] != _sourceHash) return lines;
    final action = report?['action'];
    lines[2] = switch (action) {
      'prepare' => '可以按参考范围提前准备，并继续记录实际日期。',
      'check_records' => '请核对最近一次实际经期日期，补充或修改记录。',
      'keep_wearing' => '继续佩戴戒指入睡，积累可用的夜间趋势。',
      _ => lines[2],
    };
    return lines;
  }

  bool get currentAiReport =>
      report?['aiGenerated'] == true && report?['sourceHash'] == _sourceHash;
  String get _sourceHash {
    final rows = _rows.values.map((r) => r.toJson()).toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'date': today,
              'rows': rows,
              'nights': nights.map((n) => n.toJson()).toList(),
            }),
          ),
        )
        .toString();
  }

  bool _current(int g, String o) =>
      !_disposed && g == _generation && o == _owner;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setOwner(String? owner) {
    if (_owner == owner) return;
    _generation++;
    _owner = owner;
    _rows.clear();
    _erasePending = false;
    _cursor = 0;
    _epoch = 0;
    _cursorSchema = 1;
    _symptomSync = false;
    loaded = false;
    busy = false;
    report = null;
    availability = null;
    nights = [];
    status = '';
    notificationOptIn = false;
    notificationAccepted = false;
    unawaited(notifications.owner(owner).catchError((Object _) {}));
  }

  Future<T> _serial<T>(Future<T> Function(int g, String o) operation) {
    final g = _generation, o = _owner;
    if (o == null || store == null) return Future.error(StateError('请先登录账号'));
    final c = Completer<T>();
    _queue = _queue.catchError((_) {}).then((_) async {
      try {
        if (!_current(g, o)) throw StateError('账号已变化');
        c.complete(await operation(g, o));
      } catch (e, s) {
        c.completeError(e, s);
      }
    });
    return c.future;
  }

  Future<void> load() => _serial((g, o) async {
    final saved = await store!.cycleRows(o);
    if (!_current(g, o)) return;
    _rows.clear();
    for (final raw in saved) {
      if (raw['id'] == 'cursor') {
        _cursor = (raw['value'] as num?)?.toInt() ?? 0;
        _epoch = (raw['epoch'] as num?)?.toInt() ?? 0;
        _cursorSchema = raw['schemaVersion'] == 2 ? 2 : 1;
        continue;
      }
      if (raw['id'] == 'device-notifications') {
        notificationOptIn = raw['value'] == true;
        continue;
      }
      if (raw['id'] == 'latest-report') {
        report = Map<String, Object?>.from(raw['value'] as Map);
        continue;
      }
      if (raw['id'] == 'erase-pending') {
        _erasePending = true;
        continue;
      }
      if (raw['kind'] != null) {
        final row = CycleEntry.fromJson(raw);
        _rows[row.id] = row;
      }
    }
    loaded = true;
    _notify();
    await _sync(g, o);
  });
  Future<void> saveSettings(CycleSettings value) =>
      save(CycleEntry(id: 'settings', kind: 'settings', data: value.toJson()));
  Future<void> save(CycleEntry value) => _serial((g, o) async {
    if (value.kind == 'settings') {
      final s = CycleSettings.fromJson(value.data);
      if (s.enabled && (!s.adultConfirmed || !s.purposeAccepted)) {
        throw const FormatException('请先确认成年和数据用途');
      }
    } else {
      if (!settings.enabled) throw const FormatException('请先开启生理周期');
      if (!value.deleted) validateCycleEntry(value, entries, today);
    }
    final old = _rows[value.id];
    // 同一天重复保存不建立新修订，未填写也不变成“无”。
    if (old != null &&
        !value.deleted &&
        !old.deleted &&
        old.kind == value.kind &&
        _sameCycleData(old.data, value.data)) {
      return;
    }
    final row = CycleEntry(
      id: value.id,
      kind: value.kind,
      data: value.deleted ? const {} : value.data,
      revision: old?.revision ?? 0,
      deleted: value.deleted,
      pending: true,
      mutationId: const Uuid().v4(),
    );
    await store!.putCycleRow(o, row.id, row.toJson());
    if (!_current(g, o)) return;
    _rows[row.id] = row;
    report = null;
    await _snapshot(o);
    await _reschedule(o);
    _notify();
    await _sync(g, o);
  });
  Future<void> resolve(CycleEntry row, bool useLocal) => _serial((g, o) async {
    final conflict = row.conflict;
    if (conflict == null) return;
    final server = CycleEntry.fromJson(conflict);
    final next = useLocal
        ? CycleEntry(
            id: row.id,
            kind: row.kind,
            data: row.data,
            revision: server.revision,
            deleted: row.deleted,
            pending: true,
            mutationId: const Uuid().v4(),
          )
        : server;
    if (!next.deleted && next.kind != 'settings') {
      validateCycleEntry(next, entries, today);
    }
    await store!.putCycleRow(o, next.id, next.toJson());
    if (!_current(g, o)) return;
    _rows[next.id] = next;
    report = null;
    await _reschedule(o);
    _notify();
    await _sync(g, o);
  });
  Future<void> sync() => _serial(_sync);
  bool _erasePending = false;
  Future<void> _sync(int g, String o) async {
    if (remote == null || !_current(g, o)) {
      status = '已存本机';
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      if (_erasePending) {
        await remote!.cycleRequest(
          o,
          'POST',
          'erase',
          body: {'confirmed': true},
        );
        if (!_current(g, o)) return;
        await store!.clearCycleRows(o);
        _rows.clear();
        _cursor = 0;
        _erasePending = false;
      }
      await _pull(g, o);
      if (!_current(g, o)) return;
      final pending =
          _rows.values
              .where(
                (r) =>
                    r.pending &&
                    r.conflict == null &&
                    (_symptomSync || !r.data.containsKey('symptoms')),
              )
              .toList()
            ..sort(
              (a, b) => a.kind == 'settings'
                  ? -1
                  : b.kind == 'settings'
                  ? 1
                  : a.id.compareTo(b.id),
            );
      for (var offset = 0; offset < pending.length; offset += 40) {
        final batch = pending.skip(offset).take(40);
        final response = await remote!.cycleRequest(
          o,
          'POST',
          'sync',
          body: {
            if (_symptomSync) 'schemaVersion': 2,
            'offsetMinutes': clock().timeZoneOffset.inMinutes,
            'epoch': _epoch,
            'rows': [
              for (final r in batch)
                {
                  'id': r.id,
                  'kind': r.kind,
                  'data': r.data,
                  'deleted': r.deleted,
                  'baseRevision': r.revision,
                  'mutationId': r.mutationId,
                },
            ],
          },
        );
        if (!_current(g, o)) return;
        for (final raw in response['results'] as List) {
          final result = Map<String, Object?>.from(raw as Map),
              old = _rows[result['id']];
          if (old == null ||
              !old.pending ||
              !batch.any((r) => r.id == old.id)) {
            continue;
          }
          if (result['row'] is Map) {
            final row = CycleEntry.fromJson(
              Map<String, Object?>.from(result['row'] as Map),
            );
            if (result['mutationId'] != old.mutationId ||
                row.id != old.id ||
                row.kind != old.kind ||
                row.deleted != old.deleted ||
                row.revision <= old.revision ||
                (old.data.containsKey('symptoms') &&
                    (!listEquals(
                      row.data['symptoms'] as List?,
                      old.data['symptoms'] as List?,
                    )))) {
              continue;
            }
            _rows[row.id] = row;
            await store!.putCycleRow(o, row.id, row.toJson());
          } else if (result['conflict'] is Map) {
            final row = old.copy(
              conflict: Map<String, Object?>.from(result['conflict'] as Map),
            );
            _rows[row.id] = row;
            await store!.putCycleRow(o, row.id, row.toJson());
          }
        }
      }
      if (!_current(g, o)) return;
      await _pull(g, o);
      if (!_current(g, o)) return;
      status = conflicts.isNotEmpty
          ? '有不同版本，请选择保留哪份记录'
          : pendingCount > 0
          ? '已存本机'
          : '已同步';
      if (report?['sourceHash'] != _sourceHash) report = null;
      await _snapshot(o);
      await _reschedule(o);
    } catch (_) {
      if (_current(g, o)) status = '已存本机';
    } finally {
      if (_current(g, o)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _pull(int g, String o) async {
    bool more = true;
    while (more) {
      final response = await remote!.cycleRequest(
        o,
        'GET',
        'changes?cursor=$_cursor&schemaVersion=2',
      );
      if (!_current(g, o)) return;
      _symptomSync = response['schemaVersion'] == 2;
      // 旧游标只见过精简数据。升版从头读一次，不清掉本机的离线修订。
      if (_symptomSync && _cursorSchema != 2 && _cursor > 0) {
        _cursor = 0;
        _cursorSchema = 2;
        continue;
      }
      _cursorSchema = _symptomSync ? 2 : 1;
      final epoch = (response['epoch'] as num?)?.toInt() ?? 0;
      if (epoch != _epoch) {
        await store!.clearCycleRows(o);
        if (!_current(g, o)) return;
        _rows.clear();
        report = null;
        notificationOptIn = false;
        _epoch = epoch;
      }
      for (final raw in response['rows'] as List) {
        final row = CycleEntry.fromJson(Map<String, Object?>.from(raw as Map));
        final local = _rows[row.id];
        if (local?.pending == true) {
          if (row.revision > local!.revision) {
            // 提交已落库但回执丢失：保留原 mutationId 重放，不能把自己写的同一版当成冲突。
            if (row.revision == local.revision + 1 &&
                row.kind == local.kind &&
                row.deleted == local.deleted &&
                _sameCycleData(row.data, local.data)) {
              continue;
            }
            final conflict = local.copy(conflict: row.toJson());
            _rows[row.id] = conflict;
            await store!.putCycleRow(o, row.id, conflict.toJson());
          }
          continue;
        }
        // 降级或滚动发布时，精简响应里缺字段并不意味着用户清除了感受。
        final kept =
            !_symptomSync &&
                !row.deleted &&
                local?.data.containsKey('symptoms') == true
            ? CycleEntry(
                id: row.id,
                kind: row.kind,
                revision: row.revision,
                data: {...row.data, 'symptoms': local!.data['symptoms']},
              )
            : row;
        _rows[row.id] = kept;
        await store!.putCycleRow(o, row.id, kept.toJson());
      }
      _cursor = (response['cursor'] as num).toInt();
      more = response['hasMore'] == true;
      await store!.putCycleRow(o, 'cursor', {
        'id': 'cursor',
        'value': _cursor,
        'schemaVersion': _cursorSchema,
        'epoch': _epoch,
      });
    }
  }

  Future<void> _snapshot(String o) async {
    final p = prediction;
    final id =
        'snapshot-${sha256.convert(utf8.encode(jsonEncode(p.toJson())))}';
    // 内容寻址快照不覆盖；源记录修订号在basis中。
    await store!.putCycleRow(o, id, {'id': id, 'value': p.toJson()});
  }

  void updateHealth(List<HealthRecord> records) {
    nights = cycleNightFeatures(records);
    _notify();
  }

  Future<void> enableNotifications(bool enabled) => _serial((g, o) async {
    notificationOptIn = enabled;
    await store!.putCycleRow(o, 'device-notifications', {
      'id': 'device-notifications',
      'value': enabled,
    });
    await _reschedule(o, request: enabled);
    _notify();
  });

  /// 系统语言变化时只重排原有通知，不申请权限、不更改用户提醒偏好。
  Future<void> refreshNotificationLanguage() async {
    if (_disposed || !loaded || _owner == null || store == null) return;
    await _serial((g, o) async {
      if (_current(g, o)) await _reschedule(o);
    });
  }

  Future<void> _reschedule(String o, {bool request = false}) async {
    if (o != _owner) return;
    final generation = _generation;
    final s = settings, p = prediction, plans = <Map<String, Object?>>[];
    if (s.enabled && notificationOptIn) {
      // 提醒按本地日历排期。夏令时切换时，经过 24 小时不一定是次日同一时刻。
      final now = clock(), today = cycleDate(now);
      final dates = <String>{};
      if (s.remind && p.status == 'reference') {
        dates.add(shiftCycleDate(p.from!, -s.leadDays));
      }
      if (s.recordRemind) {
        for (var i = 0; i < 30; i++) {
          dates.add(shiftCycleDate(today, i));
        }
      }
      for (final date in dates) {
        final d = parseCycleDate(date),
            at = DateTime(d.year, d.month, d.day, s.hour, s.minute);
        if (at.isAfter(now)) {
          plans.add({
            'id':
                'cycle-${sha256.convert(utf8.encode('$o|$date|${s.hour}|${s.minute}'))}',
            'date': date,
            'hour': s.hour,
            'minute': s.minute,
          });
        }
      }
    }
    final accepted = await notifications.schedule(o, plans, request: request);
    // 系统许可弹窗可能跨过换号；旧结果不能更新新账号的通知状态。
    if (_current(generation, o)) notificationAccepted = accepted;
  }

  Future<void> readAiAvailability() => _serial((g, o) async {
    if (remote == null) return;
    try {
      final a = await remote!.cycleRequest(o, 'GET', 'ai-availability');
      if (_current(g, o)) {
        availability = a;
        _notify();
      }
    } catch (_) {
      if (_current(g, o)) {
        availability = null;
        _notify();
      }
    }
  });
  Future<void> consentAi(bool granted, String version) => _serial((g, o) async {
    if (remote == null) return;
    final a = await remote!.cycleRequest(
      o,
      'POST',
      'analysis-consent',
      body: {'granted': granted, 'version': version},
    );
    if (_current(g, o)) {
      availability = a;
      report = null;
      _notify();
    }
  });
  Future<void> explain() => _serial((g, o) async {
    await _sync(g, o);
    if (!_current(g, o) || remote == null || pendingCount > 0) return;
    final hash = _sourceHash;
    try {
      final value = await remote!.cycleRequest(
        o,
        'POST',
        'explanation',
        body: {'offsetMinutes': clock().timeZoneOffset.inMinutes},
      );
      if (!_current(g, o) || hash != _sourceHash) return;
      final p = value['prediction'] as Map?;
      if (p?['from'] != prediction.from ||
          p?['to'] != prediction.to ||
          p?['status'] != prediction.status) {
        return;
      }
      report = {...value, 'sourceHash': hash};
      await store!.putCycleRow(o, 'latest-report', {
        'id': 'latest-report',
        'value': report,
      });
      _notify();
    } catch (_) {
      /* 保留本地三句解释，不冒充AI生成。 */
    }
  });
  Future<void> erase() => _serial((g, o) async {
    // 删除待办先落库；网络失败不允许旧云历史重新显示。
    await store!.clearCycleRows(o);
    await store!.putCycleRow(o, 'erase-pending', {'id': 'erase-pending'});
    if (!_current(g, o)) return;
    _rows.clear();
    report = null;
    nights = [];
    _cursor = 0;
    _erasePending = true;
    notificationOptIn = false;
    await _reschedule(o);
    _notify();
    await _sync(g, o);
  });
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
