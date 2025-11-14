import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/settings_provider.dart';
import 'vendor_list_screen.dart';
import 'service_templates_screen.dart';

class MasterScreen extends StatelessWidget {
  const MasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      // We set a background color that matches the theme
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GridView.count(
        padding: const EdgeInsets.all(16.0),
        // Create 2 columns
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        children: [
          // --- 1. Manage Vendors Card ---
          _buildMasterCard(
            context: context,
            icon: Icons.store,
            title: 'Manage Workshops',
            color: settings.primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VendorListScreen(),
                ),
              );
            },
          ),

          // --- 2. Manage Templates Card ---
          _buildMasterCard(
            context: context,
            icon: Icons.handyman,
            title: 'Manage Auto Parts',
            color: settings.primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ServiceTemplatesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Helper Widget to build the cards ---
  Widget _buildMasterCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
