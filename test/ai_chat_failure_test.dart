import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/ai_chat_failure.dart';
import 'package:saydian_app/services/api_client.dart';

void main() {
  test('AI provider failures never masquerade as phone network failure', () {
    for (final key in [
      'AI_NOT_CONFIGURED',
      'AI_PROVIDER_AUTH',
      'AI_PROVIDER_LIMIT',
      'AI_PROVIDER_REJECTED',
      'AI_PROVIDER_UNAVAILABLE',
      'AI_PROVIDER_TIMEOUT',
      'AI_PROVIDER_NETWORK',
      'AI_PROVIDER_INVALID_RESPONSE',
    ]) {
      final text = aiChatFailureMessage(
        ApiException('PRIVATE_RESPONSE_SENTINEL', statusCode: 503, code: key),
      );
      expect(text, isNot(contains('PRIVATE_RESPONSE')));
      expect(text, isNot(contains('检查网络')));
      expect(text, isNot(contains('已成功')));
    }
  });
  test('actual transport errors and auth failures are distinct', () {
    expect(
      aiChatFailureMessage(
        const ApiException('private', code: 'NETWORK_TIMEOUT'),
      ),
      contains('检查网络'),
    );
    expect(
      aiChatFailureMessage(
        const ApiException('private', code: 'NETWORK_UNAVAILABLE'),
      ),
      contains('网络连接失败'),
    );
    expect(
      aiChatFailureMessage(const ApiException('private', statusCode: 401)),
      contains('重新登录'),
    );
    expect(
      aiChatFailureMessage(const ApiException('private', statusCode: 403)),
      contains('当前账号'),
    );
    expect(
      aiChatFailureMessage(const ApiException('private', statusCode: 400)),
      contains('检查内容'),
    );
    expect(
      aiChatFailureMessage(const ApiException('private', statusCode: 502)),
      contains('暂时无法完成'),
    );
  });
  test('only bounded numeric diagnostics are displayed', () {
    expect(
      aiChatFailureMessage(
        const AiProviderApiException(
          'private',
          code: 'AI_PROVIDER_REJECTED',
          upstreamStatus: 400,
          providerCode: '1211',
        ),
      ),
      contains('HTTP 400，服务代码 1211'),
    );
    expect(
      aiChatFailureMessage(
        const AiProviderApiException(
          'private',
          code: 'AI_PROVIDER_REJECTED',
          upstreamStatus: 9999,
          providerCode: 'PRIVATE_SENTINEL',
        ),
      ),
      isNot(contains('PRIVATE_SENTINEL')),
    );
  });
}
