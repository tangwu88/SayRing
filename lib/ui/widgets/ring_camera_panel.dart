import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

class RingCameraPanel extends StatelessWidget {
  const RingCameraPanel({
    super.key,
    required this.preview,
    required this.message,
    required this.remoteReady,
    required this.takingPhoto,
    required this.saved,
    this.onCapture,
    this.onRetryCamera,
    this.onRetrySave,
    this.onPhotoSettings,
    this.thumbnail,
    this.cameraSettingsRequired = false,
  });
  final Widget preview;
  final String message;
  final bool remoteReady, takingPhoto, saved;
  final VoidCallback? onCapture, onRetryCamera, onRetrySave, onPhotoSettings;
  final Widget? thumbnail;
  final bool cameraSettingsRequired;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(Icons.circle_outlined, size: 20, color: SaydianColors.techBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              remoteReady ? '戒指遥控已就绪' : '手机相机',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(
            Icons.photo_library_outlined,
            size: 18,
            color: SaydianColors.muted,
          ),
          const SizedBox(width: 5),
          const Text(
            '自动存相册',
            style: TextStyle(fontSize: 12, color: SaydianColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        remoteReady ? '使用戒指支持的拍照动作，或轻点下方快门' : '轻点下方快门拍照',
        style: const TextStyle(fontSize: 12, color: SaydianColors.muted),
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          key: const Key('ring-camera-preview'),
          height: math.min(MediaQuery.sizeOf(context).height * .48, 420),
          child: ColoredBox(color: const Color(0xFF14212B), child: preview),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: SaydianColors.muted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox.square(
            dimension: 52,
            child: thumbnail == null
                ? const Icon(
                    Icons.image_outlined,
                    color: SaydianColors.outline,
                    size: 26,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: thumbnail!,
                  ),
          ),
          Semantics(
            label: '拍照并保存到手机相册',
            button: true,
            child: SizedBox.square(
              dimension: 76,
              child: OutlinedButton(
                key: const ValueKey('camera-shutter-button'),
                onPressed: takingPhoto ? null : onCapture,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  shape: const CircleBorder(),
                  side: const BorderSide(
                    color: SaydianColors.techBlue,
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onCapture == null
                        ? SaydianColors.line
                        : SaydianColors.techBlue,
                  ),
                  alignment: Alignment.center,
                  child: takingPhoto
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ),
            ),
          ),
          SizedBox.square(
            dimension: 52,
            child: Icon(
              saved
                  ? Icons.check_circle_outline_rounded
                  : Icons.photo_library_outlined,
              color: saved ? SaydianColors.green : SaydianColors.outline,
              size: 26,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        '轻触快门，或使用戒指支持的拍照动作',
        textAlign: TextAlign.center,
        style: TextStyle(color: SaydianColors.muted, fontSize: 12),
      ),
      if (onRetrySave != null)
        TextButton.icon(
          key: const Key('camera-retry-save-button'),
          onPressed: takingPhoto ? null : onRetrySave,
          icon: const Icon(Icons.save_alt_rounded),
          label: const Text('重试保存这张照片'),
        ),
      if (onPhotoSettings != null)
        TextButton.icon(
          key: const ValueKey('camera-photo-settings-button'),
          onPressed: onPhotoSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('允许保存照片'),
        ),
      if (onRetryCamera != null)
        TextButton.icon(
          key: const ValueKey('camera-retry-button'),
          onPressed: onRetryCamera,
          icon: Icon(
            cameraSettingsRequired
                ? Icons.settings_outlined
                : Icons.refresh_rounded,
          ),
          label: Text(cameraSettingsRequired ? '前往设置开启相机' : '重新打开相机'),
        ),
    ],
  );
}
