import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class GameCanvas extends StatefulWidget {
  final int columns;
  final int rows;
  final double padding;
  final String? backgroundColor;
  final bool backgroundImage;
  final Map<String, dynamic>? gridItemOptions;
  final String mode;

  const GameCanvas({
    super.key,
    required this.columns,
    required this.rows,
    this.padding = 16.0,
    this.backgroundColor,
    this.backgroundImage = false,
    this.gridItemOptions,
    required this.mode,
  });

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas> {
  List<dynamic>? objects;
  bool isLoadingObjects = true;
  List<Map<String, dynamic>> foodItems = [];
  List<Map<String, dynamic>> dangerItems = [];

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  Future<void> _loadObjects() async {
    String file = widget.mode == 'endless'
        ? 'assets/objects/endless_objects.json'
        : 'assets/objects/story_objects.json';
    try {
      final String jsonString = await rootBundle.loadString(file);
      setState(() {
        objects = json.decode(jsonString);
        isLoadingObjects = false;
      });
      _generateRandomFoodItems();
      _generateRandomDangerItems();
    } catch (e) {
      setState(() {
        objects = null;
        isLoadingObjects = false;
      });
    }
  }

  /// Generates random food items and places them on unoccupied grid positions.
  /// Returns a list of maps with food object and its position.
  void _generateRandomFoodItems({List<List<int>>? occupied}) {
    if (objects == null || widget.gridItemOptions == null) return;
    final int foodLimit = widget.gridItemOptions?['foodLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
    }
    final List<dynamic> foodObjects = objects!.where((obj) => obj['type'] == 'food').toList();
    final Random random = Random();
    final Set<String> usedPositions = {};
    foodItems.clear();
    // Ensure at least 1 food item is generated
    int count = foodLimit > 0 ? random.nextInt(foodLimit) + 1 : 1;
    for (int i = 0; i < count; i++) {
      int col, row;
      String posKey;
      do {
        col = random.nextInt(widget.columns);
        row = random.nextInt(widget.rows);
        posKey = '$col-$row';
      } while (usedPositions.contains(posKey) ||
          occupiedPositions.any((o) => o['col'] == col && o['row'] == row));
      usedPositions.add(posKey);
      final foodObj = foodObjects[random.nextInt(foodObjects.length)];
      foodItems.add({
        'object': foodObj,
        'col': col,
        'row': row,
      });
    }
    setState(() {});
  }

  /// Generates random danger items and places them on unoccupied grid positions.
  /// Returns a list of maps with danger object and its position.
  void _generateRandomDangerItems({List<List<int>>? occupied}) {
    if (objects == null || widget.gridItemOptions == null) return;
    final int dangerLimit = widget.gridItemOptions?['dangerItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
    }
    // Add already used positions by food to occupied
    for (var food in foodItems) {
      occupiedPositions.add({'col': food['col'], 'row': food['row']});
    }
    final List<dynamic> dangerObjects = objects!.where((obj) => obj['type'] == 'danger').toList();
    final Random random = Random();
    final Set<String> usedPositions = {};
    dangerItems.clear();
    int count = dangerLimit > 0 ? random.nextInt(dangerLimit) + 1 : 1;
    for (int i = 0; i < count; i++) {
      int col, row;
      String posKey;
      do {
        col = random.nextInt(widget.columns);
        row = random.nextInt(widget.rows);
        posKey = '$col-$row';
      } while (
        usedPositions.contains(posKey) ||
        occupiedPositions.any((o) => o['col'] == col && o['row'] == row)
      );
      usedPositions.add(posKey);
      final dangerObj = dangerObjects[random.nextInt(dangerObjects.length)];
      dangerItems.add({
        'object': dangerObj,
        'col': col,
        'row': row,
      });
    }
    setState(() {});
  }

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
    final double screenWidth = MediaQuery.of(context).size.width - (widget.padding * 2);
    final double cellSize = screenWidth / widget.columns;
    final double gridHeight = cellSize * widget.rows;

    BoxDecoration decoration;
    if (widget.backgroundImage) {
      decoration = const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: _parseColor(widget.backgroundColor),
      );
    }

    final bool coverColor = widget.gridItemOptions?['backgroundCoverColor'] ?? false;
    final String? coverImage = widget.gridItemOptions?['backgroundCoverImage'];

    return Padding(
      padding: EdgeInsets.only(left: widget.padding, right: widget.padding),
      child: Container(
        width: screenWidth,
        height: gridHeight,
        decoration: decoration,
        child: Stack(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.columns,
              ),
              itemCount: widget.columns * widget.rows,
              itemBuilder: (context, index) {
                if (!coverColor && coverImage != null && coverImage.isNotEmpty) {
                  return Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/decorations/$coverImage'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                } else {
                  return Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      border: Border.all(color: Colors.black12),
                    ),
                  );
                }
              },
            ),
            // Draw food items using their image
            if (foodItems.isNotEmpty)
              ...foodItems.map((food) {
                final int col = food['col'];
                final int row = food['row'];
                final String? imagePath = food['object']['image'];
                if (imagePath == null) return const SizedBox.shrink();
                return Positioned(
                  left: col * cellSize,
                  top: row * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            // Draw danger items using their image
            if (dangerItems.isNotEmpty)
              ...dangerItems.map((danger) {
                final int col = danger['col'];
                final int row = danger['row'];
                final String? imagePath = danger['object']['image'];
                if (imagePath == null) return const SizedBox.shrink();
                return Positioned(
                  left: col * cellSize,
                  top: row * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
