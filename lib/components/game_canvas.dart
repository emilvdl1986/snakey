import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:snakey/components/count_down.dart';

enum SnakeDirection { up, down, left, right }

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
  List<Map<String, dynamic>> exitItems = [];

  Map<String, dynamic>? snakeSettings;
  List<Map<String, int>> snakePositions = [];

  SnakeDirection snakeDirection = SnakeDirection.right;

  bool _showCountdown = true;

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  void _loadSnake() {
    // Parse snake settings from gridItemOptions or snakeSettings
    snakeSettings = getSnakeSettings(widget.gridItemOptions);
    // Place the snake on the grid in available positions based on snake length
    int snakeLength = 3; // default
    if (snakeSettings != null && snakeSettings!['length'] is int) {
      snakeLength = snakeSettings!['length'];
    }
    // Collect all occupied positions
    final Set<String> occupied = {};
    for (var food in foodItems) {
      occupied.add('${food['col']}-${food['row']}');
    }
    for (var danger in dangerItems) {
      occupied.add('${danger['col']}-${danger['row']}');
    }
    for (var exit in exitItems) {
      occupied.add('${exit['col']}-${exit['row']}');
    }
    // Try to find a horizontal or vertical segment of length snakeLength
    final Random random = Random();
    List<List<Map<String, int>>> possiblePositions = [];
    // Horizontal
    for (int row = 0; row < widget.rows; row++) {
      for (int col = 0; col <= widget.columns - snakeLength; col++) {
        bool canPlace = true;
        List<Map<String, int>> segment = [];
        for (int i = 0; i < snakeLength; i++) {
          String posKey = '${col + i}-$row';
          if (occupied.contains(posKey)) {
            canPlace = false;
            break;
          }
          segment.add({'col': col + i, 'row': row});
        }
        if (canPlace) possiblePositions.add(segment);
      }
    }
    // Vertical
    for (int col = 0; col < widget.columns; col++) {
      for (int row = 0; row <= widget.rows - snakeLength; row++) {
        bool canPlace = true;
        List<Map<String, int>> segment = [];
        for (int i = 0; i < snakeLength; i++) {
          String posKey = '$col-${row + i}';
          if (occupied.contains(posKey)) {
            canPlace = false;
            break;
          }
          segment.add({'col': col, 'row': row + i});
        }
        if (canPlace) possiblePositions.add(segment);
      }
    }
    if (possiblePositions.isNotEmpty) {
      snakePositions = possiblePositions[random.nextInt(possiblePositions.length)];
    } else {
      snakePositions = [];
    }
    setState(() {});
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
      _generateRandomExitItems();
      _loadSnake(); // Load snake after all items are placed
    } catch (e) {
      setState(() {
        objects = null;
        isLoadingObjects = false;
      });
    }
  }

  // Helper to get snake settings from gridItemOptions or snakeSettings
  Map<String, dynamic>? getSnakeSettings(Map<String, dynamic>? config) {
    if (config == null) return null;
    if (config.containsKey('snakeSettings')) {
      return config['snakeSettings'] as Map<String, dynamic>?;
    }
    // fallback to gridItemOptions for backward compatibility
    if (config.containsKey('gridItemOptions')) {
      final grid = config['gridItemOptions'];
      if (grid is Map<String, dynamic> && grid.containsKey('snakeSettings')) {
        return grid['snakeSettings'] as Map<String, dynamic>?;
      }
    }
    return null;
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

  /// Generates random exit items and places them on unoccupied grid positions.
  /// Returns a list of maps with exit object and its position.
  void _generateRandomExitItems({List<List<int>>? occupied}) {
    if (objects == null || widget.gridItemOptions == null) return;
    final int exitLimit = widget.gridItemOptions?['exitItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
    }
    // Add already used positions by food and danger to occupied
    for (var food in foodItems) {
      occupiedPositions.add({'col': food['col'], 'row': food['row']});
    }
    for (var danger in dangerItems) {
      occupiedPositions.add({'col': danger['col'], 'row': danger['row']});
    }
    final List<dynamic> exitObjects = objects!.where((obj) => obj['type'] == 'exit').toList();
    final Random random = Random();
    final Set<String> usedPositions = {};
    exitItems.clear();
    int count = exitLimit > 0 ? exitLimit : 1;
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
      final exitObj = exitObjects[random.nextInt(exitObjects.length)];
      exitItems.add({
        'object': exitObj,
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

  // Moves the snake one step in the current direction
  void _snakeMoving() {
    if (snakePositions.isEmpty) return;
    // Get current head
    final head = snakePositions.first;
    int newCol = head['col']!;
    int newRow = head['row']!;
    switch (snakeDirection) {
      case SnakeDirection.up:
        newRow -= 1;
        break;
      case SnakeDirection.down:
        newRow += 1;
        break;
      case SnakeDirection.left:
        newCol -= 1;
        break;
      case SnakeDirection.right:
        newCol += 1;
        break;
    }
    // Insert new head
    snakePositions.insert(0, {'col': newCol, 'row': newRow});
    // Remove tail
    snakePositions.removeLast();
    setState(() {});
  }

  void _onCountdownFinished() {
    setState(() {
      _showCountdown = false;
    });
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
            // Always show the grid and objects
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
                if (imagePath == null) {
                  return const SizedBox.shrink();
                }
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
            // Draw exit items using their image
            if (exitItems.isNotEmpty)
              ...exitItems.map((exit) {
                final int col = exit['col'];
                final int row = exit['row'];
                final String? imagePath = exit['object']['image'];
                if (imagePath == null) {
                  return const SizedBox.shrink();
                }
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
            // Draw snake on the grid
            if (snakePositions.isNotEmpty)
              ...snakePositions.asMap().entries.map((entry) {
                final int idx = entry.key;
                final int col = entry.value['col']!;
                final int row = entry.value['row']!;
                final bool isHead = idx == 0;
                final bool isTail = idx == snakePositions.length - 1;
                final double size = isTail ? cellSize * 0.7 : cellSize * 0.9;
                final double offset = (cellSize - size) / 2;
                return Positioned(
                  left: col * cellSize + offset,
                  top: row * cellSize + offset,
                  width: size,
                  height: size,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(size * 0.3),
                        ),
                      ),
                      if (isHead)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: size * 0.18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: size * 0.18,
                                  height: size * 0.18,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: size * 0.18),
                                Container(
                                  width: size * 0.18,
                                  height: size * 0.18,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            // Show countdown overlay if needed
            if (_showCountdown)
              Positioned.fill(
                child: CountDown(
                  seconds: 3,
                  onFinished: _onCountdownFinished,
                  textStyle: TextStyle(
                    fontSize: 64,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
