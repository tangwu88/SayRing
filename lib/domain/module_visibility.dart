enum SayRingModule {
  healthLibrary('health_library'),
  mall('mall');

  const SayRingModule(this.wireName);
  final String wireName;
}

class ModuleVisibilitySnapshot {
  const ModuleVisibilitySnapshot({
    required this.modules,
    required this.validity,
  });

  factory ModuleVisibilitySnapshot.fromMap(Map<String, Object?> data) {
    final config = data['moduleVisibility'];
    if (data['product'] != 'say-ring' ||
        data['platform'] != 'ios' ||
        config is! Map ||
        config['schemaVersion'] != 1 ||
        config['schemaVersion'] is! int) {
      throw const FormatException('Invalid module visibility');
    }
    final seconds = config['validForSeconds'];
    final flags = config['modules'];
    if (seconds is! int ||
        seconds < 1 ||
        seconds > 300 ||
        flags is! Map ||
        flags.length != SayRingModule.values.length ||
        SayRingModule.values.any((m) => flags[m.wireName] is! bool)) {
      throw const FormatException('Invalid module visibility flags');
    }
    return ModuleVisibilitySnapshot(
      modules: Set.unmodifiable({
        for (final module in SayRingModule.values)
          if (flags[module.wireName] == true) module,
      }),
      validity: Duration(seconds: seconds),
    );
  }

  final Set<SayRingModule> modules;
  final Duration validity;
}

/// Memory-only, monotonic grants. This catalogue never authorizes payments,
/// measurements or reviewer-specific behavior.
class ModuleVisibilityLease {
  ModuleVisibilityLease({Duration Function()? now}) : _nowOverride = now;
  final Duration Function()? _nowOverride;
  final Stopwatch _clock = Stopwatch()..start();
  Set<SayRingModule> _modules = const {};
  Duration _expiresAt = Duration.zero;
  int _generation = 0;
  final Map<SayRingModule, int> _moduleGenerations = {};

  Duration get _now => _nowOverride?.call() ?? _clock.elapsed;
  bool get expired => _now >= _expiresAt;
  int get generation => _generation;
  int generationFor(SayRingModule module) => _moduleGenerations[module] ?? 0;
  bool allows(SayRingModule module) => !expired && _modules.contains(module);

  void replace(Set<SayRingModule> modules, Duration validity) {
    if (validity <= Duration.zero || validity > const Duration(seconds: 300)) {
      throw const FormatException('Invalid module lease');
    }
    final wasExpired = expired;
    for (final module in SayRingModule.values) {
      if (wasExpired || _modules.contains(module) != modules.contains(module)) {
        _moduleGenerations[module] = generationFor(module) + 1;
      }
    }
    if (wasExpired ||
        _modules.length != modules.length ||
        !_modules.containsAll(modules)) {
      _generation++;
    }
    _modules = Set.unmodifiable(modules);
    _expiresAt = _now + validity;
  }

  void close() {
    _generation++;
    for (final module in SayRingModule.values) {
      _moduleGenerations[module] = generationFor(module) + 1;
    }
    _modules = const {};
    _expiresAt = Duration.zero;
  }
}
