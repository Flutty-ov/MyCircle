import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'cache_service.dart';
import 'mycircle_supabase.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StoreStickerPack {
  const _StoreStickerPack({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.stickers,
  });

  final String id;
  final String name;
  final String iconUrl;
  final List<String> stickers;

  static _StoreStickerPack fromJson(Map<String, dynamic> json) {
    final rawStickers = json['stickers'];
    final list = <String>[];

    if (rawStickers is List) {
      for (final e in rawStickers) {
        final s = (e ?? '').toString().trim();
        if (s.isNotEmpty) list.add(s);
      }
    } else if (rawStickers is String) {
      final s = rawStickers.trim();
      if (s.isNotEmpty) list.add(s);
    }

    return _StoreStickerPack(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      iconUrl: (json['icon_glav'] ?? '').toString(),
      stickers: list,
    );
  }
}

class _StorePageState extends State<StorePage> {
  late final Future<List<_StoreStickerPack>> _future = _load();
  Set<String> _addedPackIds = <String>{};
  Set<String> _downloadingPackIds = <String>{};

  static const String _kAddedStickerPacksKey = 'store_added_sticker_pack_ids';

  @override
  void initState() {
    super.initState();
    _loadAddedPacks();
  }

  Future<void> _loadAddedPacks() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kAddedStickerPacksKey) ?? const <String>[];
    if (!mounted) return;
    setState(() => _addedPackIds = raw.toSet());
  }

  Future<void> _saveAddedPacks() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kAddedStickerPacksKey, _addedPackIds.toList());
  }

  Future<List<_StoreStickerPack>> _load() async {
    final res = await MyCircleSupabase.client
        .from('sticker_packs')
        .select('id, name, icon_glav, stickers')
        .order('id', ascending: true)
        .limit(200);

    return res
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .map((e) => _StoreStickerPack.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(AppLocalizations.of(context).get('shop')),
      ),
      body: FutureBuilder<List<_StoreStickerPack>>(
        future: _future,
        builder: (context, snap) {
          final packs = snap.data ?? const <_StoreStickerPack>[];

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${AppLocalizations.of(context).get('shop_load_error')}${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (packs.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context).get('no_sticker_packs')),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: packs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final p = packs[index];
              final added = _addedPackIds.contains(p.id);
              final downloading = _downloadingPackIds.contains(p.id);
              return Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _StickerPackDetailsPage(pack: p),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _PackIcon(url: p.iconUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.get('stickers_count').replaceAll('\$count', p.stickers.length.toString()),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (added)
                          Text(AppLocalizations.of(context).get('added'))
                        else if (downloading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          TextButton(
                            onPressed: () => _downloadPack(p),
                            child: Text(
                              AppLocalizations.of(context).get('add'),
                            ),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _downloadPack(_StoreStickerPack pack) async {
    if (_addedPackIds.contains(pack.id)) return;
    if (_downloadingPackIds.contains(pack.id)) return;
    if (pack.stickers.isEmpty) return;

    setState(() {
      _downloadingPackIds = {..._downloadingPackIds, pack.id};
    });

    bool ok = true;
    try {
      for (final url in pack.stickers) {
        final f = await CacheService.instance.getOrDownloadFile(
          url,
          allowDownload: true,
          forceDownload: false,
          category: CacheCategory.sticker,
        );
        if (f == null) {
          ok = false;
          break;
        }
      }
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;

    setState(() {
      final nextDownloading = {..._downloadingPackIds};
      nextDownloading.remove(pack.id);
      _downloadingPackIds = nextDownloading;
      if (ok) {
        _addedPackIds = {..._addedPackIds, pack.id};
      }
    });

    if (ok) {
      await _saveAddedPacks();
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.get('pack_added') : l10n.get('pack_download_failed')),
      ),
    );
  }
}

class _StickerPackDetailsPage extends StatelessWidget {
  const _StickerPackDetailsPage({required this.pack});

  final _StoreStickerPack pack;

  @override
  Widget build(BuildContext context) {
    final stickers = pack.stickers;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(pack.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: stickers.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final url = stickers[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) {
                      return const Center(child: Icon(Icons.broken_image));
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PackIcon extends StatelessWidget {
  const _PackIcon({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 54,
        height: 54,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: url.trim().isEmpty
              ? const Icon(Icons.image_outlined)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) {
                    return const Icon(Icons.broken_image);
                  },
                ),
        ),
      ),
    );
  }
}
