import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'store_page.dart';

import 'app_language.dart';
import 'app_scope.dart';
import 'cache_service.dart';
import 'notifications_service.dart';
import 'storage.dart';
import 'tapflow_page.dart';
import 'telegram_settings_page.dart';
import 'telegram_settings_style.dart';
import 'mycircle_features_channel_page.dart';
import 'help_page.dart';
import 'profile.dart';
import 'registration_page.dart';
import 'about_app_page.dart';
import 'dev_notice.dart';
import 'devices_page.dart';
import 'auto_cleanup_page.dart';
import 'app_logs_page.dart';
import 'log_service.dart';

class NavigationPanelPage extends StatefulWidget {
  const NavigationPanelPage({super.key});

  @override
  State<NavigationPanelPage> createState() => _NavigationPanelPageState();
}

class _NavigationPanelPageState extends State<NavigationPanelPage> {
  bool _initialized = false;
  bool _messengerNavEnabled = false;
  bool _messengerNavLensFlipY = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final controller = AppScope.of(context);
    _messengerNavEnabled = controller.messengerNavEnabled;
    _messengerNavLensFlipY = controller.messengerNavLensFlipY;
    _initialized = true;
  }

  Future<void> _openBottomMenuSheet() async {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SizedBox(
          height: 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
                child: Row(
                  children: [
                    Text(
                      l10n.get('quick_access'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: l10n.get('close_tooltip'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  l10n.get('in_development'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.surfaceContainerHighest,
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppLocalizations.of(context).get('done')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(AppLocalizations.of(context).get('navigation_panel')),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 14),
        children: [
          TelegramSettingsSection(
            children: [
              TelegramSettingsTile(
                title: l10n.get('ios_navigation_panel'),
                subtitle: l10n.get('ios_navigation_panel_desc'),
                leading: const TelegramSettingsIcon(
                  icon: Icons.phone_iphone,
                  color: Color(0xFF007AFF),
                ),
                trailing: Switch(
                  value: _messengerNavEnabled,
                  activeThumbColor: cs.primary,
                  onChanged: (v) async {
                    setState(() => _messengerNavEnabled = v);
                    final controller = AppScope.of(context);
                    await controller.setMessengerNavEnabled(v);
                  },
                ),
              ),
              TelegramSettingsTile(
                title: l10n.get('invert_lens'),
                subtitle: l10n.get('invert_lens_desc'),
                leading: const TelegramSettingsIcon(
                  icon: Icons.flip_camera_android,
                  color: Color(0xFFAF52DE),
                ),
                trailing: Switch(
                  value: _messengerNavLensFlipY,
                  activeThumbColor: cs.primary,
                  onChanged: (v) async {
                    setState(() => _messengerNavLensFlipY = v);
                    final controller = AppScope.of(context);
                    await controller.setMessengerNavLensFlipY(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TelegramSettingsSection(
            children: [
              TelegramSettingsTile(
                title: l10n.get('bottom_menu'),
                leading: const TelegramSettingsIcon(
                  icon: Icons.grid_view_rounded,
                  color: Color(0xFFFF9500),
                ),
                onTap: _openBottomMenuSheet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _nameController;
  bool _initialized = false;
  String _initialName = '';
  Timer? _nameSaveDebounce;

  void _openSimpleInfo(BuildContext context, String title) {
    final l10n = AppLocalizations.of(context);
    if (title == l10n.get('questions_about_mycircle')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MyCircleFaqPage()));
      return;
    }
    if (title == l10n.get('about')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AboutAppPage()));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _SimpleInfoPage(title: title)),
    );
  }

  void _openMyCircleFeatures(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MyCircleFeaturesChannelPage(),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = AppScope.of(context);
    _initialName = controller.displayName ?? '';
    _nameController = TextEditingController(text: _initialName);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    if (_initialized) {
      _nameSaveDebounce?.cancel();
      _nameController.dispose();
    }
    super.dispose();
  }

  void _onNameChanged() {
    if (!widget.embedded) return;
    _nameSaveDebounce?.cancel();
    _nameSaveDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final controller = AppScope.of(context);
      final trimmed = _nameController.text.trim();
      if (trimmed.isNotEmpty && trimmed != _initialName) {
        await controller.setDisplayName(trimmed);
        _initialName = trimmed;
      }
    });
  }

  String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}';
  }

  Future<void> _pickBirthday(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = AppScope.of(context);
    final existing = controller.birthday;

    final now = DateTime.now();
    int day = existing?.day ?? 1;
    int month = existing?.month ?? 1;
    int year = existing?.year ?? (now.year - 18);

    int daysInMonth(int y, int m) => DateUtils.getDaysInMonth(y, m);

    final dayController = FixedExtentScrollController(initialItem: day - 1);
    final monthController = FixedExtentScrollController(initialItem: month - 1);
    final yearStart = now.year - 100;
    final yearEnd = now.year;
    final yearController = FixedExtentScrollController(
      initialItem: (year.clamp(yearStart, yearEnd)) - yearStart,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final maxDay = daysInMonth(year, month);
                if (day > maxDay) {
                  day = maxDay;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!dayController.hasClients) return;
                    dayController.jumpToItem(day - 1);
                  });
                }

                Widget header(String text) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  );
                }

                Widget wheel({
                  required FixedExtentScrollController controller,
                  required int count,
                  required ValueChanged<int> onSelected,
                  required String Function(int index) label,
                }) {
                  return CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 36,
                    onSelectedItemChanged: onSelected,
                    children: List.generate(
                      count,
                      (i) => Center(child: Text(label(i))),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 220,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                header(l10n.get('day_picker')),
                                Expanded(
                                  child: wheel(
                                    controller: dayController,
                                    count: maxDay,
                                    onSelected: (i) {
                                      setSheetState(() => day = i + 1);
                                    },
                                    label: (i) => '${i + 1}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                header(l10n.get('month_picker')),
                                Expanded(
                                  child: wheel(
                                    controller: monthController,
                                    count: 12,
                                    onSelected: (i) {
                                      setSheetState(() => month = i + 1);
                                    },
                                    label: (i) => '${i + 1}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                header(l10n.get('year_picker')),
                                Expanded(
                                  child: wheel(
                                    controller: yearController,
                                    count: (yearEnd - yearStart) + 1,
                                    onSelected: (i) {
                                      setSheetState(() => year = yearStart + i);
                                    },
                                    label: (i) => '${yearStart + i}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final selected = DateTime(year, month, day);
                          await controller.setBirthday(selected);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Text(AppLocalizations.of(context).get('save')),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      dayController.dispose();
      monthController.dispose();
      yearController.dispose();
    });
  }

  Future<void> _applyAndClose() async {
    final controller = AppScope.of(context);
    final trimmed = _nameController.text.trim();
    if (trimmed.isNotEmpty && trimmed != _initialName) {
      await controller.setDisplayName(trimmed);
      _initialName = trimmed;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = AppScope.of(context);
    final birthday = controller.birthday;
    final isDark = controller.themeMode == ThemeMode.dark;
    final notificationsEnabled = controller.notificationsEnabled;
    final telegramStyle = controller.telegramStyleEnabled;
    final cs = Theme.of(context).colorScheme;

    if (widget.embedded) {
      if (telegramStyle) {
        return TelegramStyledSettingsBody(
          controller: controller,
          birthday: birthday,
          isDark: isDark,
          notificationsEnabled: notificationsEnabled,
          onPickBirthday: () => _pickBirthday(context),
          onOpenProfile: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
            );
          },
          onOpenBottomNav: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NavigationPanelPage(),
              ),
            );
          },
          onOpenWallpapers: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WallpapersPage()),
            );
          },
          onOpenAccessibility: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AccessibilitySettingsPage(),
              ),
            );
          },
          onOpenDataAndMemory: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DataAndMemoryPage(),
              ),
            );
          },
          onOpenPrivacy: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
            );
          },
          onOpenLanguage: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LanguagePage()),
            );
          },
          onHelp: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const HelpPage()));
          },
          onFaq: () =>
              _openSimpleInfo(context, l10n.get('questions_about_mycircle')),
          onFeatures: () => _openMyCircleFeatures(context),
          onAbout: () => _openSimpleInfo(context, l10n.get('about')),
          onStore: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const StorePage()));
          },
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocalizations.of(context).get('settings_page'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).get('your_name'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).get('name'),
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).get('birthday'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _pickBirthday(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).get('your_birth_date'),
                    ),
                  ),
                  Text(
                    birthday == null
                        ? AppLocalizations.of(context).get('specify')
                        : _formatDate(birthday),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).get('appearance'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                key: ValueKey<bool>(isDark),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              isDark
                  ? l10n.get('switch_to_light_theme')
                  : l10n.get('switch_to_dark_theme'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () {
              final dark = controller.themeMode == ThemeMode.dark;
              LogService.instance.settings(
                'Смена темы: ${dark ? "светлая" : "тёмная"}',
              );
              controller.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.view_carousel_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              l10n.get('change_navigation_panel'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NavigationPanelPage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            l10n.get('chat_settings'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          _SeedColorPicker(
            selected: controller.seedColor,
            onSelect: (c) {
              controller.setSeedColor(c);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.wallpaper_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              l10n.get('change_wallpaper'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const WallpapersPage()),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.science_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              AppLocalizations.of(context).get('accessibility'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccessibilitySettingsPage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).get('notifications'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              notificationsEnabled
                  ? AppLocalizations.of(context).get('disable_notifications')
                  : AppLocalizations.of(context).get('enable_notifications'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () async {
              final next = !notificationsEnabled;
              if (next) {
                final granted = await NotificationsService.instance
                    .requestPermissions();
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(
                          context,
                        ).get('notification_permission'),
                      ),
                    ),
                  );
                  return;
                }
              }

              await controller.setNotificationsEnabled(next);
              await NotificationsService.instance.setEnabled(next);
              LogService.instance.settings(
                'Уведомления: ${next ? "включены" : "выключены"}',
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(
            l10n.get('memory_and_security'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline, color: cs.primary),
            title: Text(
              l10n.get('privacy'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.storage_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              AppLocalizations.of(context).get('data_and_memory'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DataAndMemoryPage(),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.language_outlined, color: cs.primary),
            title: Text(
              AppLocalizations.of(context).get('language_short'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LanguagePage()),
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).get('other_settings'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.help_outline, color: cs.primary),
            title: Text(
              AppLocalizations.of(context).get('help'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const HelpPage()));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.quiz_outlined, color: cs.primary),
            title: Text(
              AppLocalizations.of(context).get('questions_about_mycircle'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            onTap: () => _openSimpleInfo(
              context,
              AppLocalizations.of(context).get('questions_about_mycircle'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lightbulb_outline, color: cs.primary),
            title: Text(
              AppLocalizations.of(context).get('mycircle_channel'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            onTap: () => _openMyCircleFeatures(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.storefront_outlined, color: cs.primary),
            title: Text(
              AppLocalizations.of(context).get('shop'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const StorePage()),
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/MyCircle.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              AppLocalizations.of(context).get('about'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSimpleInfo(
              context,
              AppLocalizations.of(context).get('about'),
            ),
          ),
          SafeArea(top: false, child: SizedBox(height: 12)),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _applyAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Theme.of(context).colorScheme.surface,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _applyAndClose,
          ),
          title: Text(AppLocalizations.of(context).get('settings_page')),
          actions: const [],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              AppLocalizations.of(context).get('your_name'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).get('name'),
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context).get('birthday'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickBirthday(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).get('your_birth_date'),
                      ),
                    ),
                    Text(
                      birthday == null
                          ? AppLocalizations.of(context).get('specify')
                          : _formatDate(birthday),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context).get('appearance'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: Icon(
                  isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  key: ValueKey<bool>(isDark),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                isDark
                    ? 'Переключить на дневную тему'
                    : 'Переключить на ночную тему',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () {
                final dark = controller.themeMode == ThemeMode.dark;
                controller.setThemeMode(
                  dark ? ThemeMode.light : ThemeMode.dark,
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.view_carousel_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                AppLocalizations.of(context).get('change_navigation_panel'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NavigationPanelPage(),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              AppLocalizations.of(context).get('chat_settings'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            _SeedColorPicker(
              selected: controller.seedColor,
              onSelect: (c) {
                controller.setSeedColor(c);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.wallpaper_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                AppLocalizations.of(context).get('change_wallpaper'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WallpapersPage(),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.science_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                AppLocalizations.of(context).get('accessibility'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccessibilitySettingsPage(),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context).get('notifications'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.notifications_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                notificationsEnabled
                    ? AppLocalizations.of(context).get('disable_notifications')
                    : AppLocalizations.of(context).get('enable_notifications'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () async {
                final next = !notificationsEnabled;
                if (next) {
                  final granted = await NotificationsService.instance
                      .requestPermissions();
                  if (!granted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          ).get('notification_permission'),
                        ),
                      ),
                    );
                    return;
                  }
                }

                await controller.setNotificationsEnabled(next);
                await NotificationsService.instance.setEnabled(next);
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context).get('memory_and_security'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 34,
                height: 34,
                child: Image.asset(
                  'assets/icons/TapFlow.png',
                  fit: BoxFit.contain,
                ),
              ),
              title: Text(
                'TapFlow',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TapFlowPage()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                l10n.get('privacy'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.storage_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                l10n.get('data_and_memory'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DataAndMemoryPage(),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.language_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                l10n.get('language_short'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LanguagePage()),
                );
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Text(
              l10n.get('other_settings'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.help_outline, color: cs.primary),
              title: Text(
                l10n.get('help'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: cs.primary),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HelpPage()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.quiz_outlined, color: cs.primary),
              title: Text(
                l10n.get('questions_about_mycircle'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: cs.primary),
              ),
              onTap: () => _openSimpleInfo(
                context,
                l10n.get('questions_about_mycircle'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lightbulb_outline, color: cs.primary),
              title: Text(
                l10n.get('mycircle_channel'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: cs.primary),
              ),
              onTap: () => _openMyCircleFeatures(context),
            ),
            const Divider(height: 1),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icons/MyCircle.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                l10n.get('about'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: cs.primary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSimpleInfo(context, l10n.get('about')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleInfoPage extends StatelessWidget {
  const _SimpleInfoPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const SizedBox(),
    );
  }
}

class MyCircleFaqPage extends StatefulWidget {
  const MyCircleFaqPage({super.key});

  @override
  State<MyCircleFaqPage> createState() => _MyCircleFaqPageState();
}

class _MyCircleFaqPageState extends State<MyCircleFaqPage> {
  int? _openIndex;
  bool _searching = false;
  String _query = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const _items = <({String q, String a})>[
    (
      q: 'Как мессенджер ведет себя при потере сети? (Будут ли сообщения отправлены автоматически после восстановления соединения?)',
      a: '— Все сообщения в чатах скачиваются на устройство, что позволяет читать их без интернета. Сообщения не будут отправлены автоматически при восстановлении соединения (такой функции ещё нету).',
    ),
    (
      q: 'С какой скоростью приходят Push-уведомления? (Есть ли задержки при закрытом приложении?)',
      a: '— На данный момент уведомления не работают и, возможно, не будут работать, так как вы сами создаёте свои сервера.',
    ),
    (
      q: 'Насколько надежно работает авторизация?',
      a: '— Вы заноситесь в таблицу (ваше имя и индивидуальный токен (при скачивании после удаления приложения он меняется)) владельца сервера, к которому вы подключились.',
    ),
    (
      q: 'Как обрабатываются «тяжелые» данные? (Например, если отправить видео на 100 МБ или сразу 20 фотографий?)',
      a: '— В целом, нормально. Все данные обрабатываются хорошо, но всё зависит от вашего интернета.',
    ),
    (
      q: 'Работает ли статус доставки и прочтения? (Видит ли отправитель, что сообщение дошло до сервера и было открыто получателем?)',
      a: '— Нет, не видит. Сделано это для дополнительной анонимности. Возможно, что добавлю в будущем.',
    ),
    (
      q: 'Можно ли редактировать или удалять сообщения «для всех»? (И как быстро обновляется UI у второго собеседника?)',
      a: '— Да, можно. Обновляется / удаляется моментально всё.',
    ),
    (
      q: 'Как работает поиск по истории? (Насколько быстро индексируются новые сообщения?)',
      a: '— Поиск по истории не присутствует на данный момент, в будущем появится. Индексация сообщений зависит от интернета, но, в целом, быстрая.',
    ),
    (
      q: 'Насколько плавные анимации при скролле и открытии клавиатуры? (Нет ли «дерганий» списка сообщений?)',
      a: '— Нету. Если вы заметите что-то странное, то можете сообщить об этом. В следующем обновлении постараюсь исправить.',
    ),
    (
      q: 'Удобно ли управлять чатом одной рукой? (Например, свайп для ответа или расположение кнопки отправки.)',
      a: '— Приложение предназначено для управления одной рукой (кроме печатания).',
    ),
    (
      q: 'Как выглядит интерфейс в темной и светлой темах? (Не сливается ли текст с бабблами сообщений?)',
      a: '— Нет, всё выглядит хорошо. Если будут проблемы, то можете написать, постараюсь исправить.',
    ),
    (
      q: 'Понятна ли навигация? (Сможет ли новый пользователь за 5 секунд найти настройки профиля или поиск контактов?)',
      a: '— Да, любой пользователь сможет понять интерфейс и настроить его.',
    ),
    (
      q: 'Насколько защищены личные данные в базе? (Зашифрованы ли сообщения?)',
      a: '— 100% защиты никогда не бывает. Текстовые сообщения все шифруются так, что даже владелец сервера не сможет их прочитать. Медиафайлы отправляются владельцу сервера, он сможет их посмотреть.',
    ),
    (
      q: 'Можно ли заблокировать пользователя? (Перестанут ли приходить уведомления от него мгновенно?)',
      a: '— Пользователя нельзя заблокировать, только владелец сервера может удалить данные пользователя.',
    ),
    (
      q: 'Как работает синхронизация между устройствами? (Увидит ли пользователь историю чатов, если зайдет с другого смартфона?)',
      a: '— Через индивидуальный токен пользователя. Человек не регистрируется, а ему присваивается два индивидуальных токена: публичный (который идёт на сервер) и приватный. Пользователь никак не сможет зайти в свой «аккаунт» с нового устройства. Историю чатов сможет увидеть любой.',
    ),
    (
      q: 'Где именно хранятся мои сообщения и файлы? (На моем устройстве, на сервере создателя или в облаке?)',
      a: '— Сообщения хранятся на сервере, а медиа файлы хранятся в облаке у создателя',
    ),
    (
      q: 'Что произойдет, если владелец сервера его удалит или выключит? (Пропадет ли доступ к чатам навсегда?)',
      a: '— Вы не сможете больше писать в чат и, возможно, у некоторых людей пропадёт переписка оставшиеся (скаченная). Создатель же тоже не сможет получить доступ. Чат же сам останется у вас в приложении, вы сможете его удалить, если он вам будет мешаться.',
    ),
    (
      q: 'Есть ли лимит на количество людей на одном сервере? (Насколько масштабируема система?)',
      a: '— Нету, может хоть бесконечное число людей присутствовать, но лучше будет, если человек будет до 100 (мессенджер не создавался на большое число людей).',
    ),
    (
      q: 'Что делать, если я потерял свой приватный токен? (Можно ли его восстановить или доступ к аккаунту будет потерян навсегда?)',
      a: '— Вы его никак не узнаете. Потерять вы его можете только в том случае, если удалите приложение. Это никак не критично, но для сервера создателя вы будете новым человеком.',
    ),
    (
      q: 'Видят ли другие пользователи мой публичный токен?',
      a: '— Нет, только сервер и сам создатель сервера в таблице на сайте',
    ),
    (
      q: 'Можно ли скрыть время своего последнего захода в сеть? (Насколько глубоко реализована анонимность?)',
      a: '— Времени захода в чат нету и его никто не сможет отследить',
    ),
    (
      q: 'Шифруются ли данные при передаче от пользователя на сервер? (Защищена ли переписка от перехвата провайдером?)',
      a: '— Да, шифруется сквозным шифрованием. Провайдер видит лишь зашифрованный набор символов, но не содержание сообщения',
    ),
    (
      q: 'Поддерживает ли мессенджер групповые чаты или только личные диалоги?',
      a: '— Только групповые чаты, личных чатов нету. Можно создать групповой чат и добавить туда себя и ещё кого-то, в таком случае будет личный чат. Личные чаты отсутствуют, так как владелец сервера сможет увидеть, что кто-то общается с кем-то (но не сами сообщения)',
    ),
    (
      q: 'Можно ли записывать голосовые сообщения? (И шифруются ли они так же, как текстовые?)',
      a: '— Технология присутствует, но отсутствует в релизном варианте. В будущем планирую добавить окончательно.',
    ),
    (
      q: 'Есть ли в приложении стикеры или GIF-анимации?',
      a: '— В приложении есть стикеры "Котята", в будущем планирую их удалить и добавить возможность добавлять свои стикеры / скачивать из "магазина" бесплатно.',
    ),
    (q: 'Будет ли версия для ПК (Web или Desktop)?', a: '— Не планирую'),
    (
      q: 'Как часто выходят обновления и как их устанавливать?',
      a: '— Зависит от моего времени',
    ),
    (
      q: 'Сильно ли приложение расходует заряд батареи в фоновом режиме?',
      a: '— Нет, не очень. Но если у вас слабый телефон, то будет сильнее расходовать',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items
              .where(
                (e) =>
                    e.q.toLowerCase().contains(q) ||
                    e.a.toLowerCase().contains(q),
              )
              .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Поиск по вопросам',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) {
                  setState(() {
                    _query = v;
                    _openIndex = null;
                  });
                },
              )
            : Text(l10n.get('questions_about_mycircle')),
        actions: [
          IconButton(
            tooltip: _searching ? 'Закрыть поиск' : 'Поиск',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                _openIndex = null;
                if (!_searching) {
                  _query = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = filtered[i];
          final open = _openIndex == i;
          return Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() => _openIndex = open ? null : i);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.q,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: open ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: Icon(
                            Icons.expand_more,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    if (open) ...[
                      const SizedBox(height: 10),
                      Text(
                        item.a,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.85),
                          height: 1.28,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(AppLocalizations.of(context).get('privacy')),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 14),
        children: [
          TelegramSettingsSection(
            children: [
              TelegramSettingsTile(
                title: AppLocalizations.of(context).get('passcode'),
                leading: TelegramSettingsIcon(
                  icon: Icons.password_outlined,
                  color: Color(0xFFAF52DE),
                ),
                onTap: () async {
                  if (controller.hasPasscode) {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const PasscodeUnlockPage(),
                      ),
                    );
                    if (ok != true) return;
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PasscodeSettingsPage(),
                    ),
                  );
                },
              ),
              TelegramSettingsTile(
                title: AppLocalizations.of(context).get('auto_cleanup'),
                leading: const TelegramSettingsIcon(
                  icon: Icons.auto_delete_outlined,
                  color: Color(0xFFFF9500),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AutoCleanupPage(),
                    ),
                  );
                },
              ),
              TelegramSettingsTile(
                title: 'Устройства',
                leading: const TelegramSettingsIcon(
                  icon: Icons.devices_outlined,
                  color: Color(0xFF007AFF),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DevicesPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PasscodeSettingsPage extends StatelessWidget {
  const PasscodeSettingsPage({super.key});

  String _autoLockText(int seconds, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (seconds <= 0) return l10n.get('off');
    if (seconds < 60) return 'Через ${seconds}s';
    if (seconds == 60) return l10n.get('auto_lock_after_1_min');
    if (seconds == 5 * 60) return l10n.get('auto_lock_after_5_min');
    if (seconds == 60 * 60) return l10n.get('auto_lock_after_1_hour');
    if (seconds == 5 * 60 * 60) return 'Через 5 часов';
    return 'Через ${seconds ~/ 60} минут';
  }

  Future<void> _showDisableSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final controller = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await controller.clearPasscode();
                        await controller.setPasscodeAutoLockSeconds(0);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: SizedBox(
                        height: 54,
                        child: Center(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).get('disable_passcode'),
                            style: TextStyle(
                              color: Color(0xFFFF3B30),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        height: 54,
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context).get('cancel'),
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAutoLockSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    Future<void> pick(int seconds) async {
      await controller.setPasscodeAutoLockSeconds(seconds);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        Widget item(String key, int seconds) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => pick(seconds),
              child: SizedBox(
                height: 54,
                child: Center(
                  child: Text(
                    l10n.get(key),
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      item('off', 0),
                      Divider(height: 1, color: cs.outlineVariant),
                      item('auto_lock_after_1_min', 60),
                      Divider(height: 1, color: cs.outlineVariant),
                      item('auto_lock_after_5_min', 5 * 60),
                      Divider(height: 1, color: cs.outlineVariant),
                      item('auto_lock_after_1_hour', 60 * 60),
                      Divider(height: 1, color: cs.outlineVariant),
                      item('auto_lock_after_5_hours', 5 * 60 * 60),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        height: 54,
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context).get('cancel'),
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final autoLock = controller.passcodeAutoLockSeconds;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context).get('passcode'),
          style: TextStyle(color: cs.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.hasPasscode) ...[
                  _PasscodeRow(
                    text: AppLocalizations.of(context).get('disable_passcode'),
                    onTap: () => _showDisableSheet(context),
                  ),
                  Divider(height: 1, color: cs.outlineVariant),
                ],
                _PasscodeRow(
                  text: AppLocalizations.of(context).get('change_passcode'),
                  onTap: () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const PasscodeSetPage(),
                      ),
                    );
                    if (ok == true && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).get('passcode_warning'),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.55),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showAutoLockSheet(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).get('auto_lock'),
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Text(
                        _autoLockText(autoLock, context),
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasscodeRow extends StatelessWidget {
  const _PasscodeRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: TextStyle(color: cs.primary, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

class PasscodeUnlockPage extends StatefulWidget {
  const PasscodeUnlockPage({super.key});

  @override
  State<PasscodeUnlockPage> createState() => _PasscodeUnlockPageState();
}

class _PasscodeUnlockPageState extends State<PasscodeUnlockPage> {
  final List<int> _digits = <int>[];
  bool _error = false;
  bool _busy = false;

  void _addDigit(int d) {
    if (_busy) return;
    if (_digits.length >= 6) return;
    setState(() {
      _digits.add(d);
      _error = false;
    });
    if (_digits.length == 6) {
      _submit();
    }
  }

  void _delete() {
    if (_busy) return;
    if (_digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _error = false;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final controller = AppScope.of(context);
    setState(() => _busy = true);
    final code = _digits.join();
    final ok = await controller.verifyPasscode(code);
    if (!mounted) return;
    if (ok) {
      await controller.setPasscodeLocked(false);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = true;
      _digits.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(''),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 36),
            Icon(Icons.lock_outline, size: 34, color: cs.onSurface),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).get('enter_passcode'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            _DotsRow(count: _digits.length, error: _error),
            const Spacer(),
            _Keypad(onDigit: _addDigit, onDelete: _delete),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class PasscodeSetPage extends StatefulWidget {
  const PasscodeSetPage({super.key});

  @override
  State<PasscodeSetPage> createState() => _PasscodeSetPageState();
}

class _PasscodeSetPageState extends State<PasscodeSetPage> {
  final List<int> _digits = <int>[];
  bool _busy = false;

  void _addDigit(int d) {
    if (_busy) return;
    if (_digits.length >= 6) return;
    setState(() => _digits.add(d));
    if (_digits.length == 6) {
      _save();
    }
  }

  void _delete() {
    if (_busy) return;
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = AppScope.of(context);
    final code = _digits.join();
    await controller.setPasscode(code);
    await controller.setPasscodeLocked(false);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context).get('passcode'),
          style: TextStyle(color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 90),
            Text(
              AppLocalizations.of(context).get('enter_new_passcode'),
              style: TextStyle(color: cs.onSurface, fontSize: 18),
            ),
            const SizedBox(height: 18),
            _DotsRow(count: _digits.length, error: false),
            const Spacer(),
            _Keypad(onDigit: _addDigit, onDelete: _delete),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _DotsRow extends StatelessWidget {
  const _DotsRow({required this.count, required this.error});

  final int count;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    final off = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25);
    final c = error ? const Color(0xFFFF3B30) : on;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? c : Colors.transparent,
              border: Border.all(color: filled ? c : off, width: 1.5),
            ),
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onDelete});

  final void Function(int digit) onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fg = Theme.of(context).colorScheme.onSurface;
    Widget key(String text, {VoidCallback? onTap}) {
      return SizedBox(
        width: 86,
        height: 68,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: fg,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget delKey() {
      return SizedBox(
        width: 86,
        height: 68,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onDelete,
            child: Center(
              child: Text(
                l10n.get('delete_btn'),
                style: TextStyle(
                  color: fg.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            key('1', onTap: () => onDigit(1)),
            key('2', onTap: () => onDigit(2)),
            key('3', onTap: () => onDigit(3)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            key('4', onTap: () => onDigit(4)),
            key('5', onTap: () => onDigit(5)),
            key('6', onTap: () => onDigit(6)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            key('7', onTap: () => onDigit(7)),
            key('8', onTap: () => onDigit(8)),
            key('9', onTap: () => onDigit(9)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 86, height: 68),
            key('0', onTap: () => onDigit(0)),
            delKey(),
          ],
        ),
      ],
    );
  }
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = AppScope.of(context);
    final current = controller.appLanguage;
    Future<void> select(String code) async {
      await controller.setAppLanguage(code);
    }

    final languages = AppLanguages.all;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(AppLocalizations.of(context).get('language')),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 14),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                AppLocalizations.of(context).get('language_interface'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          TelegramSettingsSection(
            children: [
              for (final l in languages)
                _LanguageTile(
                  title: l.title,
                  subtitle: l.subtitle,
                  selected: current == l.code,
                  onTap: () => select(l.code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check, color: cs.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EnergySavingPage extends StatelessWidget {
  const EnergySavingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('energy_saving'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Настройки энергосбережения будут добавлены позже.'),
        ],
      ),
    );
  }
}

class AccessibilitySettingsPage extends StatefulWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  State<AccessibilitySettingsPage> createState() =>
      _AccessibilitySettingsPageState();
}

class _AccessibilitySettingsPageState extends State<AccessibilitySettingsPage> {
  bool _initialized = false;
  bool _advancedComposer = false;
  bool _iosInputPanel = false;
  bool _telegramStyle = false;

  Future<void> _resetData() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.get('warning')),
          content: const Text(
            'Ваши данные: имя, дата рождения, данные из чатов, Sup. API и Sup. pub_key будут удалены. Вам придётся занова входить в сервер какого-нибудь пользователя и проходить регистрацию.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.get('confirm_btn')),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    if (!mounted) return;

    final controller = AppScope.of(context);
    await controller.resetAllData();
    if (!mounted) return;

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const RegistrationPage(requireSupabaseConfig: true),
      ),
      (_) => false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final controller = AppScope.of(context);
    _advancedComposer = controller.advancedComposerEnabled;
    _iosInputPanel = controller.iosInputPanelEnabled;
    _telegramStyle = controller.telegramStyleEnabled;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.get('accessibility')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever_outlined, color: cs.error),
            title: Text(
              'Сбросить данные',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.error),
            ),
            onTap: _resetData,
          ),
          const Divider(height: 24),
          Text('Поле ввода', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Расширенное поле ввода'),
            trailing: Switch(
              value: _advancedComposer,
              activeThumbColor: cs.primary,
              onChanged: (v) async {
                setState(() {
                  _advancedComposer = v;
                  if (v) {
                    _iosInputPanel = false;
                  }
                });
                final controller = AppScope.of(context);
                await controller.setAdvancedComposerEnabled(v);
                if (v) {
                  await controller.setIosInputPanelEnabled(false);
                }
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Панель ввода с IOS'),
            trailing: Switch(
              value: _iosInputPanel,
              activeThumbColor: cs.primary,
              onChanged: (v) async {
                setState(() {
                  _iosInputPanel = v;
                  if (v) {
                    _advancedComposer = false;
                  }
                });
                final controller = AppScope.of(context);
                await controller.setIosInputPanelEnabled(v);
                if (v) {
                  await controller.setAdvancedComposerEnabled(false);
                }
              },
            ),
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Стиль Modern Adaptive UI'),
            trailing: Switch(
              value: _telegramStyle,
              activeThumbColor: cs.primary,
              onChanged: (v) async {
                setState(() {
                  _telegramStyle = v;
                });
                final controller = AppScope.of(context);
                await controller.setTelegramStyleEnabled(v);
              },
            ),
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.developer_mode_outlined, color: cs.primary),
            title: Text(
              'Для разработчиков',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            subtitle: Text(
              'Тестовые функции и инструменты',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DevToolsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DevToolsPage extends StatefulWidget {
  const DevToolsPage({super.key});

  @override
  State<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage> {
  AudioPlayer? _audio;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  static const List<double> _waveform = [
    0.15,
    0.18,
    0.22,
    0.20,
    0.16,
    0.12,
    0.10,
    0.14,
    0.26,
    0.38,
    0.32,
    0.24,
    0.18,
    0.14,
    0.12,
    0.16,
    0.22,
    0.30,
    0.42,
    0.60,
    0.78,
    0.66,
    0.52,
    0.36,
    0.22,
    0.18,
    0.14,
    0.20,
    0.34,
    0.46,
    0.58,
    0.40,
    0.28,
    0.22,
    0.18,
    0.14,
    0.12,
    0.10,
    0.14,
    0.18,
    0.26,
    0.34,
    0.28,
    0.22,
    0.18,
    0.16,
    0.14,
    0.12,
  ];

  @override
  void dispose() {
    _audio?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    var p = _audio;
    if (p == null) {
      p = AudioPlayer();
      _audio = p;
      await p.setAsset('assets/docum/test_audio.mp3');
      _duration = p.duration ?? Duration.zero;

      p.positionStream.listen((d) {
        if (!mounted) return;
        setState(() => _position = d);
      });
      p.playerStateStream.listen((s) {
        if (!mounted) return;
        setState(() => _playing = s.playing);
      });
      p.durationStream.listen((d) {
        if (!mounted) return;
        setState(() => _duration = d ?? Duration.zero);
      });
    }

    if (_playing) {
      await p.pause();
    } else {
      await p.play();
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = (s ~/ 60).toString();
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (_duration.inMilliseconds <= 0)
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Для разработчиков'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.notification_important_outlined,
              color: cs.primary,
            ),
            title: Text(
              'Показать оповещение (тест)',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            onTap: () => showDevNoticeDialog(context),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.bug_report_outlined, color: cs.primary),
            title: Text(
              'Логи',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cs.primary),
            ),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AppLogsPage()));
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _toggleAudio,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) async {
                              final p = _audio;
                              if (p == null) return;
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final local = box.globalToLocal(d.globalPosition);
                              final w = box.size.width;
                              if (w <= 0) return;
                              final v = (local.dx / w).clamp(0.0, 1.0);
                              await p.seek(_duration * v);
                            },
                            onHorizontalDragUpdate: (d) async {
                              final p = _audio;
                              if (p == null) return;
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final local = box.globalToLocal(d.globalPosition);
                              final w = box.size.width;
                              if (w <= 0) return;
                              final v = (local.dx / w).clamp(0.0, 1.0);
                              await p.seek(_duration * v);
                            },
                            child: SizedBox(
                              height: 28,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _WaveformPainter(
                                  amplitudes: _waveform,
                                  progress: progress,
                                  activeColor: cs.primary,
                                  inactiveColor: cs.onSurface.withValues(
                                    alpha: 0.20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              children: [
                                Text(
                                  _fmt(_position),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Spacer(),
                                Text(
                                  _fmt(_duration),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Тестирование будущих голосовых сообщений',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> amplitudes;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = amplitudes.isEmpty ? 1 : amplitudes.length;
    final gap = 2.2;
    final barW = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      1.0,
      6.0,
    );
    final totalW = barW * barCount + gap * (barCount - 1);
    final startX = (size.width - totalW) / 2.0;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;

    final centerY = size.height / 2;
    final activeBars = (progress * barCount).floor().clamp(0, barCount);

    for (var i = 0; i < barCount; i++) {
      final a = amplitudes[i % amplitudes.length].clamp(0.06, 1.0);
      final h = (a * (size.height * 0.95)).clamp(3.0, size.height);
      final x = startX + i * (barW + gap) + barW / 2;
      final p = i < activeBars ? activePaint : inactivePaint;
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.amplitudes != amplitudes;
  }
}

class DataAndMemoryPage extends StatefulWidget {
  const DataAndMemoryPage({super.key});

  @override
  State<DataAndMemoryPage> createState() => _DataAndMemoryPageState();
}

class _DataAndMemoryPageState extends State<DataAndMemoryPage> {
  bool _loading = true;
  int _memory = 0;
  int _traffic = 0;
  bool _autoMobile = false;
  bool _autoWifi = false;
  bool _autoRoaming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final memory = await CacheService.instance.getCacheSizeBytes();
    final traffic = await CacheService.instance.getNetworkUsageBytes();
    final autoMobile = await CacheService.instance.getAutoDownloadMobile();
    final autoWifi = await CacheService.instance.getAutoDownloadWifi();
    final autoRoaming = await CacheService.instance.getAutoDownloadRoaming();
    if (!mounted) return;
    setState(() {
      _memory = memory;
      _traffic = traffic;
      _autoMobile = autoMobile;
      _autoWifi = autoWifi;
      _autoRoaming = autoRoaming;
      _loading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 Б';
    const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
    double v = bytes.toDouble();
    int u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    final s = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$s ${units[u]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('data_and_memory'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Text(
              'Использование сети и кэша',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.memory_outlined),
              title: const Text('Использование памяти'),
              trailing: Text(_formatBytes(_memory)),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MemoryUsagePage(),
                  ),
                );
                await _load();
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.network_check_outlined),
              title: const Text('Использование трафика'),
              trailing: Text(_formatBytes(_traffic)),
            ),
            const SizedBox(height: 18),
            Text(
              'Автозагрузка медиа',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Через мобильную сеть'),
              subtitle: Text(
                _autoMobile ? 'Загружается этим способом' : 'Не загружать',
              ),
              value: _autoMobile,
              onChanged: (v) async {
                setState(() => _autoMobile = v);
                await CacheService.instance.setAutoDownloadMobile(v);
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Через сеть Wi‑Fi'),
              subtitle: Text(
                _autoWifi ? 'Загружается этим способом' : 'Не загружать',
              ),
              value: _autoWifi,
              onChanged: (v) async {
                setState(() => _autoWifi = v);
                await CacheService.instance.setAutoDownloadWifi(v);
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('В роуминге'),
              subtitle: Text(
                _autoRoaming ? 'Загружается этим способом' : 'Не загружать',
              ),
              value: _autoRoaming,
              onChanged: (v) async {
                setState(() => _autoRoaming = v);
                await CacheService.instance.setAutoDownloadRoaming(v);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class WallpapersPage extends StatelessWidget {
  const WallpapersPage({super.key});

  static const int _count = 10;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final selected = controller.chatWallpaper;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noneBorder = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Обои для чатов'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: _count + 1,
        itemBuilder: (context, index) {
          final isNone = index == 0;
          final asset = isNone ? null : 'assets/wallpapers/${index}_w.jpg';
          final isPicked = isNone ? selected == null : selected == asset;

          return InkWell(
            onTap: () => controller.setChatWallpaper(asset),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isNone)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: noneBorder, width: 2),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(asset!, fit: BoxFit.cover),
                  ),
                if (isPicked)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SeedColorPicker extends StatelessWidget {
  const _SeedColorPicker({required this.selected, required this.onSelect});

  final Color selected;
  final ValueChanged<Color> onSelect;

  static final List<Color> _colors = <Color>[
    Colors.blue,
    Colors.green,
    Colors.lightBlue,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.orange,
    Colors.yellow,
    Colors.grey,
  ];

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.2);

    bool isSame(Color a, Color b) => a.toARGB32() == b.toARGB32();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colors.map((c) {
        final picked = isSame(c, selected);
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onSelect(c),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(
                color: picked ? Colors.white : border,
                width: picked ? 4 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
