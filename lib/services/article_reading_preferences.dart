import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'global_environment.dart';
import 'safe_secure_storage.dart';

enum ArticleTextSize {
  standard(18),
  large(22),
  extraLarge(26);

  const ArticleTextSize(this.points);
  final double points;
}

abstract interface class ArticleReadingStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureArticleReadingStore implements ArticleReadingStore {
  const SecureArticleReadingStore();
  static const FlutterSecureStorage _storage = safeSecureStorage;
  String get _key =>
      'sayring.${GlobalEnvironment.storageNamespace}.article-text-size.v1';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

/// A device reading preference only; no article, account or health data is saved.
class ArticleReadingPreferences extends ChangeNotifier {
  ArticleReadingPreferences({ArticleReadingStore? store})
    : _store = store ?? const SecureArticleReadingStore();

  static final instance = ArticleReadingPreferences();
  final ArticleReadingStore _store;
  ArticleTextSize _size = ArticleTextSize.standard;
  ArticleTextSize get size => _size;
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  int _revision = 0;
  bool _disposed = false;

  Future<void> load() => _loading ??= _restore();

  Future<void> _restore() async {
    final revision = _revision;
    try {
      final raw = await _store.read();
      final saved = ArticleTextSize.values.where((size) => size.name == raw);
      if (!_disposed && revision == _revision && saved.isNotEmpty) {
        _size = saved.first;
        notifyListeners();
      }
    } catch (_) {
      // Reading remains available if preference storage cannot be accessed.
    }
  }

  Future<bool> select(ArticleTextSize value) {
    if (_disposed) return Future.value(false);
    _revision++;
    _size = value;
    notifyListeners();
    final result = _writes.then((_) async {
      try {
        await _store.write(value.name);
        return true;
      } catch (_) {
        return false;
      }
    });
    _writes = result.then((_) {});
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
