import 'global_environment.dart';

/// A non-secret environment digest, never an account, host URL or file path.
String globalStorageNamespace(String? configured) {
  final namespace = configured ?? GlobalEnvironment.storageNamespace;
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(namespace)) {
    throw ArgumentError.value(
      configured,
      'storageNamespace',
      'SHA-256 required',
    );
  }
  return namespace;
}
