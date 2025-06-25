import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final Locale locale;
  final void Function(Locale) onLocaleChanged;

  const SettingsScreen({
    Key? key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.locale,
    required this.onLocaleChanged,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _themeMode;
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _locale = widget.locale;
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString().split('.').last);
  }

  Future<void> _saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
  }

  void _changeTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveThemeMode(mode);
    widget.onThemeChanged(mode);
  }

  void _changeLocale(Locale locale) {
    setState(() => _locale = locale);
    _saveLocale(locale);
    widget.onLocaleChanged(locale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.drawerSettings)),
      body: ListView(
        children: [
          ListTile(
            title: Text(AppLocalizations.of(context)!.language),
            dense: true,
          ),
          RadioListTile<Locale>(
            value: const Locale('de'),
            groupValue: _locale,
            title: const Text('Deutsch'),
            onChanged: (locale) => _changeLocale(locale!),
          ),
          RadioListTile<Locale>(
            value: const Locale('en'),
            groupValue: _locale,
            title: const Text('English'),
            onChanged: (locale) => _changeLocale(locale!),
          ),
          const Divider(height: 32),
          ListTile(
            title: Text(AppLocalizations.of(context)!.theme),
            dense: true,
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: _themeMode,
            title: Text(AppLocalizations.of(context)!.lightMode),
            onChanged: (mode) => _changeTheme(mode!),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: _themeMode,
            title: Text(AppLocalizations.of(context)!.darkMode),
            onChanged: (mode) => _changeTheme(mode!),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: _themeMode,
            title: const Text('System'),
            onChanged: (mode) => _changeTheme(mode!),
          ),
        ],
      ),
    );
  }
}
