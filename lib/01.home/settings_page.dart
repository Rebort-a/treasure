import 'package:flutter/material.dart';

import '../00.common/l10n/l10n.dart';
import '../00.common/l10n/strings.dart';

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
            children: [_buildLanguageTile(context)],
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
      builder: (_) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.language),
        children: [
          RadioGroup<AppLocale>(
            groupValue: currentLocale,
            onChanged: (v) {
              if (v == null) return;
              Navigator.pop(context);
              LanguageProvider.instance.setLocale(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<AppLocale>(
                  title: const Text('中文'),
                  value: AppLocale.zh,
                ),
                RadioListTile<AppLocale>(
                  title: const Text('English'),
                  value: AppLocale.en,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
