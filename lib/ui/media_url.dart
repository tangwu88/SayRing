import '../services/global_environment.dart';

/// Resolves API media paths without allowing unsupported URL origins.
String normalizeArticleImageUrl(String source) {
  try {
    return GlobalEnvironment.media(source.replaceAll('&amp;', '&'));
  } on ArgumentError {
    return '';
  }
}
