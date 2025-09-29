import 'package:flutter/material.dart';
import '../core/theme.dart';

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.borderWidth = 3.0,
    this.fontSize = 18,
    this.iconSize = 22,
    this.radius = 26,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double borderWidth;
  final double fontSize;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: Ink(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: kBrand, width: borderWidth),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kBrand, size: iconSize),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: kBrand,
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
