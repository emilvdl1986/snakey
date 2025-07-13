import 'package:flutter/material.dart';
import 'snake_controller.dart';
import 'game_items.dart';

class GameGrid extends StatelessWidget {
  final int columns;
  final int rows;
  final double cellSize;
  final SnakeController snakeController;
  final GameItemsManager itemsManager;

  const GameGrid({
    Key? key,
    required this.columns,
    required this.rows,
    required this.cellSize,
    required this.snakeController,
    required this.itemsManager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    // Draw food items
    for (final food in itemsManager.foodItems) {
      final int col = food['col'] ?? 0;
      final int row = food['row'] ?? 0;
      final String? imagePath = food['object']?['image'];
      children.add(Positioned(
        left: col * cellSize,
        top: row * cellSize,
        width: cellSize,
        height: cellSize,
        child: imagePath != null
            ? Image.asset(imagePath, fit: BoxFit.contain)
            : Container(color: Colors.green, width: cellSize, height: cellSize),
      ));
    }

    // Draw danger items
    for (final danger in itemsManager.dangerItems) {
      final int col = danger['col'] ?? 0;
      final int row = danger['row'] ?? 0;
      final String? imagePath = danger['object']?['image'];
      children.add(Positioned(
        left: col * cellSize,
        top: row * cellSize,
        width: cellSize,
        height: cellSize,
        child: imagePath != null
            ? Image.asset(imagePath, fit: BoxFit.contain)
            : Container(color: Colors.red, width: cellSize, height: cellSize),
      ));
    }

    // Draw exit items
    for (final exit in itemsManager.exitItems) {
      final int col = exit['col'] ?? 0;
      final int row = exit['row'] ?? 0;
      final String? imagePath = exit['object']?['image'];
      children.add(Positioned(
        left: col * cellSize,
        top: row * cellSize,
        width: cellSize,
        height: cellSize,
        child: imagePath != null
            ? Image.asset(imagePath, fit: BoxFit.contain)
            : Container(color: Colors.blue, width: cellSize, height: cellSize),
      ));
    }

    // Draw heart items
    for (final heart in itemsManager.heartItems) {
      final int col = heart['col'] ?? 0;
      final int row = heart['row'] ?? 0;
      final String? imagePath = heart['object']?['image'];
      children.add(Positioned(
        left: col * cellSize,
        top: row * cellSize,
        width: cellSize,
        height: cellSize,
        child: imagePath != null
            ? Image.asset(imagePath, fit: BoxFit.contain)
            : Container(color: Colors.pink, width: cellSize, height: cellSize),
      ));
    }

    // Draw coin items
    for (final coin in itemsManager.coinItems) {
      final int col = coin['col'] ?? 0;
      final int row = coin['row'] ?? 0;
      final String? imagePath = coin['object']?['image'];
      children.add(Positioned(
        left: col * cellSize,
        top: row * cellSize,
        width: cellSize,
        height: cellSize,
        child: imagePath != null
            ? Image.asset(imagePath, fit: BoxFit.contain)
            : Container(color: Colors.yellow, width: cellSize, height: cellSize),
      ));
    }

    // Draw key items
    for (final key in itemsManager.keyItems) {
      final int col = key['col'] ?? 0;
      final int row = key['row'] ?? 0;
      final String? imagePath = key['object']?['image'];
      children.add(Positioned(
        left: col * cellSize,
        top: row * cellSize,
        width: cellSize,
        height: cellSize,
        child: imagePath != null
            ? Image.asset(imagePath, fit: BoxFit.contain)
            : Container(color: Colors.orange, width: cellSize, height: cellSize),
      ));
    }

    // Draw snake
    for (int i = 0; i < snakeController.snakePositions.length; i++) {
      final pos = snakeController.snakePositions[i];
      final int col = pos['col'] ?? 0;
      final int row = pos['row'] ?? 0;
      final bool isHead = i == 0;
      final bool isTail = i == snakeController.snakePositions.length - 1;
      final double size = isTail ? cellSize * 0.7 : cellSize * 0.9;
      final double offset = (cellSize - size) / 2;
      children.add(Positioned(
        left: col * cellSize + offset,
        top: row * cellSize + offset,
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(
            color: isHead ? Colors.black : Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ));
    }

    return Container(
      width: columns * cellSize,
      height: rows * cellSize,
      color: Colors.black12,
      child: Stack(children: children),
    );
  }
}
