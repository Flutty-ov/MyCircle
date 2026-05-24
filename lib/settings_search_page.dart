import 'package:flutter/material.dart';

import 'settings_page.dart';
import 'telegram_settings_style.dart';
import 'about_app_page.dart';
import 'help_page.dart';
import 'profile.dart';
import 'store_page.dart';
import 'mycircle_features_channel_page.dart';
import 'tapflow_page.dart';

class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({super.key});

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState extends State<SettingsSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();

    final items = <_SettingsSearchItem>[
      _SettingsSearchItem(
        title: 'Мой профиль',
        subtitle: 'Изменить профиль',
        icon: Icons.person_outline,
      ),
      _SettingsSearchItem(
        title: 'Изменить панель навигации',
        subtitle: 'Оформление',
        icon: Icons.view_carousel_outlined,
      ),
      _SettingsSearchItem(
        title: 'Изменить обои',
        subtitle: 'Оформление',
        icon: Icons.wallpaper_outlined,
      ),
      _SettingsSearchItem(
        title: 'Цвета кнопок',
        subtitle: 'Персональные цвета',
        icon: Icons.color_lens_outlined,
      ),
      _SettingsSearchItem(
        title: 'Специальные возможности',
        subtitle: 'Настройки',
        icon: Icons.science_outlined,
      ),
      _SettingsSearchItem(
        title: 'Данные и память',
        subtitle: 'Настройки',
        icon: Icons.storage_outlined,
      ),
      _SettingsSearchItem(
        title: 'Энергосбережение',
        subtitle: 'Настройки',
        icon: Icons.battery_saver_outlined,
      ),
      _SettingsSearchItem(
        title: 'Помощь',
        subtitle: 'Поддержка',
        icon: Icons.help_outline,
      ),
      _SettingsSearchItem(
        title: 'Вопросы о MyCircle',
        subtitle: 'FAQ',
        icon: Icons.quiz_outlined,
      ),
      _SettingsSearchItem(
        title: 'Канал MyCircle',
        subtitle: 'FAQ',
        icon: Icons.lightbulb_outline,
      ),
      _SettingsSearchItem(
        title: 'О приложении',
        subtitle: 'Информация',
        icon: Icons.info_outline,
      ),
      _SettingsSearchItem(
        title: 'Магазин',
        subtitle: 'Покупки',
        icon: Icons.storefront_outlined,
      ),
      _SettingsSearchItem(
        title: 'TapFlow',
        subtitle: 'Передача файлов',
        icon: Icons.wifi_tethering_outlined,
      ),
      _SettingsSearchItem(
        title: 'Язык',
        subtitle: 'Настройки',
        icon: Icons.language_outlined,
      ),
    ];

    final filtered = q.isEmpty
        ? const <_SettingsSearchItem>[]
        : items
              .where((e) {
                final hay = '${e.title} ${e.subtitle}'.toLowerCase();
                return hay.contains(q);
              })
              .toList(growable: false);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 92),
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: cs.outlineVariant),
              itemBuilder: (context, index) {
                final it = filtered[index];
                return TelegramSettingsSection(
                  padding: EdgeInsets.zero,
                  children: [
                    TelegramSettingsTile(
                      title: it.title,
                      subtitle: it.subtitle,
                      leading: TelegramSettingsIcon(
                        icon: it.icon,
                        color: cs.primary,
                      ),
                      onTap: it.isActionable
                          ? () {
                              switch (it.title) {
                                case 'Мой профиль':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ProfilePage(),
                                    ),
                                  );
                                  break;
                                case 'Изменить панель навигации':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NavigationPanelPage(),
                                    ),
                                  );
                                  break;
                                case 'Изменить обои':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const WallpapersPage(),
                                    ),
                                  );
                                  break;
                                case 'Специальные возможности':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const AccessibilitySettingsPage(),
                                    ),
                                  );
                                  break;
                                case 'Данные и память':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const DataAndMemoryPage(),
                                    ),
                                  );
                                  break;
                                case 'Энергосбережение':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const EnergySavingPage(),
                                    ),
                                  );
                                  break;
                                case 'Помощь':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const HelpPage(),
                                    ),
                                  );
                                  break;
                                case 'Вопросы о MyCircle':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const MyCircleFaqPage(),
                                    ),
                                  );
                                  break;
                                case 'Канал MyCircle':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const MyCircleFeaturesChannelPage(),
                                    ),
                                  );
                                  break;
                                case 'О приложении':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const AboutAppPage(),
                                    ),
                                  );
                                  break;
                                case 'Магазин':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const StorePage(),
                                    ),
                                  );
                                  break;
                                case 'TapFlow':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const TapFlowPage(),
                                    ),
                                  );
                                  break;
                                case 'Язык':
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const LanguagePage(),
                                    ),
                                  );
                                  break;
                                default:
                                  break;
                              }
                            }
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Поиск',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: cs.surfaceContainerHighest,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSearchItem {
  const _SettingsSearchItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  bool get isActionable => true;
}
