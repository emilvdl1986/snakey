import 'package:flutter/material.dart';

class GameCanvas extends StatelessWidget {
  final int columns;
  final int rows;
  final double padding;

  const GameCanvas({
    super.key,
    required this.columns,
    required this.rows,
    this.padding = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width - (padding * 2);
    final double cellSize = screenWidth / columns;
    final double gridHeight = cellSize * rows;

    return Padding(
      padding: EdgeInsets.only(left: padding, right: padding), // Remove top padding
      child: SizedBox(
        width: screenWidth,
        height: gridHeight,
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
