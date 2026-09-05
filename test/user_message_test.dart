import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/user_message.dart';

void main() {
  test('technical responses stay out of visible errors', () {
    for (final message in [
      '后台未返回微信 APP 支付参数',
      'SDK_NOT_CONFIGURED',
      'HTTP 500 token=private',
      '服务端接口未实现',
      '<html>error</html>',
      '微信 AppID/Universal Link 未配置',
    ]) {
      expect(userFacingMessage(message, fallback: '暂不可用，请重试'), '暂不可用，请重试');
    }
  });
  test('actionable account, permission and device errors remain visible', () {
    for (final message in ['密码不正确', '请先打开手机蓝牙', '当前手表不支持此功能', '请保持静止']) {
      expect(userFacingMessage(message, fallback: '失败'), message);
    }
    expect(
      userFacingMessage('SocketException', fallback: '失败'),
      '网络不可用，请检查后重试',
    );
  });
}
