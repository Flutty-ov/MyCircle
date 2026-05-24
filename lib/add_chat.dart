import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_language.dart';
import 'app_scope.dart';
import 'log_service.dart';

enum AddChatMode { create, join }

Future<void> openAddChatDialog(
  BuildContext context, {
  required AddChatMode mode,
  String? title,
}) async {
  final l10n = AppLocalizations.of(context);
  final chatIdController = TextEditingController();
  final chatNameController = TextEditingController();
  final tokenController = TextEditingController();

  final dialogTitle = title ?? (mode == AddChatMode.create
      ? l10n.get('create_chat')
      : l10n.get('join_chat'));

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final viewInsets = MediaQuery.viewInsetsOf(context);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              Center(
                child: Text(
                  dialogTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(166),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(
                    children: [
                      TextField(
                        controller: chatNameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: l10n.get('title_label'),
                          border: InputBorder.none,
                        ),
                      ),
                      Divider(height: 1, color: cs.onSurface.withAlpha(20)),
                      TextField(
                        controller: chatIdController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: l10n.get('chat_id_label'),
                          border: InputBorder.none,
                        ),
                      ),
                      Divider(height: 1, color: cs.onSurface.withAlpha(20)),
                      TextField(
                        controller: tokenController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: l10n.get('chat_token_label'),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.get('cancel')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l10n.get('add')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (result != true) return;

  final chatId = chatIdController.text.trim();
  final chatName = chatNameController.text.trim();
  final token = tokenController.text.trim();

  if (chatId.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('chat_id_required'))));
    return;
  }
  if (mode == AddChatMode.create && chatName.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('chat_name_required'))));
    return;
  }
  if (token.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('chat_token_required'))));
    return;
  }

  try {
    if (!context.mounted) return;
    final app = AppScope.of(context);

    String chatUuid;
    if (mode == AddChatMode.create) {
      LogService.instance.chat('Создание чата: $chatId');
      final exists = await Supabase.instance.client
          .from('chats')
          .select('id')
          .eq('chat_id', chatId)
          .limit(1);
      LogService.instance.api('Supabase: проверка существования чата $chatId');

      if (exists.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.get('chat_exists_error'))),
        );
        return;
      }

      final inserted = await Supabase.instance.client
          .from('chats')
          .insert({
            'chat_id': chatId,
            'name': chatName,
            'chat_token': token,
            'member_tokens': [app.characterToken],
          })
          .select('id')
          .maybeSingle();
      LogService.instance.api('Supabase: создан чат $chatId');

      chatUuid = (inserted == null ? '' : (inserted['id'] ?? '')).toString();
      chatUuid = chatUuid.trim();
      if (chatUuid.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.get('create_chat_error'))));
        return;
      }
    } else {
      LogService.instance.chat('Присоединение к чату: $chatId');
      final res = await Supabase.instance.client
          .from('chats')
          .select('id, member_tokens, chat_token')
          .eq('chat_id', chatId)
          .limit(1)
          .maybeSingle();
      LogService.instance.api('Supabase: поиск чата $chatId');

      if (res == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.get('chat_not_found_server'))),
        );
        return;
      }

      chatUuid = (res['id'] ?? '').toString().trim();
      if (chatUuid.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.get('no_chat_uuid'))),
        );
        return;
      }

      final serverToken = (res['chat_token'] ?? '').toString().trim();
      if (serverToken.isNotEmpty && serverToken != token) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.get('invalid_chat_token'))));
        return;
      }

      final rawMembers = res['member_tokens'];
      final members = <String>{};
      if (rawMembers is List) {
        for (final e in rawMembers) {
          final t = (e ?? '').toString().trim();
          if (t.isNotEmpty) members.add(t);
        }
      }
      if (!members.contains(app.characterToken)) {
        try {
          members.add(app.characterToken);
          await Supabase.instance.client
              .from('chats')
              .update({'member_tokens': members.toList(growable: false)})
              .eq('id', chatUuid);
        } catch (_) {
          // ignore
        }
      }
    }

    if (!context.mounted) return;
    await app.addChat(chatUuid: chatUuid, chatId: chatId, chatName: chatName);
    await app.setChatToken(chatUuid: chatUuid, token: token);
  } catch (e) {
    if (!context.mounted) return;
    final msg = e is PostgrestException
        ? '${e.code ?? ''} ${e.message}'.trim()
        : e.toString();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg.isEmpty ? l10n.get('error_fallback') : msg)));
  }
}
