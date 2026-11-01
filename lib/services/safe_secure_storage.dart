import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keep Android keystore/read failures observable. The plugin default would
/// delete the failed value, including the key to an existing encrypted DB.
const safeSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
);
