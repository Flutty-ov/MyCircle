import 'package:flutter/material.dart';

class TelegramSettingsSection extends StatelessWidget {
  const TelegramSettingsSection({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _withDividers(context, children),
        ),
      ),
    );
  }

  List<Widget> _withDividers(BuildContext context, List<Widget> children) {
    if (children.isEmpty) return const <Widget>[];
    final cs = Theme.of(context).colorScheme;
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),
        );
      }
    }
    return out;
  }
}

class TelegramSettingsTile extends StatelessWidget {
  const TelegramSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.72),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              if (leading != null) ...[
                SizedBox(width: 28, height: 28, child: Center(child: leading)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    if ((subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: subtitleStyle),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TelegramSettingsIcon extends StatelessWidget {
  const TelegramSettingsIcon({
    super.key,
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}
