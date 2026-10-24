import 'package:flutter/services.dart';

/// Adding one captured image never requires reading the user's photo library.
class CameraPhotoSaver {
  const CameraPhotoSaver({
    this.methods = const MethodChannel('cc.saidian/wearable_methods'),
  });
  final MethodChannel methods;

  Future<void> save(Uint8List bytes, String fileName) async {
    if (bytes.isEmpty) {
      throw PlatformException(
        code: 'PHOTO_ARGUMENT_INVALID',
        message: '照片为空，请重新拍摄',
      );
    }
    final result = await methods.invokeMapMethod<String, Object?>(
      'saveGalleryImage',
      {'bytes': bytes, 'fileName': fileName, 'mimeType': 'image/jpeg'},
    );
    if (result?['saved'] != true) {
      throw PlatformException(
        code: 'PHOTO_SAVE_UNCONFIRMED',
        message: '相册尚未确认保存，请重试保存这张照片',
      );
    }
  }
}
