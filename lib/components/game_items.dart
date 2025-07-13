import 'dart:math';
import 'package:flutter/material.dart';

class GameItemsManager {
  void generateRandomDangerItems({List<List<int>>? occupied}) {
    if (objects == null || gridItemOptions == null) return;
    final int dangerLimit = gridItemOptions?['dangerItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
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
        col = random.nextInt(columns);
        row = random.nextInt(rows);
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
  }

  void generateRandomExitItems({List<List<int>>? occupied}) {
    if (objects == null || gridItemOptions == null) return;
    final int exitLimit = gridItemOptions?['exitItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
    if (occupied != null) {
      for (var pos in occupied) {
        occupiedPositions.add({'col': pos[0], 'row': pos[1]});
      }
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
        col = random.nextInt(columns);
        row = random.nextInt(rows);
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
  }

  void generateRandomHeartItems({List<List<int>>? occupied}) {
    if (objects == null || gridItemOptions == null) return;
    final int heartLimit = gridItemOptions?['heartItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
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
        col = random.nextInt(columns);
        row = random.nextInt(rows);
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
      if (!found) break;
    }
  }

  void generateRandomCoinItems({List<List<int>>? occupied}) {
    if (objects == null || gridItemOptions == null) return;
    final int coinLimit = gridItemOptions?['coinItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
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
        col = random.nextInt(columns);
        row = random.nextInt(rows);
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
      if (!found) break;
    }
  }

  void generateRandomKeyItems({List<List<int>>? occupied}) {
    if (objects == null || gridItemOptions == null) return;
    final int keyLimit = gridItemOptions?['keyItemsLimit'] ?? 1;
    final List<Map<String, int>> occupiedPositions = [];
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
        col = random.nextInt(columns);
        row = random.nextInt(rows);
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
      if (!found) break;
    }
  }
  // Game item lists
  List<Map<String, dynamic>> foodItems = [];
  List<Map<String, dynamic>> dangerItems = [];
  List<Map<String, dynamic>> exitItems = [];
  List<Map<String, dynamic>> heartItems = [];
  List<Map<String, dynamic>> coinItems = [];
  List<Map<String, dynamic>> keyItems = [];

  // Store objects and grid options for item generation
  List<dynamic>? objects;
  Map<String, dynamic>? gridItemOptions;
  int columns = 0;
  int rows = 0;

  void configure({
    required List<dynamic>? objects,
    required Map<String, dynamic>? gridItemOptions,
    required int columns,
    required int rows,
  }) {
    this.objects = objects;
    this.gridItemOptions = gridItemOptions;
    this.columns = columns;
    this.rows = rows;
  }

  void clearAll() {
    foodItems.clear();
    dangerItems.clear();
    exitItems.clear();
    heartItems.clear();
    coinItems.clear();
    keyItems.clear();
  }

  void generateRandomFoodItems({List<List<int>>? occupied}) {
    if (objects == null || gridItemOptions == null) return;
    final int foodLimit = gridItemOptions?['foodLimit'] ?? 1;
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
    int count = foodLimit > 0 ? random.nextInt(foodLimit) + 1 : 1;
    for (int i = 0; i < count; i++) {
      int col, row;
      String posKey;
      bool found = false;
      for (int tries = 0; tries < 100; tries++) {
        col = random.nextInt(columns);
        row = random.nextInt(rows);
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
      if (!found) break;
    }
  }

  // Similar methods for danger, exit, heart, coin, key can be added here...
}
