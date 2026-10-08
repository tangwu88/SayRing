import 'api_client.dart';

// Fixed, user-facing messages only. Never render a raw upstream response.
String aiChatFailureMessage(ApiException error) {
  final key = error.code?.toString();
  final message = switch (key) {
    'AI_NOT_CONFIGURED' => 'AI 服务尚未启用，请联系客服',
    'AI_PROVIDER_AUTH' => 'AI 服务鉴权异常，请联系客服（AI_PROVIDER_AUTH）',
    'AI_PROVIDER_LIMIT' => 'AI 服务额度或请求频率受限，请稍后重试（AI_PROVIDER_LIMIT）',
    'AI_PROVIDER_REJECTED' => 'AI 服务未接受本次请求，请联系客服（AI_PROVIDER_REJECTED）',
    'AI_PROVIDER_UNAVAILABLE' => 'AI 服务暂时繁忙，请稍后重试（AI_PROVIDER_UNAVAILABLE）',
    'AI_PROVIDER_TIMEOUT' => 'AI 回复超时，请稍后重试（AI_PROVIDER_TIMEOUT）',
    'AI_PROVIDER_NETWORK' => '服务器连接 AI 服务失败，请稍后重试（AI_PROVIDER_NETWORK）',
    'AI_PROVIDER_INVALID_RESPONSE' =>
      'AI 服务未返回有效回复，请稍后重试（AI_PROVIDER_INVALID_RESPONSE）',
    'NETWORK_TIMEOUT' => '请求超时，请检查网络后重试',
    'NETWORK_UNAVAILABLE' => '网络连接失败，请检查网络后重试',
    _ when error.statusCode == 401 => '登录已失效，请重新登录',
    _ when error.statusCode == 403 => '当前账号暂时无法使用 AI 对话',
    _ when error.statusCode == 400 || error.statusCode == 422 =>
      '提问未被接受，请检查内容后重试',
    _ => 'AI 对话暂时无法完成，请稍后重试',
  };
  if (error is AiProviderApiException) {
    final details = <String>[];
    final status = error.upstreamStatus;
    if (status != null && status >= 100 && status <= 599) {
      details.add('HTTP $status');
    }
    final providerCode = error.providerCode;
    if (providerCode != null && RegExp(r'^\d{3,6}$').hasMatch(providerCode)) {
      details.add('服务代码 $providerCode');
    }
    if (details.isNotEmpty) return '$message（${details.join('，')}）';
  }
  return message;
}
