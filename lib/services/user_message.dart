/// Keep diagnostic payloads out of UI; preserve concise, actionable errors.
String userFacingMessage(String? value, {required String fallback}) {
  final message = value?.trim() ?? '';
  if (message.isEmpty || message.length > 180) return fallback;
  final lower = message.toLowerCase();
  // 蓝牙或后台任务超时不能误报成手机断网。未知超时交给当前页面提示重试。
  if (RegExp(
    r'(?:bluetooth|\bble\b|\bgatt\b|蓝牙|戒指).*(?:timeout|timed out|超时)',
    caseSensitive: false,
  ).hasMatch(message)) {
    return fallback;
  }
  if (RegExp(r'network|socket').hasMatch(lower) || message.contains('网络')) {
    return '网络不可用，请检查后重试';
  }
  if (RegExp(
    r'timeout|timed out|qring|luckring|coolwear|sdk|api|http|token|appid|universal.?link|exception|stack.?trace|<[^>]+>|'
    r'接口|服务端|后端|后台返回|后台未返回|桥接|未配置|配置异常|未实现|未接入|调试|原生|回调|服务器返回|响应格式|安全域名|必要字段|目标配置|下载地址不可信|配置不正确|SHA-?256|白名单|握手|回包|密钥|审核录屏|任务队列|重试队列|数据库字段|缺少必要字段|提供方配置|追踪编号|服务代码|'
    r'\b(?:worker|stacktrace|trace[_-]?id|request[_-]?id|sqlstate|upstream|schema|provider[_-]?(?:key|id)|internal[_ ]server[_ ]error)\b|\b[A-Z]{2,}(?:_[A-Z0-9]+){2,}\b',
    caseSensitive: false,
  ).hasMatch(message)) {
    return fallback;
  }
  return message;
}
