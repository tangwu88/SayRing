import 'api_client.dart';

/// 原因代码留在 ApiException；对话页只给用户能采取的下一步，不误报手机断网。
String aiChatFailureMessage(ApiException error) =>
    switch (error.code?.toString()) {
      'AI_NOT_CONFIGURED' || 'AI_PROVIDER_AUTH' => '问答暂不可用，请联系客服',
      'AI_PROVIDER_TIMEOUT' => '未收到回答，请重试',
      'AI_PROVIDER_LIMIT' ||
      'AI_PROVIDER_REJECTED' ||
      'AI_PROVIDER_UNAVAILABLE' ||
      'AI_PROVIDER_NETWORK' ||
      'AI_PROVIDER_INVALID_RESPONSE' => '问答暂不可用，请稍后重试',
      'NETWORK_TIMEOUT' => '请求超时，请检查网络后重试',
      'NETWORK_UNAVAILABLE' => '网络连接失败，请检查网络后重试',
      _ when error.statusCode == 401 => '登录已过期，请重新登录',
      _ when error.statusCode == 403 => '当前账号暂不能使用问答',
      _ when error.statusCode == 400 || error.statusCode == 422 => '请检查内容后重试',
      _ => '问答暂时无法完成，请稍后重试',
    };
