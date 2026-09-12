import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../domain/global_commerce.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';
import '../services/global_environment.dart';
import 'widgets/safe_network_image.dart';

String globalShopMoney(
  BuildContext context,
  Map<String, Object?> row, {
  String amountKey = 'priceCents',
}) {
  final amount = commerceCents(row[amountKey]);
  final currency = row['currency'];
  final exponent = row['currencyExponent'];
  if (amount == null ||
      amount < 0 ||
      currency is! String ||
      !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
      exponent is! int ||
      exponent < 0 ||
      exponent > 4) {
    return context.l10n.globalShopPricePending;
  }
  return NumberFormat.currency(
    locale: Localizations.localeOf(context).toLanguageTag(),
    name: currency,
    symbol: currency,
    decimalDigits: exponent,
  ).format(amount / math.pow(10, exponent));
}

class GlobalShopImage extends StatelessWidget {
  const GlobalShopImage(this.url, {this.fit = BoxFit.contain, super.key});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final source = GlobalEnvironment.media(url);
    if (source.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFF4F5F6),
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }
    return SafeNetworkImage(
      source,
      fit: fit,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFF4F5F6),
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      ),
    );
  }
}

class GlobalShopRetry extends StatelessWidget {
  const GlobalShopRetry({required this.onRetry, this.message, super.key});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(
            message ?? context.l10n.serviceUnavailable,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    ),
  );
}

class GlobalShopNotice extends StatelessWidget {
  const GlobalShopNotice({required this.text, this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon ?? Icons.info_outline, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
        ),
      ],
    ),
  );
}

String globalShopDate(BuildContext context, Object? value) {
  final parsed = DateTime.tryParse(commerceText(value))?.toLocal();
  if (parsed == null) return context.l10n.noData;
  return DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).add_Hm().format(parsed);
}

enum _EvidenceStatus { loading, uploading, failed, ready }

class _EvidenceRow {
  _EvidenceRow({required this.key, this.file, this.id})
    : status = file == null
          ? _EvidenceStatus.loading
          : _EvidenceStatus.uploading;

  final String key;
  XFile? file;
  String? id;
  Uint8List? bytes;
  _EvidenceStatus status;
  double progress = 0;
}

/// Private after-sales evidence picker. Only opaque server IDs leave this
/// widget; local file paths and bytes never become part of an order request.
class GlobalShopEvidencePicker extends StatefulWidget {
  const GlobalShopEvidencePicker({
    required this.controller,
    required this.ids,
    required this.onChanged,
    this.locked = false,
    this.onBlockedChanged,
    super.key,
  });

  final AppController controller;
  final List<String> ids;
  final ValueChanged<List<String>> onChanged;
  final bool locked;
  final ValueChanged<bool>? onBlockedChanged;

  @override
  State<GlobalShopEvidencePicker> createState() =>
      _GlobalShopEvidencePickerState();
}

class _GlobalShopEvidencePickerState extends State<GlobalShopEvidencePicker> {
  static const _maxFiles = 9;
  static const _maxBytes = 10 * 1024 * 1024;
  final _picker = ImagePicker();
  final List<_EvidenceRow> _rows = [];
  bool _checking = true;
  bool _enabled = false;
  bool _choosing = false;
  bool _alive = true;
  String? _notice;

  bool get _busy =>
      _choosing || _rows.any((row) => row.status == _EvidenceStatus.uploading);
  bool get _blocked =>
      _busy || _rows.any((row) => row.status == _EvidenceStatus.failed);

  @override
  void initState() {
    super.initState();
    for (final id in widget.ids.take(_maxFiles)) {
      final row = _EvidenceRow(key: id, id: id);
      _rows.add(row);
      _loadPreview(row);
    }
    _loadCapabilities();
  }

  @override
  void didUpdateWidget(covariant GlobalShopEvidencePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.ids.toSet();
    final newIds = widget.ids.take(_maxFiles).toSet();
    if (oldWidget.locked != widget.locked || !setEquals(oldIds, newIds)) {
      setState(() {
        _rows.removeWhere(
          (row) =>
              row.file == null && row.id != null && !newIds.contains(row.id),
        );
        for (final id in newIds) {
          if (_rows.any((row) => row.id == id)) continue;
          final row = _EvidenceRow(key: id, id: id);
          _rows.add(row);
          _loadPreview(row);
        }
      });
    }
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    try {
      final value = await widget.controller
          .loadGlobalShopEvidenceCapabilities();
      if (!_alive) return;
      setState(() {
        _enabled = value['enabled'] == true;
        _notice = _enabled ? null : context.l10n.photoServiceUnavailable;
      });
    } catch (_) {
      if (!_alive) return;
      setState(() {
        _enabled = false;
        _notice = context.l10n.photoServiceUnavailable;
      });
    } finally {
      if (_alive) setState(() => _checking = false);
    }
  }

  Future<void> _loadPreview(_EvidenceRow row) async {
    final id = row.id;
    if (id == null) return;
    try {
      final bytes = await widget.controller.loadGlobalShopEvidence(id);
      if (!_alive || !_rows.contains(row)) return;
      setState(() {
        row.bytes = bytes;
        row.status = _EvidenceStatus.ready;
      });
    } catch (_) {
      if (!_alive || !_rows.contains(row)) return;
      setState(() => row.status = _EvidenceStatus.failed);
    }
  }

