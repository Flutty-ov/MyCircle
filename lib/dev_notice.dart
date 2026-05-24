import 'package:flutter/material.dart';
import 'app_language.dart';

Future<void> showDevNoticeDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.get('dev_notice_title')),
        content: Text(l10n.get('dev_notice_text')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.get('close_btn')),
          ),
        ],
      );
    },
  );
}
