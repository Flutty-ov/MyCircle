import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_scope.dart';
import 'telegram_settings_style.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  bool _copied = false;

  Future<void> _copyToken(BuildContext context) async {
    final controller = AppScope.of(context);
    final token = controller.characterToken;
    await Clipboard.setData(ClipboardData(text: token));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = AppScope.of(context);
    final token = controller.characterToken;

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
          'Устройства',
          style: TextStyle(color: cs.onSurface),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 14),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Вы можете зайти в приложение MyCirkle для компьютера введя свой Токен',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TelegramSettingsSection(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _copyToken(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const TelegramSettingsIcon(
                          icon: Icons.vpn_key_outlined,
                          color: Color(0xFF007AFF),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Токен',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  token,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.8),
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _copied ? Icons.check : Icons.copy,
                          color: _copied
                              ? const Color(0xFF34C759)
                              : cs.onSurface.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_copied) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Токен скопирован',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF34C759),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
