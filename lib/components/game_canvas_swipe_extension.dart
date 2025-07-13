import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'game_canvas.dart';

extension GameCanvasSwipe on GameCanvasState {
  // Allows setting the direction from a swipe gesture
  void setDirectionFromSwipe(dynamic direction) {
    // Accepts either a SnakeDirection or a String
    final SnakeDirection? dir = direction is SnakeDirection
        ? direction
        : _snakeDirectionFromString(direction);
    if (dir == null) return;
    if (isGameOver || isLevelComplete) return;
    // Prevent reversing direction
    if ((snakeDirection == SnakeDirection.up && dir == SnakeDirection.down) ||
        (snakeDirection == SnakeDirection.down && dir == SnakeDirection.up) ||
        (snakeDirection == SnakeDirection.left && dir == SnakeDirection.right) ||
        (snakeDirection == SnakeDirection.right && dir == SnakeDirection.left)) {
      return;
    }
    // Only queue if not already moving in that direction
    if (directionQueue.isEmpty || directionQueue.last != dir) {
      directionQueue.add(dir);
    }
  }

  // Helper to convert string to SnakeDirection
  SnakeDirection? _snakeDirectionFromString(String? dir) {
    if (dir == null) return null;
    switch (dir.toLowerCase()) {
      case 'up':
        return SnakeDirection.up;
      case 'down':
        return SnakeDirection.down;
      case 'left':
        return SnakeDirection.left;
      case 'right':
        return SnakeDirection.right;
      default:
        return null;
    }
  }
}
