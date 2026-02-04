import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/subscription_provider.dart';
import 'dart:async';

class PaywallScreen extends StatelessWidget {
  final bool isBarrier; // If true, user cannot dismiss (Trial Expired)

  const PaywallScreen({super.key, this.isBarrier = false});

  @override
  Widget build(BuildContext context) {
    final subProvider = Provider.of<SubscriptionProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Fallback price if product not loaded (e.g. testing)
    String priceText = "₹79";
    if (subProvider.products.isNotEmpty) {
      priceText = subProvider.products.first.price;
    }

    return Scaffold(
      body: Consumer<SubscriptionProvider>(
        builder: (context, subProvider, child) {
          // Listen for success and close screen
          if (subProvider.isPremium && !isBarrier) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Premium Access Restored Successfully! Welcome Back.",
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
                Navigator.of(context).pop();
              }
            });
          }

          return Stack(
            children: [
              // Background Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.tertiary],
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: Column(
                  children: [
                    // Close Button (Only if not a barrier)
                    if (!isBarrier)
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),

                    const Spacer(flex: 1),

                    // Icon / Logo
                    // Icon / Logo
                    SecretLogo(
                      onSecretTriggered: () {
                        _showSecretCodeDialog(context, subProvider);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      isBarrier ? "Trial Expired" : "Go Premium",
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Unlock lifetime access to all features",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Features List
                    _buildFeatureRow(
                      Icons.backup,
                      "Secure Cloud Backup",
                      Colors.white,
                    ),
                    _buildFeatureRow(
                      Icons.check_circle_outline,
                      "Lifetime Access",
                      Colors.white,
                    ),
                    _buildFeatureRow(
                      Icons.block,
                      "No Restrictions",
                      Colors.white,
                    ),

                    const Spacer(flex: 2),

                    // Pricing Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Lifetime Subscription",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            priceText,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final error = await subProvider.buyLifetime();
                                if (context.mounted && error != null) {
                                  _showErrorDialog(context, error);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Subscribe Now",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Restore Purchase
                    TextButton(
                      onPressed: () {
                        subProvider.restorePurchases();
                      },
                      child: const Text(
                        "Restore Purchases",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Debug Info
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Debug: Products Loaded: ${subProvider.products.length}\nID: lifetime_subscription_79",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 10,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Purchase Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showSecretCodeDialog(
    BuildContext context,
    SubscriptionProvider subProvider,
  ) {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter Secret Code"),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(hintText: "Code"),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text == "FAMILY") {
                await subProvider.activateSecretOverride();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop(); // Close dialog
                  // The main listener in build() will handle closing the screen
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text("Secret Code Accepted!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text("Unlock"),
          ),
        ],
      ),
    );
  }
}

class SecretLogo extends StatefulWidget {
  final VoidCallback onSecretTriggered;
  const SecretLogo({super.key, required this.onSecretTriggered});

  @override
  State<SecretLogo> createState() => _SecretLogoState();
}

class _SecretLogoState extends State<SecretLogo> {
  Timer? _timer;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        // Start 5 second timer
        _timer = Timer(const Duration(seconds: 5), () {
          widget.onSecretTriggered();
        });
      },
      onTapUp: (_) => _timer?.cancel(),
      onTapCancel: () => _timer?.cancel(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.diamond_outlined,
          size: 80,
          color: Colors.white,
        ),
      ),
    );
  }
}
