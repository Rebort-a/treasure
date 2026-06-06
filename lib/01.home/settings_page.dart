import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/strings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.gameSettings)),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildSection(
            context,
            title: S.general,
            children: [
              _buildLanguageTile(context),
            ],
          ),
          const SizedBox(height: 8),
          _buildSection(
            context,
            title: S.about,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(S.version),
                subtitle: const Text('1.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageTile(BuildContext context) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: LanguageProvider.instance.locale,
      builder: (context, currentLocale, _) {
        return ListTile(
          leading: const Icon(Icons.language),
          title: Text(S.language),
          subtitle: Text(currentLocale == AppLocale.zh ? '中文' : 'English'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, currentLocale),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context, AppLocale currentLocale) {
    showDialog(
      context: context,
      builder: (dialogContext) => ValueListenableBuilder<AppLocale>(
        valueListenable: LanguageProvider.instance.locale,
        builder: (_, locale, __) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(S.language),
            content: RadioGroup<AppLocale>(
              groupValue: locale,
              onChanged: (v) {
                if (v != null) {
                  LanguageProvider.instance.setLocale(v);
                  Navigator.pop(dialogContext);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Radio<AppLocale>(value: AppLocale.zh),
                    title: const Text('中文'),
                    onTap: () {
                      LanguageProvider.instance.setLocale(AppLocale.zh);
                      Navigator.pop(dialogContext);
                    },
                  ),
                  ListTile(
                    leading: Radio<AppLocale>(value: AppLocale.en),
                    title: const Text('English'),
                    onTap: () {
                      LanguageProvider.instance.setLocale(AppLocale.en);
                      Navigator.pop(dialogContext);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(S.close),
              ),
            ],
          );
        },
      ),
    );
  }
}
