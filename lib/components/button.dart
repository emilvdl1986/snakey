import 'package:flutter/material.dart';

enum ButtonType { filled, outlined, text }

class Button extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color color;
  final IconData? icon;
  final ButtonType type;

  const Button({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 50,
    this.color = Colors.green,
    this.icon,
    this.type = ButtonType.filled,
  });

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = MediaQuery.of(context).size.width * 0.8;
    ButtonStyle style;
    Color effectiveTextColor = Colors.white;
    Color effectiveIconColor = Colors.white;
    switch (type) {
      case ButtonType.outlined:
        style = OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black, width: 2),
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          minimumSize: Size(buttonWidth, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
        effectiveTextColor = Colors.black;
        effectiveIconColor = Colors.black;
        break;
      case ButtonType.text:
        style = TextButton.styleFrom(
          foregroundColor: color,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          minimumSize: Size(buttonWidth, height),
        );
        effectiveTextColor = color;
        effectiveIconColor = color;
        break;
      case ButtonType.filled:
      default:
        style = ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          minimumSize: Size(buttonWidth, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
        effectiveTextColor = Colors.white;
        effectiveIconColor = Colors.white;
        break;
    }

    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: effectiveIconColor,
            size: 22,
          ),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: TextStyle(
            color: effectiveTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );

    switch (type) {
      case ButtonType.outlined:
        return SizedBox(
          width: buttonWidth,
          height: height,
          child: OutlinedButton(
            style: style,
            onPressed: onPressed,
            child: content,
          ),
        );
      case ButtonType.text:
        return SizedBox(
          width: buttonWidth,
          height: height,
          child: TextButton(
            style: style,
            onPressed: onPressed,
            child: content,
          ),
        );
      case ButtonType.filled:
      default:
        return SizedBox(
          width: buttonWidth,
          height: height,
          child: ElevatedButton(
            style: style,
            onPressed: onPressed,
            child: content,
          ),
        );
    }
  }
}
