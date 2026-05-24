import 'dart:async';
import 'dart:io';

import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:ras/cache_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'app_language.dart';

class MemoryUsagePage extends StatefulWidget {
  const MemoryUsagePage({super.key});

  @override
  State<MemoryUsagePage> createState() => _MemoryUsagePageState();
}

enum _StorageMediaTab { media, files, music }

class _MemoryUsagePageState extends State<MemoryUsagePage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  int _totalCacheBytes = 0;
  Map<CacheCategory, int> _byCategory = const <CacheCategory, int>{};
  double _totalDiskGb = 0;
  int? _maxCacheBytes;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _tiltX = 0;

  _StorageMediaTab _tab = _StorageMediaTab.media;

  @override
  void initState() {
    super.initState();
    _accelSub = accelerometerEventStream().listen((e) {
      final next = e.x.clamp(-6.0, 6.0).toDouble();
      if (!mounted) return;
      setState(() => _tiltX = next);
    });

    _load();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final totalCache = await CacheService.instance.getCacheSizeBytes();
    final byCategory = await CacheService.instance.getCacheBreakdownBytes();
    final maxBytes = await CacheService.instance.getMaxCacheBytes();
    double totalDiskGb = 0;
    try {
      final disk = DiskSpacePlus();
      totalDiskGb = (await disk.getTotalDiskSpace) ?? 0;
    } catch (_) {
      totalDiskGb = 0;
    }

    if (!mounted) return;
    setState(() {
      _totalCacheBytes = totalCache;
      _byCategory = byCategory;
      _totalDiskGb = totalDiskGb;
      _maxCacheBytes = maxBytes;
      _loading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 ${AppLocalizations.of(context).get('byte_unit_b')}';
    }
    final units = [
      AppLocalizations.of(context).get('byte_unit_b'),
      AppLocalizations.of(context).get('byte_unit_kb'),
      AppLocalizations.of(context).get('byte_unit_mb'),
      AppLocalizations.of(context).get('byte_unit_gb'),
      AppLocalizations.of(context).get('byte_unit_tb'),
    ];
    double v = bytes.toDouble();
    int u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    final s = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$s ${units[u]}';
  }

  String _formatGb(double gb) {
    if (gb <= 0) return '0 ${AppLocalizations.of(context).get('gb_unit')}';
    final s = gb >= 10 ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1);
    return '$s ${AppLocalizations.of(context).get('gb_unit')}';
  }

  Color _categoryColor(CacheCategory c) {
    switch (c) {
      case CacheCategory.video:
        return const Color(0xFF4FC3F7);
      case CacheCategory.photo:
        return const Color(0xFF1976D2);
      case CacheCategory.file:
        return const Color(0xFF43A047);
      case CacheCategory.sticker:
        return const Color(0xFFFF9800);
      case CacheCategory.other:
        return const Color(0xFF7E57C2);
    }
  }

  String _categoryTitle(CacheCategory c) {
    final l10n = AppLocalizations.of(context);
    switch (c) {
      case CacheCategory.video:
        return l10n.get('video');
      case CacheCategory.photo:
        return l10n.get('photo');
      case CacheCategory.file:
        return l10n.get('files');
      case CacheCategory.sticker:
        return l10n.get('stickers');
      case CacheCategory.other:
        return l10n.get('other');
    }
  }

  Future<void> _setMaxCache(int? bytes) async {
    await CacheService.instance.setMaxCacheBytes(bytes);
    await _load();
  }

  Future<void> _confirmClear({CacheCategory? category}) async {
    final l10n = AppLocalizations.of(context);
    final bytes = category == null
        ? _totalCacheBytes
        : (_byCategory[category] ?? 0);
    final title = l10n.get('clear_cache');
    final sizeText = _formatBytes(bytes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$title ($sizeText)'),
          content: Text(l10n.get('clear_cache_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.get('cancel_btn')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.get('clear_btn')),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await CacheService.instance.clearCacheByCategory(category);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalGb = _totalDiskGb;
    final usedGb = _totalCacheBytes / (1024 * 1024 * 1024);
    final fill = totalGb > 0 ? (usedGb / totalGb).clamp(0.0, 1.0) : 0.0;
    final usedText = _formatBytes(_totalCacheBytes);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('memory_usage')),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _MemoryCategoryButton(
                              title: _categoryTitle(CacheCategory.video),
                              sizeText: _formatBytes(
                                _byCategory[CacheCategory.video] ?? 0,
                              ),
                              color: _categoryColor(CacheCategory.video),
                              onTap: () =>
                                  _confirmClear(category: CacheCategory.video),
                            ),
                            const SizedBox(height: 10),
                            _MemoryCategoryButton(
                              title: _categoryTitle(CacheCategory.photo),
                              sizeText: _formatBytes(
                                _byCategory[CacheCategory.photo] ?? 0,
                              ),
                              color: _categoryColor(CacheCategory.photo),
                              onTap: () =>
                                  _confirmClear(category: CacheCategory.photo),
                            ),
                            const SizedBox(height: 10),
                            _MemoryCategoryButton(
                              title: _categoryTitle(CacheCategory.file),
                              sizeText: _formatBytes(
                                _byCategory[CacheCategory.file] ?? 0,
                              ),
                              color: _categoryColor(CacheCategory.file),
                              onTap: () =>
                                  _confirmClear(category: CacheCategory.file),
                            ),
                            const SizedBox(height: 10),
                            _MemoryCategoryButton(
                              title: _categoryTitle(CacheCategory.sticker),
                              sizeText: _formatBytes(
                                _byCategory[CacheCategory.sticker] ?? 0,
                              ),
                              color: _categoryColor(CacheCategory.sticker),
                              onTap: () => _confirmClear(
                                category: CacheCategory.sticker,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _MemoryCategoryButton(
                              title: _categoryTitle(CacheCategory.other),
                              sizeText: _formatBytes(
                                _byCategory[CacheCategory.other] ?? 0,
                              ),
                              color: _categoryColor(CacheCategory.other),
                              onTap: () =>
                                  _confirmClear(category: CacheCategory.other),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => _confirmClear(category: null),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                '${AppLocalizations.of(context).get('clear_cache_with_size')} (${_formatBytes(_totalCacheBytes)})',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CustomPaint(
                          painter: _LiquidStoragePainter(
                            background: cs.surfaceContainerHighest,
                            liquid: cs.primary,
                            fill: fill,
                            tiltX: _tiltX,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  AppLocalizations.of(context).get('occupied'),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$usedText / ${_formatGb(totalGb)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppLocalizations.of(context).get('max_cache_size'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  _MaxCacheSelector(
                    selectedBytes: _maxCacheBytes,
                    onSelectBytes: _setMaxCache,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context).get('max_cache_desc'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          title: AppLocalizations.of(context).get('media'),
                          selected: _tab == _StorageMediaTab.media,
                          onTap: () => setState(() {
                            _tab = _StorageMediaTab.media;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TabButton(
                          title: AppLocalizations.of(context).get('files_tab'),
                          selected: _tab == _StorageMediaTab.files,
                          onTap: () => setState(() {
                            _tab = _StorageMediaTab.files;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TabButton(
                          title: AppLocalizations.of(context).get('music'),
                          selected: _tab == _StorageMediaTab.music,
                          onTap: () => setState(() {
                            _tab = _StorageMediaTab.music;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  switch (_tab) {
                    _StorageMediaTab.media => const _MediaGrid(),
                    _StorageMediaTab.files => Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).get('files_soon'),
                        ),
                      ),
                    ),
                    _StorageMediaTab.music => Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).get('music_soon'),
                        ),
                      ),
                    ),
                  },
                ],
              ),
            ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? cs.onPrimary : cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: CacheService.instance.getCachedUrlsByCategory(
        CacheCategory.photo,
        limit: 600,
      ),
      builder: (context, snapshot) {
        final urls = snapshot.data ?? const <String>[];
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${AppLocalizations.of(context).get('cache_prefix')}${snapshot.error}',
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (urls.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                AppLocalizations.of(context).get('no_downloaded_media'),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: urls.length,
          itemBuilder: (context, index) {
            final url = urls[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        opaque: false,
                        pageBuilder: (_, _, _) =>
                            _StorageFullscreenImageViewer(imageUrl: url),
                      ),
                    );
                  },
                  child: _StorageCachedThumb(url: url),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StorageCachedThumb extends StatefulWidget {
  const _StorageCachedThumb({required this.url});

  final String url;

  @override
  State<_StorageCachedThumb> createState() => _StorageCachedThumbState();
}

class _StorageCachedThumbState extends State<_StorageCachedThumb> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = CacheService.instance.getFileFromCache(
      widget.url,
      category: CacheCategory.photo,
    );
  }

  @override
  void didUpdateWidget(covariant _StorageCachedThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = CacheService.instance.getFileFromCache(
        widget.url,
        category: CacheCategory.photo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return Image.file(file, fit: BoxFit.cover);
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return ColoredBox(
            color: cs.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return ColoredBox(color: cs.surfaceContainerHighest);
      },
    );
  }
}

class _StorageFullscreenImageViewer extends StatefulWidget {
  const _StorageFullscreenImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  State<_StorageFullscreenImageViewer> createState() =>
      _StorageFullscreenImageViewerState();
}

class _StorageFullscreenImageViewerState
    extends State<_StorageFullscreenImageViewer> {
  final TransformationController _tc = TransformationController();
  bool _panEnabled = false;

  Future<File?>? _fileFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fileFuture ??= () async {
      return CacheService.instance.getFileFromCache(
        widget.imageUrl,
        category: CacheCategory.photo,
      );
    }();
  }

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    _tc.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _tc.value.getMaxScaleOnAxis();
    final pan = scale > 1.01;
    if (pan != _panEnabled) {
      setState(() {
        _panEnabled = pan;
      });
    }
    if (!pan) {
      final m = _tc.value;
      if (m.storage[12] != 0 || m.storage[13] != 0) {
        _tc.value = Matrix4.identity();
      }
    }
  }

  Future<void> _download(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final ok = await GallerySaver.saveImage(
        widget.imageUrl,
        albumName: 'MyCircle',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok == true
                ? l10n.get('downloaded_to_mycircle')
                : l10n.get('download_failed'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.get('download_error')}: $e')),
      );
    }
  }

  Future<void> _openMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(AppLocalizations.of(context).get('download')),
                onTap: () => Navigator.of(context).pop('download'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'download' && context.mounted) {
      await _download(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: _tc,
              panEnabled: _panEnabled,
              scaleEnabled: true,
              boundaryMargin: EdgeInsets.zero,
              minScale: 0.8,
              maxScale: 4,
              child: FutureBuilder<File?>(
                future: _fileFuture,
                builder: (context, snap) {
                  final file = snap.data;
                  if (file != null) {
                    return Image.file(file, fit: BoxFit.contain);
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          Positioned(
            top: top + 12,
            left: 12,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: top + 12,
            right: 12,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _openMenu(context),
                icon: const Icon(Icons.more_vert, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCategoryButton extends StatelessWidget {
  const _MemoryCategoryButton({
    required this.title,
    required this.sizeText,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String sizeText;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              sizeText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaxCacheSelector extends StatefulWidget {
  const _MaxCacheSelector({
    required this.selectedBytes,
    required this.onSelectBytes,
  });

  final int? selectedBytes;
  final ValueChanged<int?> onSelectBytes;

  @override
  State<_MaxCacheSelector> createState() => _MaxCacheSelectorState();
}

class _MaxCacheSelectorState extends State<_MaxCacheSelector>
    with SingleTickerProviderStateMixin {
  static const int _gb = 1024 * 1024 * 1024;
  static const _options = <int?>[5 * _gb, 16 * _gb, 32 * _gb, null];

  late final AnimationController _controller;
  double _from = 0;
  double _to = 0;

  int _indexFor(int? bytes) {
    final idx = _options.indexWhere((e) => e == bytes);
    return idx == -1 ? 3 : idx;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final i = _indexFor(widget.selectedBytes);
    _from = i.toDouble();
    _to = i.toDouble();
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _MaxCacheSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedBytes != widget.selectedBytes) {
      final next = _indexFor(widget.selectedBytes).toDouble();
      _from = _currentPos;
      _to = next;
      _controller
        ..value = 0
        ..forward();
    }
  }

  double get _currentPos => _from + (_to - _from) * _controller.value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget labelFor(int idx) {
      final l10n = AppLocalizations.of(context);
      switch (idx) {
        case 0:
          return Text('5${l10n.get('gb_unit')}');
        case 1:
          return Text('16${l10n.get('gb_unit')}');
        case 2:
          return Text('32${l10n.get('gb_unit')}');
        default:
          return const Icon(Icons.all_inclusive, size: 20);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 26,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _MaxCacheSelectorPainter(
                  color: cs.primary,
                  base: cs.onSurface.withValues(alpha: 0.14),
                  pos: _currentPos,
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < 4; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onSelectBytes(_options[i]),
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < 4; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSelectBytes(_options[i]),
                  child: Center(
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                      child: labelFor(i),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MaxCacheSelectorPainter extends CustomPainter {
  _MaxCacheSelectorPainter({
    required this.color,
    required this.base,
    required this.pos,
  });

  final Color color;
  final Color base;
  final double pos; // 0..3

  @override
  void paint(Canvas canvas, Size size) {
    final trackY = 12.0;
    final segment = size.width / 4;
    final left = segment / 2;
    final right = size.width - segment / 2;
    final step = segment;

    final basePaint = Paint()
      ..color = base
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, trackY), Offset(right, trackY), basePaint);

    for (int i = 0; i < 4; i++) {
      final x = left + step * i;
      canvas.drawCircle(Offset(x, trackY), 6, Paint()..color = base);
    }

    final x = left + step * pos;
    final frac = (pos - pos.floorToDouble()).abs();
    final stretch = (frac * (1 - frac)) * 40;
    final w = 16 + stretch;
    final h = 16.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, trackY), width: w, height: h),
      const Radius.circular(999),
    );
    canvas.drawRRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MaxCacheSelectorPainter oldDelegate) {
    return oldDelegate.pos != pos ||
        oldDelegate.color != color ||
        oldDelegate.base != base;
  }
}

class _LiquidStoragePainter extends CustomPainter {
  _LiquidStoragePainter({
    required this.background,
    required this.liquid,
    required this.fill,
    required this.tiltX,
  });

  final Color background;
  final Color liquid;
  final double fill;
  final double tiltX;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(26),
    );

    final bgPaint = Paint()..color = background;
    canvas.drawRRect(r, bgPaint);

    final clipPath = Path()..addRRect(r);
    canvas.save();
    canvas.clipPath(clipPath);

    final levelY = size.height * (1.0 - fill);

    final tilt = (tiltX / 6.0).clamp(-1.0, 1.0);
    final leftY = (levelY + tilt * 14).clamp(0.0, size.height);
    final rightY = (levelY - tilt * 14).clamp(0.0, size.height);

    final p = Path();
    p.moveTo(0, size.height);
    p.lineTo(0, leftY);
    p.lineTo(size.width, rightY);
    p.lineTo(size.width, size.height);
    p.close();

    final paint = Paint()..color = liquid;
    canvas.drawPath(p, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidStoragePainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.tiltX != tiltX ||
        oldDelegate.background != background ||
        oldDelegate.liquid != liquid;
  }
}
