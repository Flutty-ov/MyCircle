import 'package:flutter/material.dart';
import 'app_scope.dart';
import 'app_language.dart';
import 'telegram_settings_style.dart';

class AutoCleanupPage extends StatefulWidget {
  const AutoCleanupPage({super.key});

  @override
  State<AutoCleanupPage> createState() => _AutoCleanupPageState();
}

class _AutoCleanupPageState extends State<AutoCleanupPage> {
  Set<String> _selectedTypes = {};
  int _cleanupDays = 0;

  static const Map<String, String> _typeKeys = {
    'video': 'video',
    'photo': 'photo',
    'files': 'files',
    'stickers': 'stickers',
    'other': 'other',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final controller = AppScope.of(context);
    setState(() {
      _selectedTypes = controller.autoCleanupTypes;
      _cleanupDays = controller.autoCleanupDays;
    });
  }

  Future<void> _showCleanupTypesSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final currentTypes = Set<String>.from(_selectedTypes);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                          for (final entry in _typeKeys.entries)
                            Column(
                              children: [
                                _CleanupTypeTile(
                                  title: AppLocalizations.of(
                                    context,
                                  ).get(entry.value),
                                  type: entry.key,
                                  selected: currentTypes.contains(entry.key),
                                  onTap: (type) {
                                    setModalState(() {
                                      if (currentTypes.contains(type)) {
                                        currentTypes.remove(type);
                                      } else {
                                        currentTypes.add(type);
                                      }
                                    });
                                  },
                                ),
                                if (entry.key != 'other')
                                  Divider(height: 1, color: cs.outlineVariant),
                              ],
                            ),
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
                          onTap: () => Navigator.of(context).pop(currentTypes),
                          child: SizedBox(
                            height: 54,
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context).get('done'),
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
      },
    );

    if (result != null && context.mounted) {
      final controller = AppScope.of(context);
      await controller.setAutoCleanupTypes(result);
      if (mounted) {
        setState(() => _selectedTypes = result);
      }
    }
  }

  Future<void> _showCleanupDaysSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    Future<void> pick(int days) async {
      final controller = AppScope.of(context);
      await controller.setAutoCleanupDays(days);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      setState(() => _cleanupDays = days);
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        Widget item(String key, int days) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => pick(days),
              child: SizedBox(
                height: 54,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).get(key),
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
                      item('after_1_day', 1),
                      Divider(height: 1, color: cs.outlineVariant),
                      item('after_5_days', 5),
                      Divider(height: 1, color: cs.outlineVariant),
                      item('after_10_days', 10),
                      Divider(height: 1, color: cs.outlineVariant),
                      item('after_20_days', 20),
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

  String _cleanupDaysText() {
    final l10n = AppLocalizations.of(context);
    switch (_cleanupDays) {
      case 0:
        return l10n.get('off');
      case 1:
        return l10n.get('after_1_day');
      case 5:
        return l10n.get('after_5_days');
      case 10:
        return l10n.get('after_10_days');
      case 20:
        return l10n.get('after_20_days');
      default:
        return l10n.get('off');
    }
  }

  String _selectedTypesText() {
    final l10n = AppLocalizations.of(context);
    if (_selectedTypes.isEmpty) return l10n.get('nothing_selected');
    final count = _selectedTypes.length;
    return '$count ${_getWordForm(count, l10n)}';
  }

  String _getWordForm(int count, AppLocalizations l10n) {
    if (count == 1) return l10n.get('type');
    if (count >= 2 && count <= 4) return l10n.get('types');
    return l10n.get('type_many');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.of(context).get('auto_cleanup_title'),
          style: TextStyle(color: cs.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 14),
        children: [
          TelegramSettingsSection(
            children: [
              TelegramSettingsTile(
                title: AppLocalizations.of(context).get('what_to_delete'),
                subtitle: _selectedTypesText(),
                leading: const TelegramSettingsIcon(
                  icon: Icons.check_box_outlined,
                  color: Color(0xFF007AFF),
                ),
                onTap: () => _showCleanupTypesSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppLocalizations.of(context).get('cleanup_warning'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TelegramSettingsSection(
            children: [
              TelegramSettingsTile(
                title: AppLocalizations.of(context).get('cleanup_time'),
                subtitle: _cleanupDaysText(),
                leading: const TelegramSettingsIcon(
                  icon: Icons.schedule_outlined,
                  color: Color(0xFF34C759),
                ),
                onTap: () => _showCleanupDaysSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CleanupTypeTile extends StatelessWidget {
  const _CleanupTypeTile({
    required this.title,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String type;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(type),
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
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
