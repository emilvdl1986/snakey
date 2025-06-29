import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:snakey/components/count_down.dart';
import 'package:snakey/components/button.dart';

enum SnakeDirection { up, down, left, right }

class GameCanvas extends StatefulWidget {
  final int columns;
  final int rows;
  final double padding;
  final String? backgroundColor;
  final bool backgroundImage;
  final Map<String, dynamic>? gridItemOptions;
  final String mode;
  final ValueChanged<int>? onScoreChanged;
  final ValueChanged<int>? onLivesChanged;
  final ValueChanged<int>? onCoinsChanged;

  const GameCanvas({
    super.key,
    required this.columns,
    required this.rows,
    this.padding = 16.0,
    this.backgroundColor,
    this.backgroundImage = false,
    this.gridItemOptions,
    required this.mode,
    this.onScoreChanged,
    this.onLivesChanged,
    this.onCoinsChanged,
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
  List<Map<String, dynamic>> heartItems = [];
  List<Map<String, dynamic>> coinItems = [];
  List<Map<String, dynamic>> keyItems = [];

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

  int _snakeSpeed = 8; // default // max 8
  int score = 0;
  int livesLeft = 3;
  int coins = 0;

  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    // Set random initial direction
    final directions = SnakeDirection.values;
    snakeDirection = directions[Random().nextInt(directions.length)];
    // Always load speed from snakeSettings in JSON (unless overridden elsewhere)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = widget.gridItemOptions?['snakeSettings'] ?? (widget.gridItemOptions?['snakeSettings'] ?? {});
      if (settings != null && settings['speed'] != null) {
        setState(() {
          _snakeSpeed = settings['speed'];
        });
      } else if (widget.gridItemOptions?['speed'] != null) {
        setState(() {
          _snakeSpeed = widget.gridItemOptions!['speed'];
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
      if (_isGameOver) return;
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
    for (var heart in heartItems) {
      occupied.add('${heart['col']}-${heart['row']}');
    }
    for (var coin in coinItems) {
      occupied.add('${coin['col']}-${coin['row']}');
    }
    for (var key in keyItems) {
      occupied.add('${key['col']}-${key['row']}');
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
      _generateRandomHeartItems();
      _generateRandomCoinItems();
      _generateRandomKeyItems();
      // _generateRandomExitItems(); // Do not spawn exits at the beginning
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
    // Add all danger, exit, and snake positions to occupied
    for (var danger in dangerItems) {
      occupiedPositions.add({'col': danger['col'], 'row': danger['row']});
    }
    for (var exit in exitItems) {
      occupiedPositions.add({'col': exit['col'], 'row': exit['row']});
    }
    for (var segment in snakePositions) {
      occupiedPositions.add({'col': segment['col']!, 'row': segment['row']!});
    }
    // Add any custom occupied positions
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
    }
    // Also add already placed food (if respawning multiple at once)
    for (var food in foodItems) {
      occupiedPositions.add({'col': food['col'], 'row': food['row']});
    }
    final List<dynamic> foodObjects = objects!.where((obj) => obj['type'] == 'food').toList();
    final Random random = Random();
    final Set<String> usedPositions = {};
    foodItems.clear();
    // Ensure at least 1 food item is generated
    int count = foodLimit > 0 ? random.nextInt(foodLimit) + 1 : 1;
    int attempts = 0;
    for (int i = 0; i < count; i++) {
      int col, row;
      String posKey;
      bool found = false;
      // Try up to 100 times to find a free spot
      for (int tries = 0; tries < 100; tries++) {
        col = random.nextInt(widget.columns);
        row = random.nextInt(widget.rows);
        posKey = '$col-$row';
        if (!usedPositions.contains(posKey) &&
            !occupiedPositions.any((o) => o['col'] == col && o['row'] == row)) {
          usedPositions.add(posKey);
          final foodObj = foodObjects[random.nextInt(foodObjects.length)];
          foodItems.add({
            'object': foodObj,
            'col': col,
            'row': row,
          });
          found = true;
          break;
        }
      }
      if (!found) {
        // No free spot found, break early
        break;
      }
    }
    setState(() {});
  }

  /// Generates random danger items and places them on unoccupied grid positions.
  /// Returns a list of maps with danger object and its position.
  void _generateRandomDangerItems({List<List<int>>? occupied}) {
    if (objects == null || widget.gridItemOptions == null) return;
    final int dangerLimit = widget.gridItemOptions?['dangerItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    // Add positions from argument
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
    // Add positions from argument
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

  /// Generates random heart items and places them on unoccupied grid positions.
  /// Returns a list of maps with heart object and its position.
  void _generateRandomHeartItems({List<List<int>>? occupied}) {
    if (objects == null || widget.gridItemOptions == null) return;
    final int heartLimit = widget.gridItemOptions?['heartItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    // Add all food, danger, exit, coin, and snake positions to occupied
    for (var food in foodItems) {
      occupiedPositions.add({'col': food['col'], 'row': food['row']});
    }
    for (var danger in dangerItems) {
      occupiedPositions.add({'col': danger['col'], 'row': danger['row']});
    }
    for (var exit in exitItems) {
      occupiedPositions.add({'col': exit['col'], 'row': exit['row']});
    }
    for (var coin in coinItems) {
      occupiedPositions.add({'col': coin['col'], 'row': coin['row']});
    }
    for (var segment in snakePositions) {
      occupiedPositions.add({'col': segment['col']!, 'row': segment['row']!});
    }
    // Add any custom occupied positions
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
    }
    final List<dynamic> heartObjects = objects!.where((obj) => obj['type'] == 'heart').toList();
    final Random random = Random();
    final Set<String> usedPositions = {};
    heartItems.clear();
    int count = heartLimit > 0 ? random.nextInt(heartLimit) + 1 : 1;
    for (int i = 0; i < count; i++) {
      int col, row;
      String posKey;
      bool found = false;
      for (int tries = 0; tries < 100; tries++) {
        col = random.nextInt(widget.columns);
        row = random.nextInt(widget.rows);
        posKey = '$col-$row';
        if (!usedPositions.contains(posKey) &&
            !occupiedPositions.any((o) => o['col'] == col && o['row'] == row)) {
          usedPositions.add(posKey);
          final heartObj = heartObjects[random.nextInt(heartObjects.length)];
          heartItems.add({
            'object': heartObj,
            'col': col,
            'row': row,
          });
          found = true;
          break;
        }
      }
      if (!found) {
        break;
      }
    }
    setState(() {});
  }

  /// Generates random coin items and places them on unoccupied grid positions.
  /// Returns a list of maps with coin object and its position.
  void _generateRandomCoinItems({List<List<int>>? occupied}) {
    if (objects == null || widget.gridItemOptions == null) return;
    final int coinLimit = widget.gridItemOptions?['coinItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    // Add all food, danger, exit, heart, and snake positions to occupied
    for (var food in foodItems) {
      occupiedPositions.add({'col': food['col'], 'row': food['row']});
    }
    for (var danger in dangerItems) {
      occupiedPositions.add({'col': danger['col'], 'row': danger['row']});
    }
    for (var exit in exitItems) {
      occupiedPositions.add({'col': exit['col'], 'row': exit['row']});
    }
    for (var heart in heartItems) {
      occupiedPositions.add({'col': heart['col'], 'row': heart['row']});
    }
    for (var segment in snakePositions) {
      occupiedPositions.add({'col': segment['col']!, 'row': segment['row']!});
    }
    // Add any custom occupied positions
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
    }
    final List<dynamic> coinObjects = objects!.where((obj) => obj['type'] == 'coin').toList();
    final Random random = Random();
    final Set<String> usedPositions = {};
    coinItems.clear();
    int count = coinLimit > 0 ? random.nextInt(coinLimit) + 1 : 1;
    for (int i = 0; i < count; i++) {
      int col, row;
      String posKey;
      bool found = false;
      for (int tries = 0; tries < 100; tries++) {
        col = random.nextInt(widget.columns);
        row = random.nextInt(widget.rows);
        posKey = '$col-$row';
        if (!usedPositions.contains(posKey) &&
            !occupiedPositions.any((o) => o['col'] == col && o['row'] == row)) {
          usedPositions.add(posKey);
          final coinObj = coinObjects[random.nextInt(coinObjects.length)];
          coinItems.add({
            'object': coinObj,
            'col': col,
            'row': row,
          });
          found = true;
          break;
        }
      }
      if (!found) {
        break;
      }
    }
    setState(() {});
  }

  /// Generates random key items and places them on unoccupied grid positions.
  /// Returns a list of maps with key object and its position.
  void _generateRandomKeyItems({List<List<int>>? occupied}) {
    if (objects == null || widget.gridItemOptions == null) return;
    final int keyLimit = widget.gridItemOptions?['keyItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    // Add all food, danger, heart, coin, and snake positions to occupied
    for (var food in foodItems) {
      occupiedPositions.add({'col': food['col'], 'row': food['row']});
    }
    for (var danger in dangerItems) {
      occupiedPositions.add({'col': danger['col'], 'row': danger['row']});
    }
    for (var heart in heartItems) {
      occupiedPositions.add({'col': heart['col'], 'row': heart['row']});
    }
    for (var coin in coinItems) {
      occupiedPositions.add({'col': coin['col'], 'row': coin['row']});
    }
    for (var segment in snakePositions) {
      occupiedPositions.add({'col': segment['col']!, 'row': segment['row']!});
    }
    // Add any custom occupied positions
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
    }
    final List<dynamic> keyObjects = objects!.where((obj) => obj['type'] == 'key').toList();
    final Random random = Random();
    final Set<String> usedPositions = {};
    keyItems.clear();
    int count = keyLimit > 0 ? random.nextInt(keyLimit) + 1 : 1;
    for (int i = 0; i < count; i++) {
      int col, row;
      String posKey;
      bool found = false;
      for (int tries = 0; tries < 100; tries++) {
        col = random.nextInt(widget.columns);
        row = random.nextInt(widget.rows);
        posKey = '$col-$row';
        if (!usedPositions.contains(posKey) &&
            !occupiedPositions.any((o) => o['col'] == col && o['row'] == row)) {
          usedPositions.add(posKey);
          final keyObj = keyObjects[random.nextInt(keyObjects.length)];
          keyItems.add({
            'object': keyObj,
            'col': col,
            'row': row,
          });
          found = true;
          break;
        }
      }
      if (!found) {
        break;
      }
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
    if (_isGameOver || _isAnimating || snakePositions.isEmpty) return;
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
        gameOver();
        return;
      }
    }

    for (final segment in snakePositions) {
      if (segment['col'] == newCol && segment['row'] == newRow) {
        gameOver();
        return;
      }
    }

    // Check for object at new head position and trigger action if found
    Map<String, dynamic>? foundFood;
    final foodMatches = foodItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (foodMatches.isNotEmpty) {
      foundFood = foodMatches.first;
      triggerObjectAction(foundFood['object'], col: newCol, row: newRow);
    }
    Map<String, dynamic>? foundDanger;
    final dangerMatches = dangerItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (dangerMatches.isNotEmpty) {
      foundDanger = dangerMatches.first;
      triggerObjectAction(foundDanger['object'], col: newCol, row: newRow);
    }
    Map<String, dynamic>? foundExit;
    final exitMatches = exitItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (exitMatches.isNotEmpty) {
      foundExit = exitMatches.first;
      triggerObjectAction(foundExit['object'], col: newCol, row: newRow);
    }
    // Check for heart at new head position
    final heartMatches = heartItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (heartMatches.isNotEmpty) {
      final foundHeart = heartMatches.first;
      triggerObjectAction(foundHeart['object'], col: newCol, row: newRow);
    }
    // Check for coin at new head position
    final coinMatches = coinItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (coinMatches.isNotEmpty) {
      final foundCoin = coinMatches.first;
      triggerObjectAction(foundCoin['object'], col: newCol, row: newRow);
    }
    // Check for key at new head position
    final keyMatches = keyItems.where((item) => item['col'] == newCol && item['row'] == newRow).toList();
    if (keyMatches.isNotEmpty) {
      final foundKey = keyMatches.first;
      triggerObjectAction(foundKey['object'], col: newCol, row: newRow);
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

  void gameOver() {
    _isGameOver = true;
    livesLeft = (livesLeft > 0) ? livesLeft - 1 : 0;
    if (widget.onLivesChanged != null) {
      widget.onLivesChanged!(livesLeft);
    }
    _moveController?.stop();
    _snakeTimer?.cancel();
    _isAnimating = false;
    _pendingMoves = 0;
    _nextDirection = null;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Game Over',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your score: $score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lives left: $livesLeft',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (livesLeft > 0)
                        Button(
                          label: 'Respawn',
                          onPressed: () {
                            Navigator.of(context).pop();
                            _respawnSnake();
                          },
                        ),
                      if (livesLeft > 0) const SizedBox(height: 12),
                      if (livesLeft == 0 && coins >= 3)
                        Button(
                          label: 'Respawn (use 3 coins)',
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              coins -= 3;
                            });
                            if (widget.onCoinsChanged != null) {
                              widget.onCoinsChanged!(coins);
                            }
                            _respawnSnake();
                          },
                          color: Colors.amber,
                        ),
                      if (livesLeft == 0 && coins >= 3) const SizedBox(height: 12),
                      Button(
                        label: 'Reset',
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _respawnSnake() {
    setState(() {
      _isGameOver = false;
      foodItems.clear();
      dangerItems.clear();
      exitItems.clear();
      snakePositions.clear();
      heartItems.clear();
      coinItems.clear();
      keyItems.clear();
      _showCountdown = true;
      _pendingMoves = 0;
      _nextDirection = null;
      _isAnimating = false;
    });
    _loadObjects();
    // Do not reset score or livesLeft
    if (widget.onScoreChanged != null) {
      widget.onScoreChanged!(score);
    }
    if (widget.onLivesChanged != null) {
      widget.onLivesChanged!(livesLeft);
    }
  }

  void _resetGame() {
    setState(() {
      _isGameOver = false;
      score = 0;
      livesLeft = 3;
      foodItems.clear();
      dangerItems.clear();
      exitItems.clear();
      snakePositions.clear();
      heartItems.clear();
      coinItems.clear();
      keyItems.clear();
      _showCountdown = true;
      _pendingMoves = 0;
      _nextDirection = null;
      _isAnimating = false;
    });
    if (widget.onScoreChanged != null) {
      widget.onScoreChanged!(score);
    }
    if (widget.onLivesChanged != null) {
      widget.onLivesChanged!(livesLeft);
    }
    _loadObjects();
  }

  void _onKey(RawKeyEvent event) {
    if (_isGameOver) return;
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
  void triggerObjectAction(Map<String, dynamic> object, {int? col, int? row}) {
    if (object['type'] == 'food') {
      debugPrint('Food eaten! \\${object['action']}');
      bool removed = false;
      if (object['action'] == 'grow') {
        // Add points from food
        int points = 0;
        if (object['points'] is int) {
          points = object['points'];
        }
        setState(() {
          score += points;
        });
        if (widget.onScoreChanged != null) {
          widget.onScoreChanged!(score);
        }
        // Remove the food item at the new head position
        if (col != null && row != null) {
          final beforeLen = foodItems.length;
          foodItems.removeWhere((item) => item['col'] == col && item['row'] == row);
          removed = foodItems.length < beforeLen;
        }
        if (removed) setState(() {});
        // If no food left and foodTrigger is true, generate new food
        if (foodItems.isEmpty && (widget.gridItemOptions?['foodTrigger'] == true)) {
          _generateRandomFoodItems();
        }
        // Grow the snake by adding new blocks at the tail
        int growLength = 1;
        if (object['growLength'] is int) {
          growLength = object['growLength'];
        }
        for (int i = 0; i < growLength; i++) {
          if (snakePositions.isNotEmpty) {
            final tail = snakePositions.last;
            final beforeTail = snakePositions.length > 1 ? snakePositions[snakePositions.length - 2] : tail;
            int dx = tail['col']! - beforeTail['col']!;
            int dy = tail['row']! - beforeTail['row']!;
            // Add new segment in the same direction as the tail
            final newTail = {
              'col': tail['col']! + dx,
              'row': tail['row']! + dy,
            };
            // Clamp to grid
            newTail['col'] = newTail['col']!.clamp(0, widget.columns - 1);
            newTail['row'] = newTail['row']!.clamp(0, widget.rows - 1);
            snakePositions.add(newTail);
          }
        }
        setState(() {});
      }
      // TODO: Implement other food logic
    } else if (object['type'] == 'danger') {
      debugPrint('Danger hit!');
      if (object['action'] == 'shrink') {
        int shrinkLength = 1;
        if (object['shrinkLength'] is int) {
          shrinkLength = object['shrinkLength'];
        }
        // Subtract points from danger
        int points = 0;
        if (object['points'] is int) {
          points = object['points'];
        }
        setState(() {
          score += points; // points is negative in JSON for danger
        });
        if (widget.onScoreChanged != null) {
          widget.onScoreChanged!(score);
        }
        // If snake is only 1 block, game over
        if (snakePositions.length <= 1) {
          gameOver();
          return;
        }
        // Remove blocks from the tail, but keep at least 1 block
        for (int i = 0; i < shrinkLength; i++) {
          if (snakePositions.length > 1) {
            snakePositions.removeLast();
          } else {
            break;
          }
        }
        setState(() {});
      }
      // TODO: Implement other danger logic
    } else if (object['type'] == 'heart') {
      debugPrint('Heart collected!');
      bool removed = false;
      // Remove the heart item at the new head position
      if (col != null && row != null) {
        final beforeLen = heartItems.length;
        heartItems.removeWhere((item) => item['col'] == col && item['row'] == row);
        removed = heartItems.length < beforeLen;
      }
      if (removed) setState(() {});
      // Increase lives
      setState(() {
        livesLeft += 1;
      });
      // Award points if present
      if (object['points'] is int || object['points'] is num) {
        setState(() {
          score += (object['points'] as num).toInt();
        });
        if (widget.onScoreChanged != null) {
          widget.onScoreChanged!(score);
        }
      }
      if (widget.onLivesChanged != null) {
        widget.onLivesChanged!(livesLeft);
      }
      // Respawn heart if needed
      if (heartItems.isEmpty && (widget.gridItemOptions?['heartTrigger'] == true)) {
        _generateRandomHeartItems();
      }
    } else if (object['type'] == 'key') {
      debugPrint('Key collected!');
      bool removed = false;
      // Remove the key item at the new head position
      if (col != null && row != null) {
        final beforeLen = keyItems.length;
        keyItems.removeWhere((item) => item['col'] == col && item['row'] == row);
        removed = keyItems.length < beforeLen;
      }
      if (removed) setState(() {});
      // Award points if present
      if (object['points'] is int || object['points'] is num) {
        setState(() {
          score += (object['points'] as num).toInt();
        });
        if (widget.onScoreChanged != null) {
          widget.onScoreChanged!(score);
        }
      }
      // If all keys collected, spawn exits
      if (keyItems.isEmpty) {
        _generateRandomExitItems();
      }
      // Respawn key if needed
      if (keyItems.isEmpty && (widget.gridItemOptions?['keyTrigger'] == true)) {
        _generateRandomKeyItems();
      }
    } else if (object['type'] == 'coin') {
      debugPrint('Coin collected!');
      bool removed = false;
      // Remove the coin item at the new head position
      if (col != null && row != null) {
        final beforeLen = coinItems.length;
        coinItems.removeWhere((item) => item['col'] == col && item['row'] == row);
        removed = coinItems.length < beforeLen;
      }
      if (removed) setState(() {});
      // Increase coins
      setState(() {
        coins += 1;
      });
      if (widget.onCoinsChanged != null) {
        widget.onCoinsChanged!(coins);
      }
      // Respawn coin if needed
      if (coinItems.isEmpty && (widget.gridItemOptions?['coinTrigger'] == true)) {
        _generateRandomCoinItems();
      }
    } else if (object['type'] == 'exit') {
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
              // Draw heart items using their image
              if (heartItems.isNotEmpty)
                ...heartItems.map((heart) {
                  final int col = heart['col'];
                  final int row = heart['row'];
                  final String? imagePath = heart['object']['image'];
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
              // Draw coin items using their image
              if (coinItems.isNotEmpty)
                ...coinItems.map((coin) {
                  final int col = coin['col'];
                  final int row = coin['row'];
                  final String? imagePath = coin['object']['image'];
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
              // Draw key items using their image
              if (keyItems.isNotEmpty)
                ...keyItems.map((key) {
                  final int col = key['col'];
                  final int row = key['row'];
                  final String? imagePath = key['object']['image'];
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
