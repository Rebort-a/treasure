import 'dart:async';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../../00.common/l10n/l10n.dart';
import '../../../00.common/l10n/strings.dart';
import '../../../00.common/service/audio_preferences.dart';
import '../../../00.common/style/theme.dart';
import '../../../00.common/tool/app_info.dart';
import '../../../00.common/widget/component/chat_component.dart'
    show MediaFilePicker;
import '../../middle/background_settings.dart';
import '../../middle/player_settings.dart';
import '../../middle/home_state.dart';

class HomeSettingsPage extends StatelessWidget {
  final HomeState state;
  final AudioPreferences? audioPreferences;

  const HomeSettingsPage({
    super.key,
    required this.state,
    this.audioPreferences,
  });

  AudioPreferences get _audio => audioPreferences ?? AudioPreferences.instance;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.only(
      top: 8,
      bottom: 8 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      _settingsSection(
        context,
        title: S.general,
        children: [_defaultNameTile(context), _languageTile(context)],
      ),
      _settingsSection(
        context,
        title: S.appearance,
        children: [_themeTile(context), _backgroundTile(context)],
      ),
      _settingsSection(
        context,
        title: S.gameAudio,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _audio.soundEnabled,
            builder: (_, enabled, _) => SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: Text(S.gameSoundEffects),
              value: enabled,
              onChanged: _audio.setSoundEnabled,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _audio.voiceEnabled,
            builder: (_, enabled, _) => SwitchListTile(
              secondary: const Icon(Icons.record_voice_over_rounded),
              title: Text(S.voiceAnnouncements),
              value: enabled,
              onChanged: _audio.setVoiceEnabled,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _audio.musicEnabled,
            builder: (_, enabled, _) => Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.music_note_rounded),
                  title: Text(S.backgroundMusic),
                  value: enabled,
                  onChanged: _audio.setMusicEnabled,
                ),
                ValueListenableBuilder<double>(
                  valueListenable: _audio.musicVolume,
                  builder: (_, volume, _) => ListTile(
                    title: Slider(
                      value: volume,
                      label: '${(volume * 100).round()}%',
                      onChanged: enabled ? _audio.setMusicVolume : null,
                    ),
                    trailing: Text('${(volume * 100).round()}%'),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _audio.vibrationEnabled,
            builder: (_, enabled, _) => SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: Text(S.vibration),
              value: enabled,
              onChanged: _audio.setVibrationEnabled,
            ),
          ),
        ],
      ),
      _settingsSection(
        context,
        title: S.about,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(S.version),
            subtitle: Text(AppInfo.isLoaded ? (AppInfo.version ?? '—') : '—'),
          ),
        ],
      ),
    ],
  );

  Widget _defaultNameTile(BuildContext context) =>
      ValueListenableBuilder<String>(
        valueListenable: PlayerSettings.instance.defaultName,
        builder: (_, name, _) => ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(S.defaultPlayerName),
          subtitle: Text(name.isEmpty ? S.defaultPlayerNameSummary : name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(_editDefaultName(context)),
        ),
      );

  Future<void> _editDefaultName(BuildContext context) async {
    await PlayerSettings.instance.load();
    if (!context.mounted) return;

    final current = PlayerSettings.instance.defaultName.value;
    var name = current;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(S.defaultPlayerName),
          content: TextFormField(
            initialValue: current,
            autofocus: true,
            decoration: InputDecoration(
              labelText: S.userName,
              helperText: S.defaultPlayerNameHint,
            ),
            onChanged: (value) => name = value,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                PlayerSettings.instance.setDefaultName(name);
              },
              child: Text(S.confirm),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(S.cancel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) => Column(
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
      ...children.map(
        (child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ),
      ),
    ],
  );

  Widget _languageTile(BuildContext context) =>
      ValueListenableBuilder<AppLocale>(
        valueListenable: LanguageProvider.instance.locale,
        builder: (context, currentLocale, _) => ListTile(
          leading: const Icon(Icons.language),
          title: Text(S.language),
          subtitle: Text(currentLocale == AppLocale.zh ? S.chinese : S.english),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, currentLocale),
        ),
      );

  Widget _themeTile(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: ThemeProvider.instance.themeMode,
    builder: (context, currentTheme, _) => ListTile(
      leading: const Icon(Icons.palette),
      title: Text(S.theme),
      subtitle: Text(
        currentTheme == ThemeMode.light ? S.themeLight : S.themeDark,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context, currentTheme),
    ),
  );

  Widget _backgroundTile(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: state.changingBackground,
    builder: (_, changing, __) => ValueListenableBuilder<Uint8List?>(
      valueListenable: BackgroundSettings.instance.image,
      builder: (_, bytes, __) => ListTile(
        leading: const Icon(Icons.wallpaper_outlined),
        title: Text(S.background),
        subtitle: Text(S.homeBackgroundHint),
        trailing: changing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : bytes == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: S.restoreDefaultBackground,
                icon: const Icon(Icons.restore),
                onPressed: () =>
                    unawaited(_changeBackground(context, clear: true)),
              ),
        onTap: changing ? null : () => unawaited(_changeBackground(context)),
      ),
    ),
  );

  Future<void> _changeBackground(
    BuildContext context, {
    bool clear = false,
  }) async {
    if (state.changingBackground.value) return;
    state.changingBackground.value = true;
    try {
      final bytes = clear ? null : await MediaFilePicker.pickImage();
      if (!context.mounted || (!clear && bytes == null)) return;
      if (bytes != null && bytes.length > BackgroundSettings.maxImageBytes) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.backgroundImageTooLarge)));
        return;
      }
      await BackgroundSettings.instance.setImage(bytes);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.backgroundImageFailed)));
      }
    } finally {
      if (!state.isDisposed) state.changingBackground.value = false;
    }
  }

  void _showThemeDialog(BuildContext context, ThemeMode currentTheme) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.theme),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: currentTheme,
            onChanged: (value) async {
              if (value == null) return;
              Navigator.pop(dialogContext);
              await ThemeProvider.instance.setThemeMode(value);
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.language),
        children: [
          RadioGroup<AppLocale>(
            groupValue: currentLocale,
            onChanged: (value) async {
              if (value == null) return;
              Navigator.pop(dialogContext);
              await LanguageProvider.instance.setLocale(value);
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
