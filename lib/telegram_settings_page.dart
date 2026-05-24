import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cupertino_liquid_glass/cupertino_liquid_glass.dart';

import 'app_scope.dart';
import 'app_language.dart';
import 'notifications_service.dart';
import 'tapflow_page.dart';
import 'telegram_settings_style.dart';

class TelegramStyledSettingsBody extends StatefulWidget {
  const TelegramStyledSettingsBody({
    super.key,
    required this.controller,
    required this.birthday,
    required this.isDark,
    required this.notificationsEnabled,
    required this.onPickBirthday,
    required this.onOpenProfile,
    required this.onOpenBottomNav,
    required this.onOpenWallpapers,
    required this.onOpenAccessibility,
    required this.onOpenDataAndMemory,
    required this.onOpenPrivacy,
    required this.onOpenLanguage,
    required this.onHelp,
    required this.onFaq,
    required this.onFeatures,
    required this.onAbout,
    required this.onStore,
  });

  final AppController controller;
  final DateTime? birthday;
  final bool isDark;
  final bool notificationsEnabled;
  final VoidCallback onPickBirthday;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenBottomNav;
  final VoidCallback onOpenWallpapers;
  final VoidCallback onOpenAccessibility;
  final VoidCallback onOpenDataAndMemory;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenLanguage;
  final VoidCallback onHelp;
  final VoidCallback onFaq;
  final VoidCallback onFeatures;
  final VoidCallback onAbout;
  final VoidCallback onStore;

  @override
  State<TelegramStyledSettingsBody> createState() =>
      _TelegramStyledSettingsBodyState();
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _GlassCapsuleButton extends StatelessWidget {
  const _GlassCapsuleButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.hardEdge,
      child: CupertinoLiquidGlass(
        theme: isDark
            ? LiquidGlassThemeData.dark()
            : LiquidGlassThemeData.light(),
        blurSigma: 44,
        tintOpacity: isDark ? 0.20 : 0.14,
        borderRadius: BorderRadius.circular(999),
        edgeLightColor: isDark
            ? const Color(0x70FFFFFF)
            : const Color(0x55FFFFFF),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: DefaultTextStyle.merge(
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TelegramStyledSettingsBodyState extends State<TelegramStyledSettingsBody>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late DateTime? _draftBirthday;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: (widget.controller.displayName ?? '').trim(),
    );
    _draftBirthday = widget.birthday;
  }

  @override
  void didUpdateWidget(covariant TelegramStyledSettingsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.controller.displayName != widget.controller.displayName) {
      final next = (widget.controller.displayName ?? '').trim();
      if (_nameController.text.trim() != next && !_editMode) {
        _nameController.text = next;
      }
    }
    if (oldWidget.birthday != widget.birthday && !_editMode) {
      _draftBirthday = widget.birthday;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatBirthday(BuildContext context, DateTime? date) {
    if (date == null) return AppLocalizations.of(context).get('specify');
    return DateFormat('d MMM y', 'ru').format(date);
  }

  Future<void> _pickDraftBirthday(BuildContext context) async {
    final now = DateTime.now();
    final initial =
        _draftBirthday ?? DateTime(now.year - 18, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
      helpText: AppLocalizations.of(context).get('birthday'),
      cancelText: AppLocalizations.of(context).get('cancel'),
      confirmText: AppLocalizations.of(context).get('done'),
    );
    if (!mounted) return;
    if (selected == null) return;
    setState(() => _draftBirthday = selected);
  }

  void _enterEdit() {
    setState(() {
      _editMode = true;
      _draftBirthday = widget.birthday;
      _nameController.text = (widget.controller.displayName ?? '').trim();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editMode = false;
      _draftBirthday = widget.birthday;
      _nameController.text = (widget.controller.displayName ?? '').trim();
    });
  }

  Future<void> _saveEdit() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isNotEmpty &&
        trimmed != (widget.controller.displayName ?? '')) {
      await widget.controller.setDisplayName(trimmed);
    }
    if (_draftBirthday != widget.controller.birthday) {
      await widget.controller.setBirthday(_draftBirthday);
    }
    if (!mounted) return;
    setState(() => _editMode = false);
  }

