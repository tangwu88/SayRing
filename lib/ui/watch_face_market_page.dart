import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/feature_models.dart';
import '../services/app_controller.dart';
import '../services/device_watch_face_market_service.dart';
import 'app_theme.dart';

class WatchFaceLoadRequestGate {
  int _generation = 0;

  int begin() => ++_generation;

  void invalidate() => _generation++;

  bool accepts({
    required int token,
    required String? requestedDeviceId,
    required String? currentDeviceId,
  }) => token == _generation && requestedDeviceId == currentDeviceId;
}

class DeviceWatchFaceMarketPage extends StatefulWidget {
  const DeviceWatchFaceMarketPage({
    required this.controller,
    required this.profile,
    this.service,
    super.key,
  });

  final AppController controller;
  final DeviceWatchFaceMarketProfile profile;
  final DeviceWatchFaceMarketService? service;

  @override
  State<DeviceWatchFaceMarketPage> createState() =>
      _DeviceWatchFaceMarketPageState();
}

class _DeviceWatchFaceMarketPageState extends State<DeviceWatchFaceMarketPage> {
  late DeviceWatchFaceMarketService _service;
  final List<DeviceWatchFaceMarketItem> _items = [];
  int _page = 0;
  int _pageCount = 1;
  int _total = 0;
  bool _loading = false;
  DeviceWatchFaceMarketItem? _installing;
  DeviceWatchFaceMarketItem? _lastFailedInstall;
  double _downloadProgress = 0;
  String? _error;
  String? _installError;
  bool _showingCache = false;
  final _loadGate = WatchFaceLoadRequestGate();
  String? _observedDeviceId;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DeviceWatchFaceMarketService();
    _observedDeviceId = widget.controller.connectedDevice?.id;
    widget.controller.addListener(_handleDeviceChanged);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleDeviceChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DeviceWatchFaceMarketPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    var shouldReload = false;
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleDeviceChanged);
      widget.controller.addListener(_handleDeviceChanged);
      _observedDeviceId = widget.controller.connectedDevice?.id;
      _loadGate.invalidate();
      shouldReload = true;
    }
    if (oldWidget.service != widget.service) {
      _service = widget.service ?? DeviceWatchFaceMarketService();
      _loadGate.invalidate();
      shouldReload = true;
    }
    if (oldWidget.profile.profileFingerprint !=
        widget.profile.profileFingerprint) {
      shouldReload = true;
    }
    if (shouldReload) unawaited(_load(reset: true));
  }

  void _handleDeviceChanged() {
    final currentDeviceId = widget.controller.connectedDevice?.id;
    if (currentDeviceId == _observedDeviceId) return;
    _observedDeviceId = currentDeviceId;
    _loadGate.invalidate();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items.clear();
      _page = 0;
      _pageCount = 1;
      _total = 0;
      _showingCache = false;
      _error = '连接设备已变化，请返回表盘中心重新读取规格';
    });
  }

  bool _isCurrentLoad(
    int generation,
    String? requestedDeviceId,
    String requestedFingerprint,
  ) =>
      mounted &&
      _loadGate.accepts(
        token: generation,
        requestedDeviceId: requestedDeviceId,
        currentDeviceId: widget.controller.connectedDevice?.id,
      ) &&
      widget.profile.profileFingerprint == requestedFingerprint &&
      widget.profile.matchesDevice(requestedDeviceId);

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!widget.profile.matchesDevice(widget.controller.connectedDevice?.id)) {
      setState(() => _error = '连接设备已变化，请返回表盘中心重新读取规格');
      return;
    }
    final generation = _loadGate.begin();
    final requestedDeviceId = widget.controller.connectedDevice?.id;
    final requestedFingerprint = widget.profile.profileFingerprint;
    final nextPage = reset ? 1 : _page + 1;
    if (!reset && nextPage > _pageCount) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _page = 0;
        _pageCount = 1;
      }
    });
    try {
      final result = await _loadMarketPage(nextPage);
      if (!_isCurrentLoad(
        generation,
        requestedDeviceId,
        requestedFingerprint,
      )) {
        return;
      }
      setState(() {
        _items.addAll(result.items);
        _page = result.pageIndex;
        _pageCount = result.pageCount;
        _total = result.total;
        _showingCache = result.isCached;
      });
    } on DeviceWatchFaceMarketException catch (error) {
      if (_isCurrentLoad(generation, requestedDeviceId, requestedFingerprint)) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (_isCurrentLoad(generation, requestedDeviceId, requestedFingerprint)) {
        setState(() => _error = '表盘商城加载失败，请稍后重试');
      }
    } finally {
      if (_isCurrentLoad(generation, requestedDeviceId, requestedFingerprint)) {
        setState(() => _loading = false);
      }
    }
  }

  Future<DeviceWatchFaceMarketPageData> _loadMarketPage(int page) async {
    if (!widget.controller.usesNativeWatchFaceMarket) {
      return _service.loadPage(page: page, profile: widget.profile);
    }
    const pageSize = 12;
    final catalogue = await widget.controller.readNativeWatchFaceCatalog();
    final allItems = catalogue
        .map(DeviceWatchFaceMarketItem.fromNative)
        .where(
          (item) =>
              item.available &&
              item.dialShape == widget.profile.dialShape &&
              item.binProtocol == widget.profile.binProtocol,
        )
        .toList(growable: false);
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, allItems.length);
    final items = start >= allItems.length
        ? const <DeviceWatchFaceMarketItem>[]
        : allItems.sublist(start, end);
    return DeviceWatchFaceMarketPageData(
      pageIndex: page,
      pageCount: allItems.isEmpty
          ? 1
          : (allItems.length + pageSize - 1) ~/ pageSize,
      total: allItems.length,
      items: items,
    );
  }

  Future<void> _install(DeviceWatchFaceMarketItem item) async {
    if (_installing != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用这个表盘？'),
        content: const Text('下载后会传送到手表。传送期间请保持手表靠近手机，不要离开当前页面。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('下载并使用'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _installing = item;
      _downloadProgress = 0;
      _installError = null;
      _lastFailedInstall = null;
    });
    try {
      final latestProfileData = await widget.controller.readWatchFaceProfile();
      final latestProfile = DeviceWatchFaceMarketProfile.fromMap(
        latestProfileData,
      );
      if (latestProfile.profileFingerprint !=
              widget.profile.profileFingerprint ||
          !latestProfile.matchesDevice(widget.controller.connectedDevice?.id)) {
        throw const DeviceWatchFaceMarketException('连接设备或表盘规格已变化，请返回后重新进入商城');
      }
      late final String filePath;
      late final int fileLength;
      final nativeCatalogId = item.nativeCatalogId;
      if (nativeCatalogId != null) {
        if (!widget.controller.usesNativeWatchFaceMarket ||
            item.dialShape != latestProfile.dialShape ||
            item.binProtocol != latestProfile.binProtocol) {
          throw const DeviceWatchFaceMarketException('连接设备或表盘规格已变化，请重新进入商城');
        }
        final download = await widget.controller.downloadNativeWatchFace(
          nativeCatalogId,
        );
        if (download.catalogId != nativeCatalogId ||
            download.fileLength > latestProfile.maxFileLength) {
          throw const DeviceWatchFaceMarketException('表盘文件与当前手表规格不匹配');
        }
        filePath = download.filePath;
        fileLength = download.fileLength;
        if (mounted) setState(() => _downloadProgress = 1);
      } else {
        filePath = await _service.download(
          item,
          profile: latestProfile,
          onProgress: (progress) {
            if (mounted) setState(() => _downloadProgress = progress);
          },
        );
        fileLength = item.fileLength;
      }
      final saved = await widget.controller
          .writeDeviceFeature(DeviceFeature.watchFaces, {
            'operation': 'upload_network',
            'filePath': filePath,
            'name': item.name,
            'deviceId': latestProfile.deviceId,
            'profileFingerprint': latestProfile.profileFingerprint,
            'screenWidth': latestProfile.screenWidth,
            'screenHeight': latestProfile.screenHeight,
            'dialShape': latestProfile.dialShape,
            'maxLength': latestProfile.maxFileLength,
            'maxFileLength': latestProfile.maxFileLength,
            'fileLength': fileLength,
            'crc': item.crc,
            'binProtocol': item.binProtocol ?? latestProfile.binProtocol,
            'itemDialShape': item.dialShape ?? latestProfile.dialShape,
            'fileUrl': item.fileUrl.toString(),
            'previewUrl': item.previewUrl.toString(),
          });
      if (!mounted) return;
      final resultMessage = saved
          ? '表盘已传送并设置完成'
          : widget.controller.errorMessage ?? '表盘设置失败，请稍后重试';
      setState(() {
        _installError = saved ? null : resultMessage;
        _lastFailedInstall = saved ? null : item;
      });
      if (saved) {
        unawaited(
          widget.controller.readDeviceFeature(DeviceFeature.watchFaces),
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultMessage)));
    } on DeviceWatchFaceMarketException catch (error) {
      if (mounted) {
        setState(() {
          _installError = error.message;
          _lastFailedInstall = item;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        const message = '表盘设置失败，请稍后重试';
        setState(() {
          _installError = message;
          _lastFailedInstall = item;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _installing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('表盘商城')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          key: const Key('watch-face-market-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.profile.deviceLabel.isEmpty
                            ? '适配当前手表'
                            : '为 ${widget.profile.deviceLabel} 精选',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_total > 0)
                      Text(
                        '共 $_total 款',
                        style: const TextStyle(color: SaydianColors.muted),
                      ),
                  ],
                ),
              ),
            ),
            if (_showingCache)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    '当前展示离线缓存；安装前会重新验证已连接手表。',
                    style: TextStyle(color: SaydianColors.orange),
                  ),
                ),
              ),
            if (_installError case final message?)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SaydianColors.brandRedSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SaydianColors.brandRed.withValues(alpha: .22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: SaydianColors.brandRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '表盘未设置成功',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(message),
                              ],
                            ),
                          ),
                          if (_lastFailedInstall case final failed?)
                            TextButton(
                              onPressed: _installing == null
                                  ? () => _install(failed)
                                  : null,
                              child: const Text('重试'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_items.isEmpty && _loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.watch_outlined, size: 58),
                        const SizedBox(height: 14),
                        Text(_error ?? '暂无可用表盘', textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _loading ? null : () => _load(reset: true),
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: .72,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final installing = identical(_installing, item);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _installing == null
                            ? () => _install(item)
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _WatchFaceMarketPreview(
                                service: _service,
                                item: item,
                                profile: widget.profile,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _displayName(item, index),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (installing) ...[
                                    LinearProgressIndicator(
                                      value:
                                          _downloadProgress > 0 &&
                                              _downloadProgress < 1
                                          ? _downloadProgress
                                          : null,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _downloadProgress < 1
                                          ? '正在下载'
                                          : '正在传送到手表',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ] else
                                    const Text(
                                      '点击下载并使用',
                                      style: TextStyle(
                                        color: SaydianColors.brandRed,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _page < _pageCount
                      ? OutlinedButton(
                          onPressed: _loading ? null : _load,
                          child: Text(_loading ? '加载中…' : '加载更多'),
                        )
                      : const Center(
                          child: Text(
                            '已经到底了',
                            style: TextStyle(color: SaydianColors.muted),
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayName(DeviceWatchFaceMarketItem item, int index) {
    final raw = item.name.trim();
    final isProtocolCode =
        raw.length <= 32 &&
        !RegExp(r'[\s\u4e00-\u9fff]').hasMatch(raw) &&
        RegExp(r'[A-Za-z]').hasMatch(raw) &&
        RegExp(r'\d').hasMatch(raw);
    return raw.isEmpty || isProtocolCode ? '精选表盘 ${index + 1}' : raw;
  }
}

class _WatchFaceMarketPreview extends StatefulWidget {
  const _WatchFaceMarketPreview({
    required this.service,
    required this.item,
    required this.profile,
  });

  final DeviceWatchFaceMarketService service;
  final DeviceWatchFaceMarketItem item;
  final DeviceWatchFaceMarketProfile profile;

  @override
  State<_WatchFaceMarketPreview> createState() =>
      _WatchFaceMarketPreviewState();
}

class _WatchFaceMarketPreviewState extends State<_WatchFaceMarketPreview> {
  File? _file;
  bool _loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _WatchFaceMarketPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        _requestIdentity(oldWidget) != _requestIdentity(widget)) {
      setState(() {
        _file = null;
        _loading = true;
      });
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  String _requestIdentity(_WatchFaceMarketPreview target) => [
    target.profile.deviceId,
    target.profile.profileFingerprint,
    target.item.fileUrl,
    target.item.previewUrl,
    target.item.fileLength,
    target.item.binProtocol,
    target.item.dialShape,
  ].join('|');

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final service = widget.service;
    final item = widget.item;
    final profile = widget.profile;
    final identity = _requestIdentity(widget);
    File? file;
    try {
      file = await service.previewFile(item, profile: profile);
    } catch (_) {
      file = null;
    }
    if (mounted &&
        generation == _loadGeneration &&
        service == widget.service &&
        identity == _requestIdentity(widget)) {
      setState(() {
        _file = file;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file case final file?) return Image.file(file, fit: BoxFit.cover);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return const ColoredBox(
      color: SaydianColors.brandRedSoft,
      child: Center(
        child: Text(
          '预览暂不可用',
          textAlign: TextAlign.center,
          style: TextStyle(color: SaydianColors.muted),
        ),
      ),
    );
  }
}
