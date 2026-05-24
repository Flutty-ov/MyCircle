import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_chat.dart';
import 'app_language.dart';

class StartChatPage extends StatelessWidget {
  const StartChatPage({
    required this.channels,
    required this.onOpenChat,
    super.key,
  });

  final List<Map<String, String>> channels;
  final void Function(BuildContext context, Map<String, String> row) onOpenChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final usable = channels
        .where((e) {
          final name = (e['chatName'] ?? '').toString().trim();
          final id = (e['chatId'] ?? '').toString().trim();
          final uuid = (e['chatUuid'] ?? '').toString().trim();
          return name.isNotEmpty || id.isNotEmpty || uuid.isNotEmpty;
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.get('start_chat'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: usable.isEmpty
                ? null
                : () async {
                    final row = await showSearch<Map<String, String>?>(
                      context: context,
                      delegate: _ChatSearchDelegate(chats: usable),
                    );
                    if (row == null) return;
                    if (!context.mounted) return;
                    onOpenChat(context, row);
                  },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.group_add_outlined,
                    iconColor: const Color(0xFF34C759),
                    title: l10n.get('create_chat'),
                    onTap: () => openAddChatDialog(
                      context,
                      mode: AddChatMode.create,
                      title: l10n.get('create_chat'),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 52,
                    color: cs.outlineVariant.withValues(alpha: 0.25),
                  ),
                  _ActionTile(
                    icon: Icons.add_link,
                    iconColor: const Color(0xFF007AFF),
                    title: l10n.get('join_chat'),
                    onTap: () => openAddChatDialog(
                      context,
                      mode: AddChatMode.join,
                      title: l10n.get('join_chat'),
                    ),
                  ),
                ],
              ),
            ),
            if (usable.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Мои чаты',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildChatRows(context, usable, onOpenChat: onOpenChat),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: cs.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate<Map<String, String>?> {
  _ChatSearchDelegate({required this.chats});

  final List<Map<String, String>> chats;

  String _displayTitle(Map<String, String> row) {
    final name = (row['chatName'] ?? '').toString().trim();
    final id = (row['chatId'] ?? '').toString().trim();
    return name.isNotEmpty ? name : (id.isNotEmpty ? id : 'Чат');
  }

  @override
  String get searchFieldLabel => 'Поиск';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  List<Map<String, String>> _filtered() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return chats
        .where((row) {
          final name = (row['chatName'] ?? '').toString().toLowerCase();
          final id = (row['chatId'] ?? '').toString().toLowerCase();
          final uuid = (row['chatUuid'] ?? '').toString().toLowerCase();
          return name.contains(q) || id.contains(q) || uuid.contains(q);
        })
        .toList(growable: false);
  }

  @override
  Widget buildResults(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _filtered();
    if (items.isEmpty) {
      return Center(
        child: Text(l10n.get('nothing_found')),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = items[index];
        return ListTile(
          title: Text(_displayTitle(row)),
          subtitle: Text((row['chatId'] ?? '').toString().trim()),
          onTap: () => close(context, row),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

List<Widget> _buildChatRows(
  BuildContext context,
  List<Map<String, String>> chats, {
  required void Function(BuildContext context, Map<String, String> row)
  onOpenChat,
}) {
  String displayTitle(Map<String, String> row) {
    final name = (row['chatName'] ?? '').toString().trim();
    final id = (row['chatId'] ?? '').toString().trim();
    return name.isNotEmpty ? name : (id.isNotEmpty ? id : 'Чат');
  }

  final sorted = [...chats]
    ..sort(
      (a, b) => displayTitle(
        a,
      ).toLowerCase().compareTo(displayTitle(b).toLowerCase()),
    );

  String? lastLetter;
  final out = <Widget>[];
  for (final row in sorted) {
    final title = displayTitle(row);
    final trimmed = title.trim();
    final letter = trimmed.isEmpty
        ? '#'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final showLetter = lastLetter != letter;
    if (showLetter) lastLetter = letter;

    out.add(
      _ChatRow(
        letter: showLetter ? letter : null,
        title: title,
        row: row,
        onTap: () => onOpenChat(context, row),
        onLongPress: () => _showChatInfoSheet(context, row, title: title),
      ),
    );
  }

  return out;
}

Future<void> _showChatInfoSheet(
  BuildContext context,
  Map<String, String> row, {
  required String title,
}) async {
  final l10n = AppLocalizations.of(context);
  final chatUuid = (row['chatUuid'] ?? '').toString().trim();
  final chatId = (row['chatId'] ?? '').toString().trim();
  final cs = Theme.of(context).colorScheme;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final text = [
        if (title.isNotEmpty) l10n.get('name_prefix').replaceAll('\$title', title),
        if (chatId.isNotEmpty) 'ID: $chatId',
        if (chatUuid.isNotEmpty) 'UUID: $chatUuid',
      ].join('\n');

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    text.isEmpty
                        ? l10n.get('no_data')
                        : text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.get('chat_data_copied')),
                    ),
                  );
                },
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(l10n.get('share')),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.letter,
    required this.title,
    required this.row,
    required this.onTap,
    required this.onLongPress,
  });

  final String? letter;
  final String title;
  final Map<String, String> row;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trimmed = title.trim();
    final first = trimmed.isEmpty
        ? '#'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  letter ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary.withValues(alpha: 0.18),
                child: Text(
                  first,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
