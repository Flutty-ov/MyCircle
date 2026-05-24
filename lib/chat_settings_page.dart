import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_scope.dart';

class ChatSettingsPage extends StatefulWidget {
  const ChatSettingsPage({
    required this.chatUuid,
    required this.chatId,
    required this.chatName,
    super.key,
  });

  final String chatUuid;
  final String chatId;
  final String chatName;

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  late String _displayName;
  bool _editingName = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayName = widget.chatName;
    _nameCtrl.text = widget.chatName;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    final newName = app.getChatDisplayName(
      chatUuid: widget.chatUuid,
      fallback: widget.chatName,
    );
    if (newName != _displayName) {
      setState(() {
        _displayName = newName;
        _nameCtrl.text = newName;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final trimmed = _nameCtrl.text.trim();
    if (trimmed.isEmpty) return;

    final app = AppScope.of(context);
    await app.setChatDisplayName(chatUuid: widget.chatUuid, name: trimmed);

    if (!mounted) return;
    setState(() {
      _displayName = trimmed;
      _editingName = false;
    });
  }

  void _cancelEdit() {
    _nameCtrl.text = _displayName;
    setState(() => _editingName = false);
  }

  void _changeIcon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Смена иконки скоро будет доступна')),
    );
  }

  Future<void> _leaveChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Покинуть чат?'),
        content: const Text(
          'Вы будете удалены из чата. '
          'Чтобы вернуться, потребуется заново ввести токен и ID чата.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Покинуть'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final app = AppScope.of(context);
    final myToken = app.characterToken;

    try {
      final chatRow = await Supabase.instance.client
          .from('chats')
          .select('member_tokens')
          .eq('id', widget.chatUuid)
          .limit(1)
          .maybeSingle();

      final raw = chatRow?['member_tokens'];
      final tokens = <String>[];
      if (raw is List) {
        for (final e in raw) {
          final t = (e ?? '').toString().trim();
          if (t.isNotEmpty) tokens.add(t);
        }
      }

      tokens.remove(myToken);

      await Supabase.instance.client
          .from('chats')
          .update({'member_tokens': tokens})
          .eq('id', widget.chatUuid);

      if (!mounted) return;
      await app.removeChats({widget.chatUuid});

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Вы покинули чат')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = _displayName.isNotEmpty
        ? _displayName[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Настройки чата',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _changeIcon,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [cs.primary, cs.tertiary],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _displayName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _editingName
                      ? _NameEditor(
                          controller: _nameCtrl,
                          onSave: _saveName,
                          onCancel: _cancelEdit,
                        )
                      : _SettingsTile(
                          icon: Icons.edit_outlined,
                          title: 'Название',
                          subtitle: _displayName,
                          onTap: () => setState(() => _editingName = true),
                        ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: _LeaveChatButton(onTap: _leaveChat),
          ),
        ],
      ),
    );
  }
}

class _NameEditor extends StatelessWidget {
  const _NameEditor({
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
              filled: true,
              fillColor: cs.surface,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCancel,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Отмена',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onSave,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      child: Text(
                        'Сохранить',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveChatButton extends StatelessWidget {
  const _LeaveChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.error.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.exit_to_app_rounded, color: cs.error, size: 20),
              const SizedBox(width: 10),
              Text(
                'Покинуть чат',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
