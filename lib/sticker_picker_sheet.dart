import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'cache_service.dart';
import 'mycircle_supabase.dart';

class StickerPickerSheet extends StatefulWidget {
  const StickerPickerSheet({this.onPicked, this.popOnPick = true, super.key});

  final ValueChanged<String>? onPicked;
  final bool popOnPick;

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  late final Future<List<String>> _future = _load();

  static const String _kAddedStickerPacksKey = 'store_added_sticker_pack_ids';

  Future<List<String>> _load() async {
    final p = await SharedPreferences.getInstance();
    final ids = (p.getStringList(_kAddedStickerPacksKey) ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) return const <String>[];

    final res = await MyCircleSupabase.client
        .from('sticker_packs')
        .select('id, stickers')
        .inFilter('id', ids)
        .limit(200);

    final out = <String>[];
    for (final row in (res as List)) {
      if (row is! Map) continue;
      final stickers = row['stickers'];
      if (stickers is List) {
        for (final s in stickers) {
          final url = (s ?? '').toString().trim();
          if (url.isNotEmpty) out.add(url);
        }
      }
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: FutureBuilder<List<String>>(
        future: _future,
        builder: (context, snap) {
          final urls = snap.data ?? const <String>[];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${AppLocalizations.of(context).get('sticker_load_error')}\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (urls.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context).get('add_sticker_packs_hint'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: urls.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final url = urls[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  widget.onPicked?.call(url);
                  if (widget.popOnPick) {
                    Navigator.of(context).pop(url);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: _CachedStickerCell(url: url),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CachedStickerCell extends StatefulWidget {
  const _CachedStickerCell({required this.url});

  final String url;

  @override
  State<_CachedStickerCell> createState() => _CachedStickerCellState();
}

class _CachedStickerCellState extends State<_CachedStickerCell> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = CacheService.instance.getFileFromCache(
      widget.url,
      category: CacheCategory.sticker,
    );
  }

  @override
  void didUpdateWidget(covariant _CachedStickerCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = CacheService.instance.getFileFromCache(
        widget.url,
        category: CacheCategory.sticker,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return Padding(
            padding: const EdgeInsets.all(6),
            child: Image.file(file, fit: BoxFit.contain),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) =>
                const Center(child: Icon(Icons.broken_image)),
          ),
        );
      },
    );
  }
}