  Future<void> _choose() async {
    if (_busy || !_enabled || widget.locked || _rows.length >= _maxFiles) {
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.l10n.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !_alive) return;
    setState(() => _choosing = true);
    _notifyBlocked();
    try {
      final files = source == ImageSource.camera
          ? [
              ?await _picker.pickImage(
                source: ImageSource.camera,
                requestFullMetadata: false,
              ),
            ]
          : await _picker.pickMultiImage(requestFullMetadata: false);
      for (final file in files.take(_maxFiles - _rows.length)) {
        if (!_alive) return;
        await _addAndUpload(file);
      }
    } catch (_) {
      if (_alive) setState(() => _notice = context.l10n.photoReadFailed);
    } finally {
      if (_alive) {
        setState(() => _choosing = false);
        _notifyBlocked();
      }
    }
  }

  Future<void> _addAndUpload(XFile file) async {
    final extension = file.name.toLowerCase().split('.').last;
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      setState(() => _notice = context.l10n.photoFormatUnsupported);
      return;
    }
    final length = await file.length();
    if (length <= 0 || length > _maxBytes) {
      setState(() => _notice = context.l10n.photoTooLarge);
      return;
    }
    final row = _EvidenceRow(key: const Uuid().v4(), file: file);
    row.bytes = await file.readAsBytes();
    if (!_alive) return;
    setState(() {
      _rows.add(row);
      _notice = null;
    });
    _notifyBlocked();
    await _upload(row);
  }

  Future<void> _upload(_EvidenceRow row) async {
    final file = row.file;
    if (file == null || widget.locked || !_enabled) return;
    setState(() {
      row.status = _EvidenceStatus.uploading;
      row.progress = 0;
    });
    _notifyBlocked();
    try {
      final value = await widget.controller.uploadGlobalShopEvidence(
        file.path,
        onProgress: (progress) {
          if (!_alive || !_rows.contains(row)) return;
          if ((progress - row.progress).abs() < .02 && progress < 1) return;
          setState(() => row.progress = progress.clamp(0, 1));
        },
      );
      if (!_alive || !_rows.contains(row)) return;
      setState(() {
        row.id = commerceId(value['id']);
        row.file = null;
        row.status = _EvidenceStatus.ready;
        row.progress = 1;
      });
      _emitIds();
    } catch (_) {
      if (!_alive || !_rows.contains(row)) return;
      setState(() => row.status = _EvidenceStatus.failed);
    } finally {
      _notifyBlocked();
    }
  }

  void _remove(_EvidenceRow row) {
    if (widget.locked || _busy) return;
    setState(() => _rows.remove(row));
    _emitIds();
    _notifyBlocked();
  }

  void _emitIds() => widget.onChanged(
    _rows
        .where((row) => row.status == _EvidenceStatus.ready)
        .map((row) => row.id)
        .whereType<String>()
        .toList(growable: false),
  );

  void _notifyBlocked() {
    final value = _blocked;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_alive) widget.onBlockedChanged?.call(value);
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.problemPhotos,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${_rows.length}/$_maxFiles'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.afterSalePhotoHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_notice != null) ...[
            const SizedBox(height: 8),
            GlobalShopNotice(text: _notice!),
          ],
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 300 ? 2 : 3;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (final row in _rows)
                      SizedBox(width: width, child: _tile(row)),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed:
                _checking ||
                    !_enabled ||
                    _busy ||
                    widget.locked ||
                    _rows.length >= _maxFiles
                ? null
                : _choose,
            icon: _choosing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(context.l10n.addProblemPhotos),
          ),
        ],
      ),
    ),
  );

  Widget _tile(_EvidenceRow row) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: row.bytes != null
                ? Image.memory(row.bytes!, fit: BoxFit.cover)
                : Center(
                    child: row.status == _EvidenceStatus.loading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      if (row.status == _EvidenceStatus.uploading) ...[
        LinearProgressIndicator(value: row.progress > 0 ? row.progress : null),
        const SizedBox(height: 3),
        Text(context.l10n.photoUploading),
      ] else if (row.status == _EvidenceStatus.failed) ...[
        Text(
          context.l10n.photoUploadFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (row.file != null && !widget.locked)
          TextButton(
            onPressed: _busy ? null : () => _upload(row),
            child: Text(context.l10n.retry),
          ),
      ] else
        Text(context.l10n.photoUploaded),
      if (!widget.locked)
        TextButton(
          onPressed: _busy ? null : () => _remove(row),
          child: Text(context.l10n.removePhoto),
        ),
    ],
  );
}

class GlobalShopEvidenceGallery extends StatefulWidget {
  const GlobalShopEvidenceGallery({
    required this.controller,
    required this.ids,
    super.key,
  });

  final AppController controller;
  final List<String> ids;

  @override
  State<GlobalShopEvidenceGallery> createState() =>
      _GlobalShopEvidenceGalleryState();
}

class _GlobalShopEvidenceGalleryState extends State<GlobalShopEvidenceGallery> {
  final Map<String, Uint8List?> _images = {};

  @override
  void initState() {
    super.initState();
    for (final id in widget.ids.take(9)) {
      _images[id] = null;
      _load(id);
    }
  }

  Future<void> _load(String id) async {
    try {
      final bytes = await widget.controller.loadGlobalShopEvidence(id);
      if (mounted && _images.containsKey(id)) {
        setState(() => _images[id] = bytes);
      }
    } catch (_) {
      if (mounted && _images.containsKey(id)) {
        setState(() => _images[id] = Uint8List(0));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.problemPhotos,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in _images.entries)
            SizedBox.square(
              dimension: 88,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: entry.value == null
                    ? const ColoredBox(
                        color: Color(0xFFF4F5F6),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : entry.value!.isEmpty
                    ? InkWell(
                        onTap: () {
                          setState(() => _images[entry.key] = null);
                          _load(entry.key);
                        },
                        child: ColoredBox(
                          color: const Color(0xFFF4F5F6),
                          child: Tooltip(
                            message: context.l10n.retry,
                            child: const Icon(Icons.refresh),
                          ),
                        ),
                      )
                    : Image.memory(entry.value!, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    ],
  );
}