  Future<void> _showButtonColors(BuildContext context) async {
    const palette = <Color>[
      Color(0xFF007AFF),
      Color(0xFF34C759),
      Color(0xFF5AC8FA),
      Color(0xFFFF3B30),
      Color(0xFFFF2D55),
      Color(0xFFAF52DE),
      Color(0xFFFF9500),
      Color(0xFFFFCC00),
      Color(0xFF8E8E93),
    ];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selected = widget.controller.seedColor;
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).get('button_colors'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final color in palette)
                          _ColorDot(
                            color: color,
                            selected: color.toARGB32() == selected.toARGB32(),
                            onTap: () async {
                              await widget.controller.setSeedColor(color);
                              if (!context.mounted) return;
                              setModalState(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = (widget.controller.displayName ?? '').trim();
    final title = name.isEmpty
        ? AppLocalizations.of(context).get('profile')
        : name;

    final topBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_editMode) ...[
                      _GlassCapsuleButton(
                        onPressed: () {
                          final url = widget.controller.supabaseUrl;
                          final key = widget.controller.supabaseAnonKey;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TapFlowPage(
                                mode: TapFlowMode.sendSupabase,
                                supabaseUrl: url,
                                supabaseAnonKey: key,
                              ),
                            ),
                          );
                        },
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Transform.scale(
                                scale: 1.3,
                                child: Image.asset(
                                  'assets/icons/TapFlow_nofon.png',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _editMode
                          ? _GlassCapsuleButton(
                              key: const ValueKey('cancel'),
                              onPressed: _cancelEdit,
                              child: Text(
                                AppLocalizations.of(context).get('cancel'),
                              ),
                            )
                          : const SizedBox(key: ValueKey('spacer')),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _editMode
                    ? _GlassCapsuleButton(
                        key: const ValueKey('done'),
                        onPressed: _saveEdit,
                        child: Text(AppLocalizations.of(context).get('done')),
                      )
                    : _GlassCapsuleButton(
                        key: const ValueKey('edit'),
                        onPressed: _enterEdit,
                        child: Text(AppLocalizations.of(context).get('edit')),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
            child: Icon(Icons.person, size: 44, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    final normalBody = Column(
      key: const ValueKey('normal'),
      children: [
        TelegramSettingsSection(
          children: [
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('my_profile'),
              leading: const TelegramSettingsIcon(
                icon: Icons.person_outline,
                color: Color(0xFFFF3B30),
              ),
              onTap: widget.onOpenProfile,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TelegramSettingsSection(
          children: [
            TelegramSettingsTile(
              title: widget.isDark
                  ? AppLocalizations.of(context).get('switch_to_light_theme')
                  : AppLocalizations.of(context).get('switch_to_dark_theme'),
              leading: TelegramSettingsIcon(
                icon: widget.isDark
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round,
                color: const Color(0xFFFF9500),
              ),
              onTap: () {
                final dark = widget.controller.themeMode == ThemeMode.dark;
                widget.controller.setThemeMode(
                  dark ? ThemeMode.light : ThemeMode.dark,
                );
              },
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(
                context,
              ).get('change_navigation_panel'),
              leading: const TelegramSettingsIcon(
                icon: Icons.view_carousel_outlined,
                color: Color(0xFF007AFF),
              ),
              onTap: widget.onOpenBottomNav,
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('change_wallpaper'),
              leading: const TelegramSettingsIcon(
                icon: Icons.wallpaper_outlined,
                color: Color(0xFFAF52DE),
              ),
              onTap: widget.onOpenWallpapers,
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('button_colors'),
              leading: const TelegramSettingsIcon(
                icon: Icons.color_lens_outlined,
                color: Color(0xFF5AC8FA),
              ),
              onTap: () => _showButtonColors(context),
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('accessibility'),
              leading: const TelegramSettingsIcon(
                icon: Icons.science_outlined,
                color: Color(0xFF5856D6),
              ),
              onTap: widget.onOpenAccessibility,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TelegramSettingsSection(
          children: [
            TelegramSettingsTile(
              title: widget.notificationsEnabled
                  ? AppLocalizations.of(context).get('disable_notifications')
                  : AppLocalizations.of(context).get('enable_notifications'),
              leading: const TelegramSettingsIcon(
                icon: Icons.notifications_outlined,
                color: Color(0xFFFF3B30),
              ),
              onTap: () async {
                final next = !widget.notificationsEnabled;
                if (next) {
                  final granted = await NotificationsService.instance
                      .requestPermissions();
                  if (!context.mounted) return;
                  if (!granted) {
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

                await widget.controller.setNotificationsEnabled(next);
                await NotificationsService.instance.setEnabled(next);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        TelegramSettingsSection(
          children: [
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('tapflow'),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Transform.scale(
                  scale: 1.35,
                  child: Image.asset(
                    'assets/icons/TapFlow.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TapFlowPage()),
                );
              },
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('privacy'),
              leading: const TelegramSettingsIcon(
                icon: Icons.lock_outline,
                color: Color(0xFF007AFF),
              ),
              onTap: widget.onOpenPrivacy,
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('data_and_memory'),
              leading: const TelegramSettingsIcon(
                icon: Icons.storage_outlined,
                color: Color(0xFF34C759),
              ),
              onTap: widget.onOpenDataAndMemory,
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('language_short'),
              leading: const TelegramSettingsIcon(
                icon: Icons.language_outlined,
                color: Color(0xFFFF9500),
              ),
              onTap: widget.onOpenLanguage,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TelegramSettingsSection(
          children: [
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('help'),
              leading: const TelegramSettingsIcon(
                icon: Icons.help_outline,
                color: Color(0xFF007AFF),
              ),
              onTap: widget.onHelp,
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(
                context,
              ).get('questions_about_mycircle'),
              leading: const TelegramSettingsIcon(
                icon: Icons.quiz_outlined,
                color: Color(0xFF5AC8FA),
              ),
              onTap: widget.onFaq,
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('mycircle_channel'),
              leading: const TelegramSettingsIcon(
                icon: Icons.lightbulb_outline,
                color: Color(0xFFFFCC00),
              ),
              onTap: widget.onFeatures,
            ),
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('shop'),
              leading: const TelegramSettingsIcon(
                icon: Icons.storefront_outlined,
                color: Color(0xFF34C759),
              ),
              onTap: widget.onStore,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TelegramSettingsSection(
          children: [
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('about'),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/icons/MyCircle.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                ),
              ),
              onTap: widget.onAbout,
            ),
          ],
        ),
        const SafeArea(top: false, child: SizedBox(height: 12)),
      ],
    );

    final editBody = Column(
      key: const ValueKey('edit'),
      children: [
        TelegramSettingsSection(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context).get('name'),
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TelegramSettingsSection(
          children: [
            TelegramSettingsTile(
              title: AppLocalizations.of(context).get('birthday'),
              leading: const TelegramSettingsIcon(
                icon: Icons.cake_outlined,
                color: Color(0xFF34C759),
              ),
              trailing: Text(
                _formatBirthday(context, _draftBirthday),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => _pickDraftBirthday(context),
            ),
          ],
        ),
        const SafeArea(top: false, child: SizedBox(height: 12)),
      ],
    );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        topBar,
        header,
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[...previousChildren, ?currentChild],
              );
            },
            transitionBuilder: (child, animation) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
                reverseCurve: Curves.easeIn,
              );
              return FadeTransition(opacity: fade, child: child);
            },
            child: _editMode ? editBody : normalBody,
          ),
        ),
      ],
    );
  }
}
