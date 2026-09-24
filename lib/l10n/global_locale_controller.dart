import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'generated/app_localizations.dart';

abstract interface class GlobalLocaleStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureGlobalLocaleStore implements GlobalLocaleStore {
  const SecureGlobalLocaleStore();

  static const key = 'sayring.global.locale.v1';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

class GlobalLocaleController extends ChangeNotifier {
  GlobalLocaleController({GlobalLocaleStore? store, Locale? initialLocale})
    : _store = store ?? const SecureGlobalLocaleStore(),
      _locale = normalize(initialLocale?.toLanguageTag()) ?? defaultLocale;

  static final instance = GlobalLocaleController();
  static const defaultLocale = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
  );
  static const supportedLocales = [
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('de'),
    Locale('fr'),
    Locale('es'),
    Locale('ja'),
    Locale('ko'),
  ];
  static const names = {
    'en': 'English',
    'zh-Hans': '简体中文',
    'zh-Hant': '繁體中文',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'ja': '日本語',
    'ko': '한국어',
  };

  final GlobalLocaleStore _store;
  Locale _locale;
  Locale get locale => _locale;
  String get languageName => names[_locale.toLanguageTag()]!;
  int _revision = 0;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();
  Future<void>? _loading;

  static Locale? normalize(String? value) {
    final tag = value?.trim().replaceAll('_', '-').toLowerCase();
    if (tag == null || tag.isEmpty) return null;
    if (tag.startsWith('zh')) {
      if (tag == 'zh-hant' ||
          tag == 'zh-tw' ||
          tag == 'zh-hk' ||
          tag == 'zh-mo') {
        return supportedLocales[2];
      }
      if (tag == 'zh' || tag == 'zh-hans' || tag == 'zh-cn' || tag == 'zh-sg') {
        return supportedLocales[1];
      }
      return null;
    }
    for (final locale in supportedLocales) {
      if (tag == locale.languageCode ||
          tag.startsWith('${locale.languageCode}-')) {
        return locale;
      }
    }
    return null;
  }

  Future<void> load() => _loading ??= _restore();

  Future<void> _restore() async {
    final revision = _revision;
    try {
      final stored = normalize(await _store.read());
      if (!_disposed &&
          revision == _revision &&
          stored != null &&
          stored != _locale) {
        _locale = stored;
        notifyListeners();
      }
    } catch (_) {
      // A preference failure must not prevent sign-in or expose storage errors.
    }
  }

  Future<bool> setLocale(Locale locale) {
    final supported = normalize(locale.toLanguageTag());
    if (supported == null || _disposed) return Future.value(false);
    _revision += 1;
    final result = _writes.then((_) async {
      try {
        await _store.write(supported.toLanguageTag());
        if (!_disposed) {
          _locale = supported;
          notifyListeners();
        }
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

class GlobalLocaleScope extends InheritedNotifier<GlobalLocaleController> {
  const GlobalLocaleScope({
    required GlobalLocaleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static GlobalLocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlobalLocaleScope>()?.notifier;

  static GlobalLocaleController of(BuildContext context) => maybeOf(context)!;
}

extension SaydianLocalizedContext on BuildContext {
  // Existing domestic page hosts can omit the new delegate. Global App always
  // installs it and explicitly starts in Simplified Chinese; it never follows
  // the OS locale.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );
}

class GlobalLanguageButton extends StatelessWidget {
  const GlobalLanguageButton({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> showGlobalLanguagePicker(BuildContext context) async {
  final controller = GlobalLocaleScope.of(context);
  final selected = await showModalBottomSheet<Locale>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                sheetContext.l10n.language,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final locale in GlobalLocaleController.supportedLocales)
              ListTile(
                key: ValueKey('global-language-${locale.toLanguageTag()}'),
                title: Text(
                  GlobalLocaleController.names[locale.toLanguageTag()]!,
                ),
                trailing: locale == controller.locale
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(locale),
              ),
          ],
        ),
      ),
    ),
  );
  if (selected == null) return;
  final saved = await controller.setLocale(selected);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.changeLanguageFailed)));
  }
}
