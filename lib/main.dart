import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:price_snap/screens/shopping_cart_screen.dart';
import 'package:price_snap/screens/settings_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PriceSnapApp());
}

class PriceSnapApp extends StatefulWidget {
  const PriceSnapApp({super.key});

  @override
  State<PriceSnapApp> createState() => _PriceSnapAppState();
}

class _PriceSnapAppState extends State<PriceSnapApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode');
    final langCode = prefs.getString('languageCode');

    Locale? detectedLocale;
    if (langCode != null) {
      detectedLocale = Locale(langCode);
    } else {
      detectedLocale = WidgetsBinding.instance.platformDispatcher.locale;
      if (!['de', 'en'].contains(detectedLocale.languageCode)) {
        detectedLocale = const Locale('en');
      }
    }

    setState(() {
      if (themeString != null) {
        _themeMode = ThemeMode.values.firstWhere(
              (m) => m.toString().split('.').last == themeString,
          orElse: () => ThemeMode.light,
        );
      }
      _locale = detectedLocale;
    });
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString().split('.').last);
    setState(() => _themeMode = mode);
  }

  Future<void> _changeLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    if (_locale == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      title: 'PriceSnap',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      home: ShoppingCart(
        themeMode: _themeMode,
        onThemeChanged: _changeTheme,
        locale: _locale!,
        onLocaleChanged: _changeLocale,
        onOpenSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                themeMode: _themeMode,
                onThemeChanged: _changeTheme,
                locale: _locale!,
                onLocaleChanged: _changeLocale,
              ),
            ),
          );
        },
      ),
    );
  }
}
