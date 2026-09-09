import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../services/safe_resource_client.dart';

/// Network images use the same pre-request boundary in Debug and Release.
class SafeNetworkImage extends Image {
  SafeNetworkImage(
    String url, {
    super.key,
    super.width,
    super.height,
    super.fit,
    super.alignment,
    super.errorBuilder,
    super.loadingBuilder,
    super.semanticLabel,
    super.excludeFromSemantics,
    super.gaplessPlayback,
  }) : super(image: SafeNetworkImageProvider(url));
}

@immutable
class SafeNetworkImageProvider extends ImageProvider<SafeNetworkImageProvider> {
  const SafeNetworkImageProvider(this.url);
  final String url;

  @override
  Future<SafeNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    SafeNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final progress = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _load(decode, progress),
      scale: 1,
      chunkEvents: progress.stream,
    );
  }

  Future<ui.Codec> _load(
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> progress,
  ) async {
    final client = SafeResourceClient(purpose: ResourcePurpose.image);
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 20));
      const limit = 20 * 1024 * 1024;
      if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
        throw StateError('Image is unavailable.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > limit) {
          throw StateError('Image is unavailable.');
        }
        bytes.add(chunk);
        progress.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: bytes.length,
            expectedTotalBytes: response.contentLength,
          ),
        );
      }
      if (bytes.isEmpty) throw StateError('Image is unavailable.');
      return decode(await ui.ImmutableBuffer.fromUint8List(bytes.takeBytes()));
    } catch (_) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      // No URL in the error: signed file links may carry private credentials.
      throw StateError('Image is unavailable.');
    } finally {
      client.close();
      unawaited(progress.close());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SafeNetworkImageProvider && other.url == url;
  @override
  int get hashCode => url.hashCode;
}
