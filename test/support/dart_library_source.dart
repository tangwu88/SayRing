import 'dart:io';

import 'package:path/path.dart' as p;

/// Keeps source-copy audits effective after a library is split into modules.
/// Imports are deliberately not followed: only this public library's own
/// parts and local exports belong to its source surface.
String readDartLibrarySource(String path) {
  final visited = <String>{};
  final directives = RegExp(
    r'''^\s*(?:part|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  String read(String filePath) {
    final normalized = p.normalize(p.absolute(filePath));
    if (!visited.add(normalized)) return '';
    final source = File(normalized).readAsStringSync();
    if (!normalized.endsWith('.dart')) return source;
    final children = directives.allMatches(source).map((match) {
      final uri = Uri.parse(match.group(1)!);
      if (uri.hasScheme || uri.hasAuthority || p.isAbsolute(uri.path)) {
        return '';
      }
      return read(p.join(p.dirname(normalized), uri.path));
    });
    return [source, ...children].join('\n');
  }

  return read(path);
}
