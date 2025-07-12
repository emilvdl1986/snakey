import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:snakey/components/count_down.dart';
import 'package:snakey/components/button.dart';
import '../components/local_storage_service.dart';
import 'package:screenshot/screenshot.dart';
import 'share_helper.dart';

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
  final int currentLevel;
  final ValueChanged<int>? onLevelChanged;
  final bool isFinalStage;

  final Map<String, dynamic>? resumeState;

  // Add objectDefinitions prop
  final List<dynamic>? objectDefinitions;

  final ScreenshotController? screenshotController;

  const GameCanvas({
    Key? key,
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
    required this.currentLevel,
    this.onLevelChanged,
    this.isFinalStage = false,
    this.resumeState,
    this.objectDefinitions,
    this.screenshotController,
  }) : super(key: key);

  @override
  State<GameCanvas> createState() => GameCanvasState();
}

class GameCanvasState extends State<GameCanvas> with TickerProviderStateMixin {
  // Removed _pendingControllerCreation. Only ever one controller at a time.
  // Endless mode level tracking
  int endlessLevel = 1;

  // Queue for direction changes
  final List<SnakeDirection> _directionQueue = [];

  // Allow external swipe direction control
  void setDirectionFromSwipe(String direction) {
    debugPrint('setDirectionFromSwipe called with: ' + direction);
    if (_isGameOver || _isLevelComplete) return;
    SnakeDirection? newDirection;
    switch (direction) {
      case 'up':
        newDirection = SnakeDirection.up;
        break;
      case 'down':
        newDirection = SnakeDirection.down;
        break;
      case 'left':
        newDirection = SnakeDirection.left;
        break;
      case 'right':
        newDirection = SnakeDirection.right;
        break;
    }
    if (newDirection != null) {
      // Prevent reversing direction (relative to last in queue or current direction)
      SnakeDirection lastDirection = _directionQueue.isNotEmpty ? _directionQueue.last : snakeDirection;
      if ((lastDirection == SnakeDirection.up && newDirection == SnakeDirection.down) ||
          (lastDirection == SnakeDirection.down && newDirection == SnakeDirection.up) ||
          (lastDirection == SnakeDirection.left && newDirection == SnakeDirection.right) ||
          (lastDirection == SnakeDirection.right && newDirection == SnakeDirection.left)) {
        return;
      }
      // Only add if not already the last queued direction
      if (_directionQueue.isEmpty || _directionQueue.last != newDirection) {
        _directionQueue.add(newDirection);
      }
      // Give focus to the RawKeyboardListener so keyboard and swipe can both work
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    }
  }
  String? _resumeMode;
  // Ensures that if all keys are collected and no exit exists, exits are generated
  void _ensureExitIfKeysCollected() {
    if (keyItems.isEmpty && exitItems.isEmpty && objects != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && keyItems.isEmpty && exitItems.isEmpty && objects != null) {
          _generateRandomExitItems();
        }
      });
    }
  }
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
  bool _isDisposingController = false;
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
  bool _isLevelComplete = false;

  // Track what was gained in the last level
  int _lastPointsGained = 0;
  int _lastCoinsGained = 0;
  int _lastLivesGained = 0;
  // Track values at the start of each level for gain calculation
  int _startScore = 0;
  int _startCoins = 0;
  int _startLives = 0;

  @override
  void initState() {
    super.initState();
    // If objectDefinitions are provided (from resume), use them immediately
    if (widget.objectDefinitions != null) {
      objects = widget.objectDefinitions;
    }
    // Only restore from resumeState if not moving to next level or after game over
    // Use local state, not widget, for isLevelComplete and isGameOver
    if (widget.resumeState != null && !_isLevelComplete && !_isGameOver) {
      final dynamic stateRaw = widget.resumeState;
      final Map<String, dynamic> state = stateRaw is Map<String, dynamic>
          ? stateRaw
          : Map<String, dynamic>.from(stateRaw);
      // Use mode from resumeState if present
      if (state['gameMode'] != null) {
        _resumeMode = state['gameMode'];
      }
      // Restore basic game state
      score = state['score'] ?? 0;
      livesLeft = state['lives'] ?? 3;
      coins = state['coins'] ?? 0;
      snakeDirection = _snakeDirectionFromString(state['snakeDirection'] ?? 'right');
      _snakeSpeed = state['snakeSpeed'] ?? 8;
      // Restore endless level if present (do not increment on resume)
      if ((state['gameMode'] ?? widget.mode) == 'endless' && state['endlessLevel'] != null) {
        endlessLevel = state['endlessLevel'] is int ? state['endlessLevel'] : int.tryParse(state['endlessLevel'].toString()) ?? 1;
      }
      // Restore snake positions
      if (state['snakePositions'] != null) {
        snakePositions = List<Map<String, int>>.from(
          (state['snakePositions'] as List).map((e) => Map<String, int>.from(e)),
        );
      }
      // Restore items/objects
      foodItems = _restoreItemList(state['foodItems']);
      dangerItems = _restoreItemList(state['dangerItems']);
      exitItems = _restoreItemList(state['exitItems']);
      heartItems = _restoreItemList(state['heartItems']);
      coinItems = _restoreItemList(state['coinItems']);
      keyItems = _restoreItemList(state['keyItems']);
      // Restore snakeSettings if present
      if (state['snakeSettings'] != null) {
        snakeSettings = state['snakeSettings'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(state['snakeSettings'])
            : {};
      }
      // (No exit generation here; defer to _loadObjects after objects are loaded)
      _showCountdown = true;
      _setupAnimationController();
      isLoadingObjects = false;
      // Do NOT start snake movement here; let the countdown handle it
    } else {
      // On new game, reset, respawn, or next level, always start fresh
      // Only clear the saved game on reset, NOT when simply leaving the game screen
      // (Do not clear here)
      // Set random initial direction
      final directions = SnakeDirection.values;
      snakeDirection = directions[Random().nextInt(directions.length)];
      // For endless mode, reset endlessLevel to 1 on new game
      if ((widget.mode == 'endless') && (widget.resumeState == null)) {
        endlessLevel = 1;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final settings = widget.gridItemOptions?['snakeSettings'] ?? (widget.gridItemOptions?['snakeSettings'] ?? {});
        if (settings != null && settings['speed'] != null) {
          if (!mounted) return;
          setState(() {
            _snakeSpeed = settings['speed'];
          });
        } else if (widget.gridItemOptions?['speed'] != null) {
          if (!mounted) return;
          setState(() {
            _snakeSpeed = widget.gridItemOptions!['speed'];
          });
        }
        _setupAnimationController();
      });
      _loadObjects();
    }
  }

  // Helper to restore item lists from saved state
  List<Map<String, dynamic>> _restoreItemList(dynamic list) {
    if (list == null) return [];
    return List<Map<String, dynamic>>.from((list as List).map((e) => Map<String, dynamic>.from(e)));
  }

  // Helper to restore snake direction from string
  SnakeDirection _snakeDirectionFromString(String dir) {
    // Accepts both 'up' and 'SnakeDirection.up' and defaults to right
    if (dir == null) return SnakeDirection.right;
    final String value = dir.toString();
    if (value == 'up' || value == 'SnakeDirection.up') return SnakeDirection.up;
    if (value == 'down' || value == 'SnakeDirection.down') return SnakeDirection.down;
    if (value == 'left' || value == 'SnakeDirection.left') return SnakeDirection.left;
    if (value == 'right' || value == 'SnakeDirection.right') return SnakeDirection.right;
    // Try to match enum string
    try {
      return SnakeDirection.values.firstWhere((e) => e.toString() == value || e.name == value);
    } catch (_) {
      return SnakeDirection.right;
    }
  }

  void _setupAnimationController() {
    debugPrint('[DEBUG] _setupAnimationController: ENTER');
    // Always dispose the old controller synchronously before creating a new one
    if (_moveController != null) {
      try {
        debugPrint('[DEBUG] Disposing previous AnimationController...');
        _moveController!.dispose();
      } catch (e) {
        debugPrint('[DEBUG] Exception during AnimationController dispose: $e');
      }
      _moveController = null;
      _moveAnimation = null;
    }
    // Now create the new controller synchronously
    _createAnimationController();
    debugPrint('[DEBUG] _setupAnimationController: EXIT');
  }

  void _createAnimationController() {
    final int speed = _snakeSpeed.clamp(1, 20);
    final int durationMs = (400 / speed * 5).clamp(60, 1000).toInt();
    if (widget.mode == 'endless') {
      debugPrint('[DEBUG] Snake speed (endless): $_snakeSpeed | Level: $endlessLevel');
    }
    _moveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    _moveAnimation = CurvedAnimation(
      parent: _moveController!,
      curve: Curves.linear,
    );
    _moveAnimation!.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _moveController!.addStatusListener((status) {
      if (!mounted) return;
      if (_isGameOver) return;
      if (status == AnimationStatus.completed) {
        _isAnimating = false;
        _moveController!.reset();
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
    _saveGameStateToLocalStorage(); // Save after snake is loaded
  }

  Future<void> _loadObjects() async {
    String objectsFile = widget.mode == 'endless'
        ? 'assets/objects/endless_objects.json'
        : 'assets/objects/story_objects.json';
    try {
      final String objectsJson = await rootBundle.loadString(objectsFile);
      setState(() {
        objects = json.decode(objectsJson);
        isLoadingObjects = false;
      });
      // Always clear all item lists before generating new ones
      foodItems.clear();
      dangerItems.clear();
      exitItems.clear();
      heartItems.clear();
      coinItems.clear();
      keyItems.clear();
      _generateRandomFoodItems();
      _generateRandomDangerItems();
      _generateRandomHeartItems();
      _generateRandomCoinItems();
      _generateRandomKeyItems();

      // --- GUARANTEED EXIT GENERATION AFTER RESUME (objects loaded) ---
      if (keyItems.isEmpty && exitItems.isEmpty) {
        setState(() {
          _generateRandomExitItems();
        });
        _saveGameStateToLocalStorage();
      }

      _loadSnake(); // Load snake after all items are placed
      _saveGameStateToLocalStorage(); // Save after all objects are loaded
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
    _saveGameStateToLocalStorage(); // Save after food items change
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
    _saveGameStateToLocalStorage(); // Save after danger items change
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
    _saveGameStateToLocalStorage(); // Save after exit items change
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
    _saveGameStateToLocalStorage(); // Save after heart items change
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
    _saveGameStateToLocalStorage(); // Save after coin items change
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
    _saveGameStateToLocalStorage(); // Save after key items change
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
    if (_isGameOver || _isLevelComplete || _isAnimating || snakePositions.isEmpty) return;
    if (!mounted || _moveController == null) return;
    // Use next direction from queue if available
    if (_directionQueue.isNotEmpty) {
      snakeDirection = _directionQueue.removeAt(0);
      _directionQueue.clear(); // Clear any extra queued swipes after applying one
    } else if (_nextDirection != null) {
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

    // Ensure exit is generated after every move if all keys are collected
    _ensureExitIfKeysCollected();

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
    _saveGameStateToLocalStorage(); // Save after every move
  }

  List<Offset>? _segmentOldOffsets;
  List<Offset>? _segmentNewOffsets;

  void _startSnakeMoving() {
    // Only trigger the first move after countdown, then let animation drive the loop
    if (!mounted || _moveController == null) return;
    _snakeMoving();
  }

  @override
  void dispose() {
    _snakeTimer?.cancel();
    _moveController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateTopScores(int newScore) async {
    final scoresString = await LocalStorageService.getString('top_scores');
    List<int> scores = [];
    if (scoresString != null && scoresString.isNotEmpty) {
      scores = scoresString.split(',').map((e) => int.tryParse(e) ?? 0).toList();
    }
    scores.add(newScore);
    scores.sort((a, b) => b.compareTo(a)); // Descending
    if (scores.length > 10) scores = scores.sublist(0, 10);
    await LocalStorageService.setString('top_scores', scores.join(','));
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
                          _updateTopScores(score); // Update top scores on reset
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

  void gameNext({int? pointsGained, int? coinsGained, int? livesGained}) {
    _moveController?.stop();
    _snakeTimer?.cancel();
    _isAnimating = false;
    _isLevelComplete = true;

    // Save what was gained for display
    if (pointsGained != null) _lastPointsGained = pointsGained;
    if (coinsGained != null) _lastCoinsGained = coinsGained;
    if (livesGained != null) _lastLivesGained = livesGained;

    if (widget.mode == "story" && (widget.isFinalStage == true)) {
      // Calculate total score and update top scores before showing dialog
      final int totalScore = calculateTotalScore();
      _updateTopScores(totalScore);
      // Show Game Complete dialog
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
                          'Game Complete!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Congrats! You have completed the story games.',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Total Score: ' + totalScore.toString(),
                          style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 32),
                        Button(
                          label: "Back to Home",
                          onPressed: () async {
                            // Clear saved game when returning to home after completion
                            await SavedGameStorage.clear();
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
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
      return;
    }

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
                        'Complete!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.mode == 'endless')
                        Text('Level $endlessLevel', style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('Points x [38;5;214m$_lastPointsGained[0m', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Coins x $_lastCoinsGained', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Lives x $_lastLivesGained', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Total Score x ${calculateTotalScore()}', style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 32),
                      if (widget.mode == "story") ...[
                        Button(
                          label: "Continue",
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (widget.onLevelChanged != null) {
                              widget.onLevelChanged!(widget.currentLevel + 1);
                            }
                            setState(() {
                              _isLevelComplete = false;
                              _showCountdown = true;
                            });
                            // _resetGame will be called after parent updates props
                          },
                        ),
                      ] else ...[
                        Button(
                          label: "Continue",
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _isLevelComplete = false;
                              _showCountdown = true;
                            });
                            // Only increment endlessLevel and update app bar when actually continuing to next endless level
                            if (widget.mode == 'endless') {
                              endlessLevel += 1;
                              if (widget.onLevelChanged != null) {
                                widget.onLevelChanged!(endlessLevel);
                              }
                              _saveGameStateToLocalStorage();
                              _onLevelStart(); // Ensure speed and debug log update
                            }
                            _respawnSnake();
                          },
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) => Button(
                            label: 'Share with Friends',
                            onPressed: () async {
                              final controller = widget.screenshotController;
                              if (controller != null) {
                                await ShareHelper.shareCurrentScreen(context, controller);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Screenshot sharing not available.')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
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
      _isLevelComplete = false;
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
    // Always reload objects after respawn, even after resume
    _loadObjects();
    // Do not increment endlessLevel or call _onLevelStart here!
    // Do not reset score or livesLeft
    if (widget.onScoreChanged != null) {
      widget.onScoreChanged!(score);
    }
    if (widget.onLivesChanged != null) {
      widget.onLivesChanged!(livesLeft);
    }
    _saveGameStateToLocalStorage(); // Save after respawn
  }

  void _resetGame({
    bool keepScore = false,
    bool keepLives = false,
    bool keepCoins = false,
    bool nextLevel = false,
  }) {
    if (!mounted) return;
    setState(() {
      if (!keepScore) score = 0;
      if (!keepLives) livesLeft = 3;
      if (!keepCoins) coins = 0;
      foodItems.clear();
      dangerItems.clear();
      exitItems.clear();
      snakePositions.clear();
      heartItems.clear();
      coinItems.clear();
      keyItems.clear();
      _isGameOver = false;
      _isLevelComplete = false;
      _showCountdown = true;
      _pendingMoves = 0;
      _nextDirection = null;
      _isAnimating = false;
    });
    // Always reload objects after reset, even after resume
    _loadObjects();
    // Do not increment endlessLevel or call _onLevelStart here!
    if (widget.onScoreChanged != null) widget.onScoreChanged!(score);
    if (widget.onLivesChanged != null) widget.onLivesChanged!(livesLeft);
    if (widget.onCoinsChanged != null) widget.onCoinsChanged!(coins);
    _saveGameStateToLocalStorage(); // Save after reset
  }

  // Track values at the start of each level for gain calculation
  void _startLevelTracking() {
    _startScore = score;
    _startCoins = coins;
    _startLives = livesLeft;
  }

  // Call this after respawn/reset/next level
  void _onLevelStart() {
    // Only update endlessLevel from resumeState if resuming
    if (widget.mode == 'endless') {
      if (widget.resumeState != null) {
        final dynamic stateRaw = widget.resumeState;
        final Map<String, dynamic> state = stateRaw is Map<String, dynamic>
            ? stateRaw
            : Map<String, dynamic>.from(stateRaw);
        if (state['endlessLevel'] != null) {
          endlessLevel = state['endlessLevel'] is int ? state['endlessLevel'] : int.tryParse(state['endlessLevel'].toString()) ?? endlessLevel;
        }
        // Always update the app bar after restore
        if (widget.onLevelChanged != null) {
          widget.onLevelChanged!(endlessLevel);
        }
        _saveGameStateToLocalStorage();
      }
      // --- SPEED INCREASE LOGIC FOR ENDLESS MODE ---
      // On every endless level start, set speed to base + (endlessLevel - 1)
      // Only if not restoring from resumeState (i.e., on actual level up)
      if (widget.resumeState == null) {
        // Use the initial speed from gridItemOptions or fallback to 8
        int baseSpeed = 8;
        final settings = widget.gridItemOptions?['snakeSettings'] ?? (widget.gridItemOptions?['snakeSettings'] ?? {});
        if (settings != null && settings['speed'] != null) {
          baseSpeed = settings['speed'];
        } else if (widget.gridItemOptions?['speed'] != null) {
          baseSpeed = widget.gridItemOptions!['speed'];
        }
        _snakeSpeed = baseSpeed + (endlessLevel - 1);
        debugPrint('[DEBUG] (before controller) Snake speed (endless): $_snakeSpeed | Level: $endlessLevel');
        _setupAnimationController();
        // Print debug again after controller is set up (in case speed is changed by controller logic)
        debugPrint('[DEBUG] (after controller) Snake speed (endless): $_snakeSpeed | Level: $endlessLevel');
      }
    }
    _startLevelTracking();
  }

  // Call this when exit is reached
  void _onExitReached() {
    final int pointsGained = score - _startScore;
    final int coinsGained = coins - _startCoins;
    final int livesGained = livesLeft - _startLives;
    gameNext(pointsGained: pointsGained, coinsGained: coinsGained, livesGained: livesGained);
  }

  /// Calculates the total score based on the game mode.
  int calculateTotalScore() {
    if (widget.mode == 'endless') {
      return score * (coins > 0 ? coins : 1);
    } else if (widget.mode == 'story') {
      return score * (coins > 0 ? coins : 1) * (widget.currentLevel > 0 ? widget.currentLevel : 1);
    }
    return score;
  }

  // Restore triggerObjectAction method
  void triggerObjectAction(Map<String, dynamic> object, {int? col, int? row}) {

    String type = (object['type']?.toString() ?? '').replaceAll(RegExp(r'[\\/]'), '').trim().toLowerCase();

    // --- ATOMIC KEY COLLECTION AND EXIT GENERATION ---
    if (type == 'key') {
      debugPrint('Key collected!');
      bool removed = false;
      int beforeLen = keyItems.length;
      if (col != null && row != null) {
        keyItems.removeWhere((item) => item['col'] == col && item['row'] == row);
        removed = keyItems.length < beforeLen;
      }
      int pointsToAdd = 0;
      if (object['points'] is int || object['points'] is num) {
        pointsToAdd = (object['points'] as num).toInt();
      }
      // ATOMIC: Remove key, add points, generate exits, update UI in one setState
      if (!mounted) return;
      setState(() {
        score += pointsToAdd;
        // If all keys are collected and no exits, generate exits synchronously
        if (keyItems.isEmpty && exitItems.isEmpty && objects != null) {
          _generateRandomExitItems();
        }
        // Respawn key if needed
        if (keyItems.isEmpty && (widget.gridItemOptions?['keyTrigger'] == true)) {
          _generateRandomKeyItems();
        }
      });
      if (widget.onScoreChanged != null) {
        widget.onScoreChanged!(score);
      }
      _saveGameStateToLocalStorage();
      // Remove all post-frame callbacks for exit generation after key collection (no longer needed)
      return;
    }
    // --- END ATOMIC KEY COLLECTION AND EXIT GENERATION ---

    if (type == 'food') {
      debugPrint('Food eaten! \\${object['action']}');
      bool removed = false;
      if (object['action'] == 'grow') {
        // Add points from food
        int points = 0;
        if (object['points'] is int) {
          points = object['points'];
        }
        if (!mounted) return;
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
    } else if (type == 'danger') {
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
    } else if (type == 'heart') {
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
    } else if (type == 'coin') {
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
    } else if (type == 'exit') {
      debugPrint('Exit reached!');
      _onExitReached();
    } else {
      debugPrint('Unknown object type: \\${object['type']}');
    }
    _saveGameStateToLocalStorage(); // Save after every object action
  }

  // Restore _onKey method
  void _onKey(RawKeyEvent event) {
    if (_isGameOver || _isLevelComplete) return;
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

  // Restore _onCountdownFinished method
  void _onCountdownFinished() {
    setState(() {
      _showCountdown = false;
      // If the user swiped during countdown, use that direction
      if (_nextDirection != null) {
        snakeDirection = _nextDirection!;
        _nextDirection = null;
      }
    });
    _startSnakeMoving();
  }

  /// Returns the highest score from a list of scores, or the current score if no list is provided.
  int calculateTopScore([List<int>? previousScores]) {
    if (previousScores == null || previousScores.isEmpty) {
      return score;
    }
    return [score, ...previousScores].reduce((a, b) => a > b ? a : b);
  }

  /// Save the current game state to local storage for resume functionality.
  Future<void> _saveGameStateToLocalStorage() async {
    // Always use the mode from resumeState if present, else widget.mode
    final String modeToSave = _resumeMode ?? widget.mode;
    final Map<String, dynamic> gameState = {
      'gameMode': modeToSave,
      'score': score,
      'level': modeToSave == 'story' ? widget.currentLevel : null,
      'endlessLevel': modeToSave == 'endless' ? endlessLevel : null,
      'coins': coins,
      'lives': livesLeft,
      'snakePositions': List<Map<String, int>>.from(snakePositions),
      'snakeDirection': snakeDirection.toString(),
      'snakeLength': snakePositions.length,
      'foodItems': foodItems.map((item) => Map<String, dynamic>.from(item)).toList(),
      'dangerItems': dangerItems.map((item) => Map<String, dynamic>.from(item)).toList(),
      'exitItems': exitItems.map((item) => Map<String, dynamic>.from(item)).toList(),
      'heartItems': heartItems.map((item) => Map<String, dynamic>.from(item)).toList(),
      'coinItems': coinItems.map((item) => Map<String, dynamic>.from(item)).toList(),
      'keyItems': keyItems.map((item) => Map<String, dynamic>.from(item)).toList(),
      // Add any other relevant state here if needed
    };
    await SavedGameStorage.save(gameState);
  }

  @override
  Widget build(BuildContext context) {
    // As a last resort, ensure exit is generated if all keys are collected (guarded to avoid infinite loop)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureExitIfKeysCollected();
    });
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
                                            margin: EdgeInsets.only(top: size *  0.05),
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

// Add a static helper for saved_game local storage
class SavedGameStorage {
  static const String key = 'saved_game';

  static Future<void> save(Map<String, dynamic> gameState) async {
    await LocalStorageService.setString(key, json.encode(gameState));
  }

  static Future<Map<String, dynamic>?> load() async {
    final str = await LocalStorageService.getString(key);
    if (str == null) return null;
    return json.decode(str) as Map<String, dynamic>;
  }

  static Future<void> clear() async {
    await LocalStorageService.remove(key);
  }
}
