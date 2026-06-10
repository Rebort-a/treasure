import 'package:flutter/material.dart';
import '../00.common/l10n/l10n.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/style/theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSection(
            context,
            title: S.general,
            children: [_buildLanguageTile(context), _buildThemeTile(context)],
          ),
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
        ...children.map((child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: child,
            ),
          );
        }),
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
          subtitle: Text(currentLocale == AppLocale.zh ? S.chinese : S.english),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, currentLocale),
        );
      },
    );
  }

  Widget _buildThemeTile(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeProvider.instance.themeMode,
      builder: (context, currentTheme, _) {
        return ListTile(
          leading: const Icon(Icons.palette),
          title: Text(S.theme),
          subtitle: Text(
            currentTheme == ThemeMode.light ? S.themeLight : S.themeDark,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemeDialog(context, currentTheme),
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context, ThemeMode currentTheme) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.theme),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: currentTheme,
            onChanged: (v) async {
              if (v == null) return;
              Navigator.pop(context);
              await ThemeProvider.instance.setThemeMode(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(S.themeLight),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(S.themeDark),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
        ],
      ),
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
            onChanged: (v) async {
              if (v == null) return;
              Navigator.pop(context);
              await LanguageProvider.instance.setLocale(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<AppLocale>(
                  title: Text(S.chinese),
                  value: AppLocale.zh,
                ),
                RadioListTile<AppLocale>(
                  title: Text(S.english),
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
