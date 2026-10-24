import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/camera_photo_saver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('camera-save-synthetic');
  const saver = CameraPhotoSaver(methods: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('only a confirmed native album write is success', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'saveGalleryImage');
      expect(call.arguments['mimeType'], 'image/jpeg');
      return {'saved': true};
    });
    await saver.save(Uint8List.fromList([1, 2]), 'synthetic.jpg');
  });
  for (final reply in [
    null,
    <String, Object?>{},
    {'saved': false},
  ]) {
    test('unconfirmed album result $reply remains retryable', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => reply);
      await expectLater(
        saver.save(Uint8List.fromList([1]), 'synthetic.jpg'),
        throwsA(isA<PlatformException>()),
      );
    });
  }
  test('permission failure remains a permission failure', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'PHOTO_PERMISSION_DENIED'),
    );
    await expectLater(
      saver.save(Uint8List.fromList([1]), 'synthetic.jpg'),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'PHOTO_PERMISSION_DENIED',
        ),
      ),
    );
  });
  test('empty photo never calls native', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return {'saved': true};
    });
    await expectLater(
      saver.save(Uint8List(0), 'synthetic.jpg'),
      throwsA(isA<PlatformException>()),
    );
    expect(calls, 0);
  });
}
