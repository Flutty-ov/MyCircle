import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_language.dart';
import 'app_scope.dart';
import 'tapflow_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = AppScope.of(context);
    final name = (controller.displayName ?? '').trim();
    final birthday = controller.birthday;
    final supabaseUrl = controller.supabaseUrl;
    final supabaseAnonKey = controller.supabaseAnonKey;

    String formatDate(DateTime value) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(value.day)}.${two(value.month)}.${value.year}';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(''),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Text(
                      name.isNotEmpty
                          ? name.characters.first.toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name.isEmpty ? l10n.get('nameless') : name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.get('info_section'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        name.isEmpty ? l10n.get('nameless') : name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.get('name'),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(153),
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        birthday == null ? l10n.get('not_specified') : formatDate(birthday),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.get('birth_date_label'),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(153),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            supabaseUrl.isEmpty ? l10n.get('not_specified') : supabaseUrl,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.get('sup_api_label'),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withAlpha(153),
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            supabaseAnonKey.isEmpty
                                ? l10n.get('not_specified')
                                : supabaseAnonKey,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.get('sup_pub_key_label'),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withAlpha(153),
                                ),
                          ),
                        ),
                        const SizedBox(height: 46),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (ctx) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.wifi_tethering),
                                    title: Text(l10n.get('send_via_tapflow')),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => TapFlowPage(
                                            mode: TapFlowMode.sendSupabase,
                                            supabaseUrl: supabaseUrl,
                                            supabaseAnonKey: supabaseAnonKey,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.copy),
                                    title: Text(l10n.get('copy_and_share')),
                                    onTap: () async {
                                      final text =
                                          '${l10n.get('sup_api_label')}\n$supabaseUrl\n\n${l10n.get('sup_pub_key_label')}\n$supabaseAnonKey';
                                      await Clipboard.setData(
                                        ClipboardData(text: text),
                                      );
                                      if (!context.mounted) return;
                                      Navigator.of(ctx).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(l10n.get('copied')),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.ios_share),
                      label: Text(l10n.get('share_btn')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
