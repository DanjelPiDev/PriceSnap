import 'package:flutter/material.dart';
import '../screens/saved_list_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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
                  title: 'Shopping Cart',
                  onTap: () => Navigator.pop(context),
                ),
                _buildTile(
                  context,
                  icon: Icons.receipt_long,
                  title: 'Saved Receipts',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SavedListScreen()),
                    );
                  },
                ),
                const Divider(height: 32, indent: 16, endIndent: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Settings',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                _buildTile(
                  context,
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    // TODO: Settings screen
                  },
                ),
                _buildTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'About PriceSnap',
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
              'v1.0.0',
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
