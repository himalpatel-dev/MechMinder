import 'package:flutter/material.dart';

class CommonPopup extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final bool isLoading;

  const CommonPopup({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Standardize size: 90% width, max 400px
    final double width = MediaQuery.of(context).size.width * 0.9;
    final double maxWidth = 400.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Theme.of(context).cardColor,
      child: Container(
        width: width > maxWidth ? maxWidth : width,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            Flexible(child: SingleChildScrollView(child: content)),

            // Actions
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
            ],
          ],
        ),
      ),
    );
  }
}
