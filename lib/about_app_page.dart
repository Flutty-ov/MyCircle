import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'privacy_policy_page.dart';
import 'eula_page.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении'), centerTitle: true),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version = info == null
              ? ''
              : 'Версия ${info.version}${info.buildNumber.isEmpty ? '' : '+${info.buildNumber}'}';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
            children: [
              Center(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/icons/MyCircle.png',
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      version,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _LegalButton(
                      icon: Icons.shield_outlined,
                      label: 'Privacy Policy',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _LegalButton(
                      icon: Icons.description_outlined,
                      label: 'EULA',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EulaPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: 16),
              Text(
                'О мессенджере\n\nMyCircle — это мессенджер для создания персональных виртуальных пространств, ориентированный на визуальную кастомизацию, удобство групповых коммуникаций и автономию пользователей.\n\n\n\nКлючевые принципы\n\nСобственная инфраструктура\nВ основе MyCircle лежит концепция персональных серверов. Пользователи самостоятельно разворачивают серверную часть, что позволяет гибко настраивать среду общения и самостоятельно определять круг участников.\n\nКонфиденциальность\nРазработчик мессенджера не осуществляет сбор, хранение или обработку ваших данных. Вся информация (сообщения, медиафайлы) располагается исключительно на сервере, выбранном или созданном пользователем.\n\nОрганизация доступа\nВы самостоятельно определяете, кому предоставить доступ к вашему серверу, что исключает появление случайных участников или получение нежелательного спама.\n\n\n\nТехнологический стек\n\nМессенджер разработан на фреймворке Flutter, что обеспечивает высокую производительность, стабильность работы и отзывчивость интерфейса.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LegalButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
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
