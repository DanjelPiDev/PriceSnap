import 'package:flutter/material.dart';
import 'package:price_snap/models/shopping_list.dart';
import 'package:price_snap/screens/settings_screen.dart';
import 'package:price_snap/screens/shopping_list_screen.dart';
import '../l10n/app_localizations.dart';
import '../screens/saved_products_screen.dart';
import '../screens/saved_receipt_screen.dart';
import '../screens/shopping_cart_screen.dart';

class AppDrawer extends StatelessWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final Locale locale;
  final void Function(Locale) onLocaleChanged;
  final VoidCallback? onOpenSettings;

  AppDrawer({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.locale,
    required this.onLocaleChanged,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD2AA19), Color(0xFFE1DE5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white70,
                  child: Icon(Icons.person, size: 32, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'PriceSnap',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                _buildTile(
                  context,
                  icon: Icons.shopping_cart_outlined,
                  title: AppLocalizations.of(context)!.drawerShoppingCart,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShoppingCart(
                          onOpenSettings: onOpenSettings,
                          locale: locale,
                          onLocaleChanged: onLocaleChanged,
                          themeMode: themeMode,
                          onThemeChanged: onThemeChanged,
                        ),
                      ),
                    );
                  },
                ),
                _buildTile(
                  context,
                  icon: Icons.receipt_long,
                  title: AppLocalizations.of(context)!.drawerShoppingList,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShoppingListsScreen(),),
                    );
                  }
                ),
                const Divider(height: 32, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Saved Data',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                _buildTile(
                  context,
                  icon: Icons.receipt_sharp,
                  title: AppLocalizations.of(context)!.drawerSavedReceipts,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SavedListScreen()),
                    );
                  },
                ),
                _buildTile(
                  context,
                  icon: Icons.ad_units,
                  title: AppLocalizations.of(context)!.drawerSavedProducts,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SavedProductsScreen()),
                    );
                  }
                ),
                const Divider(height: 32, indent: 16, endIndent: 16),

                _buildTile(
                  context,
                  icon: Icons.settings,
                  title: AppLocalizations.of(context)!.drawerSettings,
                  onTap: () async {
                    Navigator.pop(context);
                    await Future.delayed(const Duration(milliseconds: 250));
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          themeMode: themeMode,
                          onThemeChanged: onThemeChanged,
                          locale: locale,
                          onLocaleChanged: onLocaleChanged,
                        ),
                      ),
                    );
                  },
                ),
                _buildTile(
                  context,
                  icon: Icons.info_outline,
                  title: AppLocalizations.of(context)!.drawerAbout,
                  onTap: () {
                    // TODO: About screen
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'v0.1.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext ctx,
      {required IconData icon,
        required String title,
        required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: Colors.blue.shade50,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
