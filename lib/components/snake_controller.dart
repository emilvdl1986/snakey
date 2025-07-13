import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'game_items.dart';

enum SnakeDirection { up, down, left, right }

class SnakeController {
  // Game state fields
  int endlessLevel = 1;
  List<Map<String, int>> snakePositions = [];
  SnakeDirection snakeDirection = SnakeDirection.right;
  SnakeDirection? _nextDirection;
  int _snakeSpeed = 8;
  int score = 0;
  int livesLeft = 3;
  int coins = 0;
  bool _isGameOver = false;
  bool _isLevelComplete = false;
  // Add more fields as needed

  // Animation
  AnimationController? _moveController;
  Animation<double>? _moveAnimation;
  bool _isAnimating = false;
  int _pendingMoves = 0;
  Timer? _snakeTimer;

  final TickerProvider tickerProvider;
  final GameItemsManager itemsManager;
  final ValueChanged<int>? onScoreChanged;
  final ValueChanged<int>? onLivesChanged;
  final ValueChanged<int>? onCoinsChanged;
  final ValueChanged<int>? onLevelChanged;

  SnakeController({
    required this.tickerProvider,
    required this.itemsManager,
    this.onScoreChanged,
    this.onLivesChanged,
    this.onCoinsChanged,
    this.onLevelChanged,
  });

  void dispose() {
    _snakeTimer?.cancel();
    _moveController?.dispose();
  }

  void onKey(RawKeyEvent event) {
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

  // Add more methods for snake movement, respawn, etc.
}
