import 'dart:async';
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

class _GameCanvasState extends State<GameCanvas> with SingleTickerProviderStateMixin {
  List<dynamic>? objects;
  bool isLoadingObjects = true;
  List<Map<String, dynamic>> foodItems = [];
  List<Map<String, dynamic>> dangerItems = [];
  List<Map<String, dynamic>> exitItems = [];

  Map<String, dynamic>? snakeSettings;
  List<Map<String, int>> snakePositions = [];

  SnakeDirection snakeDirection = SnakeDirection.right;
  SnakeDirection? _nextDirection;

  bool _showCountdown = true;
  Timer? _snakeTimer;

  AnimationController? _moveController;
  Animation<double>? _moveAnimation;
  Offset? _oldHeadOffset;
  Offset? _newHeadOffset;
  bool _isAnimating = false;
  int _pendingMoves = 0;

  final FocusNode _focusNode = FocusNode();

  int _snakeSpeed = 5; // default

  @override
  void initState() {
    super.initState();
    // Set random initial direction
    final directions = SnakeDirection.values;
    snakeDirection = directions[Random().nextInt(directions.length)];
    // Load speed from snakeSettings if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = widget.gridItemOptions?['snakeSettings'];
      if (settings != null && settings['speed'] != null) {
        setState(() {
          _snakeSpeed = settings['speed'];
        });
      }
      _setupAnimationController();
    });
    _loadObjects();
  }

  void _setupAnimationController() {
    // Clamp speed to avoid division by zero or too fast/slow
    final int speed = _snakeSpeed.clamp(1, 20);
    final int durationMs = (400 / speed * 5).clamp(60, 1000).toInt(); // Higher speed = shorter duration
    _moveController?.dispose();
    _moveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    _moveAnimation = CurvedAnimation(
      parent: _moveController!,
      curve: Curves.linear,
    );
    _moveAnimation!.addListener(() {
      setState(() {});
    });
    _moveController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isAnimating = false;
        _moveController!.reset();
        // Insert new head
        if (_pendingNewHead != null) {
          snakePositions.insert(0, _pendingNewHead!);
          snakePositions.removeLast();
          _pendingNewHead = null;
        }
        setState(() {});
        _snakeMoving();
      }
    });
  }

  Map<String, int>? _pendingNewHead;

  void _loadSnake() {
    // Use snakeSettings from widget.gridItemOptions or from widget if available
    if (widget.gridItemOptions != null && widget.gridItemOptions!.containsKey('snakeSettings')) {
      snakeSettings = widget.gridItemOptions!['snakeSettings'] as Map<String, dynamic>?;
    } else if (widget.mode == 'story' && objects != null && objects is Map<String, dynamic> && (objects as Map<String, dynamic>).containsKey('snakeSettings')) {
      snakeSettings = (objects as Map<String, dynamic>)['snakeSettings'] as Map<String, dynamic>?;
    }
    // fallback to previous logic if above fails
    snakeSettings ??= getSnakeSettings(widget.gridItemOptions);
    // Place the snake on the grid in available positions based on snake length
    int snakeLength = 3; // default
    if (snakeSettings != null && (snakeSettings!['initialLength'] ?? snakeSettings!['length']) is int) {
      snakeLength = snakeSettings!['initialLength'] ?? snakeSettings!['length'];
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
        if (canPlace) {
          // Check head can move at least 2 blocks
          final head = segment[0];
          int freeMoves = 0;
          // Check all four directions
          for (var dir in [
            {'dx': 1, 'dy': 0},
            {'dx': -1, 'dy': 0},
            {'dx': 0, 'dy': 1},
            {'dx': 0, 'dy': -1},
          ]) {
            int nx = head['col']! + dir['dx']!;
            int ny = head['row']! + dir['dy']!;
            int nnx = nx + dir['dx']!;
            int nny = ny + dir['dy']!;
            String nKey = '$nx-$ny';
            String nnKey = '$nnx-$nny';
            if (nx >= 0 && nx < widget.columns && ny >= 0 && ny < widget.rows &&
                !occupied.contains(nKey) &&
                nnx >= 0 && nnx < widget.columns && nny >= 0 && nny < widget.rows &&
                !occupied.contains(nnKey)) {
              freeMoves++;
            }
          }
          if (freeMoves > 0) {
            possiblePositions.add(segment);
          }
        }
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
        if (canPlace) {
          // Check head can move at least 2 blocks
          final head = segment[0];
          int freeMoves = 0;
          for (var dir in [
            {'dx': 1, 'dy': 0},
            {'dx': -1, 'dy': 0},
            {'dx': 0, 'dy': 1},
            {'dx': 0, 'dy': -1},
          ]) {
            int nx = head['col']! + dir['dx']!;
            int ny = head['row']! + dir['dy']!;
            int nnx = nx + dir['dx']!;
            int nny = ny + dir['dy']!;
            String nKey = '$nx-$ny';
            String nnKey = '$nnx-$nny';
            if (nx >= 0 && nx < widget.columns && ny >= 0 && ny < widget.rows &&
                !occupied.contains(nKey) &&
                nnx >= 0 && nnx < widget.columns && nny >= 0 && nny < widget.rows &&
                !occupied.contains(nnKey)) {
              freeMoves++;
            }
          }
          if (freeMoves > 0) {
            possiblePositions.add(segment);
          }
        }
      }
    }
    if (possiblePositions.isNotEmpty) {
      snakePositions = possiblePositions[random.nextInt(possiblePositions.length)];
      // Set the initial direction to be opposite of the second block
      if (snakePositions.length > 1) {
        final head = snakePositions[0];
        final second = snakePositions[1];
        final int headCol = head['col'] ?? 0;
        final int headRow = head['row'] ?? 0;
        final int secondCol = second['col'] ?? 0;
        final int secondRow = second['row'] ?? 0;
        if (headCol == secondCol) {
          if (headRow == secondRow - 1) {
            snakeDirection = SnakeDirection.up;
          } else if (headRow == secondRow + 1) {
            snakeDirection = SnakeDirection.down;
          }
        } else if (headRow == secondRow) {
          if (headCol == secondCol - 1) {
            snakeDirection = SnakeDirection.left;
          } else if (headCol == secondCol + 1) {
            snakeDirection = SnakeDirection.right;
          }
        }
      }
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
    if (_isAnimating || snakePositions.isEmpty) return;
    // Use next direction if set
    if (_nextDirection != null) {
      snakeDirection = _nextDirection!;
      _nextDirection = null;
    }
    final head = snakePositions.first;
    int newCol = head['col']!;
    int newRow = head['row']!;
    final int maxCol = widget.columns - 1;
    final int maxRow = widget.rows - 1;
    final bool canGoThroughBorders = (snakeSettings?['canGoThroughBorders'] ?? snakeSettings?['canGoTroughBorders'] ?? false) == true;

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

    if (canGoThroughBorders) {
      if (newCol < 0) newCol = maxCol;
      if (newCol > maxCol) newCol = 0;
      if (newRow < 0) newRow = maxRow;
      if (newRow > maxRow) newRow = 0;
    } else {
      if (newCol < 0 || newCol > maxCol || newRow < 0 || newRow > maxRow) {
        return;
      }
    }

    for (final segment in snakePositions) {
      if (segment['col'] == newCol && segment['row'] == newRow) {
        return;
      }
    }

    // Check for object at new head position and trigger action if found
    Map<String, dynamic>? foundFood;
    final foodMatches = foodItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (foodMatches.isNotEmpty) {
      foundFood = foodMatches.first;
      triggerObjectAction(foundFood['object']);
    }
    Map<String, dynamic>? foundDanger;
    final dangerMatches = dangerItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (dangerMatches.isNotEmpty) {
      foundDanger = dangerMatches.first;
      triggerObjectAction(foundDanger['object']);
    }
    Map<String, dynamic>? foundExit;
    final exitMatches = exitItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (exitMatches.isNotEmpty) {
      foundExit = exitMatches.first;
      triggerObjectAction(foundExit['object']);
    }

    // Animate all segments
    List<Offset> oldOffsets = snakePositions.map((s) => Offset(s['col']!.toDouble(), s['row']!.toDouble())).toList();
    List<Offset> newOffsets = [Offset(newCol.toDouble(), newRow.toDouble())];
    newOffsets.addAll(oldOffsets.take(oldOffsets.length - 1));
    _isAnimating = true;
    _oldHeadOffset = oldOffsets[0];
    _newHeadOffset = newOffsets[0];
    _segmentOldOffsets = oldOffsets;
    _segmentNewOffsets = newOffsets;
    _pendingNewHead = {'col': newCol, 'row': newRow};
    _moveController!.forward(from: 0);
  }

  List<Offset>? _segmentOldOffsets;
  List<Offset>? _segmentNewOffsets;

  void _startSnakeMoving() {
    // Only trigger the first move after countdown, then let animation drive the loop
    _snakeMoving();
  }

  @override
  void dispose() {
    _snakeTimer?.cancel();
    _moveController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      SnakeDirection? newDirection;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        newDirection = SnakeDirection.up;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        newDirection = SnakeDirection.down;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        newDirection = SnakeDirection.left;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        newDirection = SnakeDirection.right;
      }
      if (newDirection != null) {
        // Prevent reversing direction
        if ((snakeDirection == SnakeDirection.up && newDirection == SnakeDirection.down) ||
            (snakeDirection == SnakeDirection.down && newDirection == SnakeDirection.up) ||
            (snakeDirection == SnakeDirection.left && newDirection == SnakeDirection.right) ||
            (snakeDirection == SnakeDirection.right && newDirection == SnakeDirection.left)) {
          return;
        }
        _nextDirection = newDirection;
      }
    }
  }

  void _onCountdownFinished() {
    setState(() {
      _showCountdown = false;
    });
    _startSnakeMoving();
  }

  /// Triggers a custom action based on the object the snake interacts with.
  /// You can expand this to handle different object types or properties.
  void triggerObjectAction(Map<String, dynamic> object) {
    if (object['type'] == 'food') {
      // Example: Increase score, grow snake, play sound, etc.
      debugPrint('Food eaten!');
      // TODO: Implement food logic
    } else if (object['type'] == 'danger') {
      // Example: End game, reduce life, play sound, etc.
      debugPrint('Danger hit!');
      // TODO: Implement danger logic
    } else if (object['type'] == 'exit') {
      // Example: Complete level, show dialog, etc.
      debugPrint('Exit reached!');
      // TODO: Implement exit logic
    } else {
      debugPrint('Unknown object type: \\${object['type']}');
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

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: _onKey,
      child: Padding(
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
                  double left = col * cellSize + offset;
                  double top = row * cellSize + offset;
                  if (_isAnimating && _segmentOldOffsets != null && _segmentNewOffsets != null && idx < _segmentOldOffsets!.length) {
                    final old = _segmentOldOffsets![idx];
                    final newO = _segmentNewOffsets![idx];
                    final dx = old.dx + (newO.dx - old.dx) * (_moveAnimation?.value ?? 0);
                    final dy = old.dy + (newO.dy - old.dy) * (_moveAnimation?.value ?? 0);
                    left = dx * cellSize + offset;
                    top = dy * cellSize + offset;
                  }
                  return Positioned(
                    left: left,
                    top: top,
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
                          Builder(
                            builder: (context) {
                              // Eye positioning based on direction
                              switch (snakeDirection) {
                                case SnakeDirection.up:
                                  return Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: size * 0.10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: size * 0.18,
                                            height: size * 0.18,
                                            margin: EdgeInsets.only(right: size * 0.05),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Container(
                                            width: size * 0.18,
                                            height: size * 0.18,
                                            margin: EdgeInsets.only(left: size * 0.05),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                case SnakeDirection.down:
                                  return Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: size * 0.10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: size * 0.18,
                                            height: size * 0.18,
                                            margin: EdgeInsets.only(right: size * 0.05),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Container(
                                            width: size * 0.18,
                                            height: size * 0.18,
                                            margin: EdgeInsets.only(left: size * 0.05),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                case SnakeDirection.left:
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: size * 0.10),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: size * 0.18,
                                            height: size * 0.18,
                                            margin: EdgeInsets.only(bottom: size * 0.05),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Container(
                                            width: size * 0.18,
                                            height: size * 0.18,
                                            margin: EdgeInsets.only(top: size * 0.05),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                case SnakeDirection.right:
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: EdgeInsets.only(right: size * 0.10),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: size * 0.18,
                                            height: size * 0.18,
                                            margin: EdgeInsets.only(bottom: size * 0.05),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Container(
                                            width: size * 0.18,
                                            height: size * 0.18,
                                            margin: EdgeInsets.only(top: size * 0.05),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                              }
                            },
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
      ),
    );
  }
}
