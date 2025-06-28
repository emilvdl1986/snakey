import 'package:flutter/material.dart';

class GameCanvas extends StatelessWidget {
  final int columns;
  final int rows;
  final double padding;
  final String? backgroundColor;
  final bool backgroundImage;

  const GameCanvas({
    super.key,
    required this.columns,
    required this.rows,
    this.padding = 16.0,
    this.backgroundColor,
    this.backgroundImage = false,
  });

  Color? _parseColor(String? colorString) {
    if (colorString == null) return null;
    switch (colorString.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width - (padding * 2);
    final double cellSize = screenWidth / columns;
    final double gridHeight = cellSize * rows;

    BoxDecoration decoration;
    if (backgroundImage) {
      decoration = const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: _parseColor(backgroundColor),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: padding, right: padding),
      child: Container(
        width: screenWidth,
        height: gridHeight,
        decoration: decoration,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
          ),
          itemCount: columns * rows,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border.all(color: Colors.black12),
              ),
            );
          },
        ),
      ),
    );
  }
}
