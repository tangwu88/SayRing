import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

export 'device_prompt_wording.dart';

import 'device_prompt_wording.dart';
import 'generated/app_localizations.dart';
import 'legacy_ui_copy.dart';
import '../services/safe_secure_storage.dart';

abstract interface class GlobalLocaleStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureGlobalLocaleStore implements GlobalLocaleStore {
  const SecureGlobalLocaleStore();

  static const key = 'sayring.global.locale.v1';
  static const FlutterSecureStorage _storage = safeSecureStorage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

class GlobalLocaleController extends ChangeNotifier {
  GlobalLocaleController({
    GlobalLocaleStore? store,
    Locale? initialLocale,
    Locale Function()? systemLocale,
  }) : _store = store ?? const SecureGlobalLocaleStore(),
       _systemLocale =
           systemLocale ??
           (() => WidgetsBinding.instance.platformDispatcher.locale),
       _followsSystem = initialLocale == null,
       _locale = resolveSystemLocale(
         initialLocale ??
             (systemLocale ??
                 (() => WidgetsBinding.instance.platformDispatcher.locale))(),
       );

  static final instance = GlobalLocaleController();
  static const defaultLocale = Locale('en');
  static const supportedLocales = [
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ];
  static const names = {'en': 'English', 'zh-Hans': '简体中文'};
  final GlobalLocaleStore _store;
  final Locale Function() _systemLocale;
  bool _followsSystem;
  Locale _locale;
  bool _disposed = false;
  bool _hasApplicationHost = false;
  Future<void> _writes = Future.value();
  Locale get locale => _locale;
  String get languageName => names[_locale.toLanguageTag()]!;

  static Locale? normalize(String? value) {
    final tag = value?.trim().replaceAll('_', '-').toLowerCase();
    if (tag == null || tag.isEmpty) return null;
    final parts = tag.split('-');
    if (parts.first == 'en') return supportedLocales.first;
    if (parts.first == 'zh' &&
        !parts.contains('hant') &&
        !parts.any({'tw', 'hk', 'mo'}.contains) &&
        (parts.length == 1 ||
            parts.contains('hans') ||
            parts.contains('cn') ||
            parts.contains('sg'))) {
      return supportedLocales[1];
    }
    return null;
  }

  static Locale resolveSystemLocale(Locale value) =>
      normalize(value.toLanguageTag()) ?? defaultLocale;

  // 不读取旧版固定中文偏好。升级、冷启动与系统变化采用同一规则。
  Future<void> load() async {
    _hasApplicationHost = true;
    refreshSystemLocale();
  }

  void refreshSystemLocale() {
    if (_disposed || !_followsSystem) return;
    final next = resolveSystemLocale(_systemLocale());
    if (next != _locale) {
      _locale = next;
      notifyListeners();
    }
  }

  // 保留供现有显式测试宿主使用的接口；产品没有手动语言入口。
  Future<bool> setLocale(Locale value) {
    final supported = normalize(value.toLanguageTag());
    if (supported == null || _disposed) return Future.value(false);
    final operation = _writes.then((_) async {
      try {
        await _store.write(supported.toLanguageTag());
        if (!_disposed) {
          _followsSystem = false;
          _locale = supported;
          notifyListeners();
        }
        return true;
      } catch (_) {
        return false;
      }
    });
    _writes = operation.then((_) {});
    return operation;
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
  // 兼容未安装委托的旧独立页面宿主；正式 App 始终安装系统中英文委托。
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

/// 只处理源码中明确标记的应用文案；用户记录、文章和已生成报告不得传入。
String uiCopy(
  Object? context,
  String template, {
  List<Object?> parameters = const [],
}) {
  final tag = context is BuildContext
      ? (AppLocalizations.of(context)?.localeName ?? 'zh-Hans')
      : (GlobalLocaleController.instance._hasApplicationHost
            ? GlobalLocaleController.instance.locale.toLanguageTag()
            : 'zh-Hans');
  var copy = tag.startsWith('zh')
      ? template
      : legacyUiEnglish[template] ?? template;
  if (context is BuildContext &&
      template.contains('戒指') &&
      legacyUiEnglish.containsKey(template) &&
      DevicePromptScope.usesDevice(context)) {
    copy = genericDevicePrompt(copy);
  }
  // 一次性替换模板占位符，参数中的花括号不再解释，防止用户文本被二次替换。
  copy = copy.replaceAllMapped(RegExp(r'\{p(\d+)\}'), (m) {
    final index = int.parse(m[1]!);
    return index < parameters.length ? '${parameters[index] ?? ''}' : m[0]!;
  });
  return copy;
}

// 仅调用于控制器维护的状态/错误，绝不传入文章或用户的健康内容。
final _statusTemplates = legacyUiEnglish.entries
    .where((e) => e.key.contains(RegExp(r'\{p\d+\}')))
    .map((e) {
      final keys = RegExp(
        r'\{p\d+\}',
      ).allMatches(e.key).map((m) => m[0]!).toList();
      var pattern = RegExp.escape(e.key);
      for (final key in keys) {
        pattern = pattern.replaceFirst(RegExp.escape(key), '(.+?)');
      }
      return (RegExp('^$pattern\$'), e.value, keys);
    })
    .toList();
String appStatusCopy(String value, {bool genericDevice = false}) {
  final english =
      GlobalLocaleController.instance._hasApplicationHost &&
      GlobalLocaleController.instance.locale.languageCode != 'zh';
  if (genericDevice) {
    final status = localizeGenericDeviceStatus(value, english: english);
    if (status != null) return status;
    final appTemplate = legacyUiEnglish[value];
    if (appTemplate != null && value.contains('戒指')) {
      return genericDevicePrompt(english ? appTemplate : value);
    }
  }
  if (!english) {
    return value;
  }
  final direct = legacyUiEnglish[value];
  if (direct != null) return direct;
  for (final (pattern, english, keys) in _statusTemplates) {
    final match = pattern.firstMatch(value);
    if (match == null) continue;
    return english.replaceAllMapped(RegExp(r'\{p\d+\}'), (m) {
      final i = keys.indexOf(m[0]!);
      final original = i < 0 ? m[0]! : match[i + 1]!;
      return legacyUiEnglish[original] ?? original;
    });
  }
  return value;
}
