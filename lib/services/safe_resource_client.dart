import 'package:http/http.dart' as http;

import 'global_environment.dart';
import 'network_audit.dart';

enum ResourcePurpose { image, watchFace, weather }

/// The vendor list is intentionally separate from first-party service routing.
class SafeResourceClient extends http.BaseClient {
  SafeResourceClient({http.Client? inner, required this.purpose})
    : _inner = inner ?? http.Client();

  final http.Client _inner;
  final ResourcePurpose purpose;

  static bool isWatchVendor(Uri uri) =>
      uri.scheme == 'https' &&
      GlobalEnvironment.safeResourcePath(uri) &&
      (uri.host == 'vphband.com' || uri.host.endsWith('.vphband.com')) &&
      (uri.port == 443 || uri.port == 9001);

  static bool isWeatherVendor(Uri uri) =>
      uri.scheme == 'https' &&
      uri.port == 443 &&
      GlobalEnvironment.safeResourcePath(uri) &&
      uri.host.endsWith('.qweatherapi.com');

  bool allows(Uri uri) => switch (purpose) {
    ResourcePurpose.image =>
      GlobalEnvironment.allowsFirstPartyResource(uri) || isWatchVendor(uri),
    ResourcePurpose.watchFace => isWatchVendor(uri),
    ResourcePurpose.weather => isWeatherVendor(uri),
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!allows(request.url)) {
      NetworkAudit.record(
        request.url,
        request.method,
        purpose.name,
        outcome: 'blocked_origin',
      );
      throw http.ClientException('Resource is unavailable.');
    }
    request.followRedirects = false;
    NetworkAudit.record(
      request.url,
      request.method,
      purpose.name,
      outcome: 'sending',
    );
    final response = await _inner.send(request);
    NetworkAudit.record(
      request.url,
      request.method,
      purpose.name,
      status: response.statusCode,
      requestId: response.headers['x-request-id'],
    );
    // Do not hand a redirect to Image.network or a vendor download helper.
    if (response.statusCode >= 300 && response.statusCode < 400) {
      await response.stream.drain<void>();
      throw http.ClientException('Resource is unavailable.');
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
