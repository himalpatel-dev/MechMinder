import 'package:flutter/material.dart';

class CustomAnimatedBottomBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<BottomBarItem> items;
  final Color backgroundColor;

  const CustomAnimatedBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
    this.backgroundColor = Colors.white,
  });

  @override
  State<CustomAnimatedBottomBar> createState() =>
      _CustomAnimatedBottomBarState();
}

class _CustomAnimatedBottomBarState extends State<CustomAnimatedBottomBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ), // Optional: rounded top corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: widget.items.map((item) {
              var index = widget.items.indexOf(item);
              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onItemSelected(index),
                  child: _buildItem(item, index == widget.selectedIndex),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BottomBarItem item, bool isSelected) {
    final Color primaryColor = Theme.of(
      context,
    ).colorScheme.primary; // Get primary color from theme
    final Color iconColor = isSelected ? Colors.white : Colors.grey[600]!;
    final Color textColor = isSelected ? primaryColor : Colors.grey[600]!;
    final FontWeight textWeight = isSelected
        ? FontWeight.bold
        : FontWeight.normal;
    final double textScale = isSelected ? 1.05 : 1.0;

    return Column(
      mainAxisSize:
          MainAxisSize.min, // Important to prevent column taking full height
      children: [
        // Icon with animated background
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isSelected ? 50 : 40,
          height: isSelected ? 50 : 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? primaryColor
                : Colors.transparent, // Use primary color for solid background
            // If you want a gradient as in the image, use a ShaderMask around the icon instead
            // For simplicity, we start with solid color.
            // For gradient:
            // gradient: isSelected ? LinearGradient(
            //   colors: [Colors.cyan.shade300, Colors.blue.shade700],
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomRight,
            // ) : null,
          ),
          alignment: Alignment.center,
          child: Icon(item.icon, color: iconColor, size: isSelected ? 28 : 24),
        ),
        const SizedBox(height: 4),
        // Text with animated style
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          style: TextStyle(
            color: textColor,
            fontWeight: textWeight,
            fontSize: 12 * textScale,
          ),
          child: Text(item.title),
        ),
        const SizedBox(height: 4),
        // Underline indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 3,
          width: isSelected ? 30 : 0,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class BottomBarItem {
  final IconData icon;
  final String title;

  BottomBarItem({required this.icon, required this.title});
}
