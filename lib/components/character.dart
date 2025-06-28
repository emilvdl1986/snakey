import 'package:flutter/material.dart';

class Character extends StatelessWidget {
  final double size;
  final Color color;
  final IconData icon;

  const Character({
    super.key,
    this.size = 24.0,
    this.color = Colors.green,
    this.icon = Icons.circle,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
    );
  }
}
