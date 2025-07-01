import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/top_scores.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeScreen(),
      navigatorObservers: [routeObserver],
      routes: {
        '/top-scores': (context) => const TopScores(),
      },
    );
  }
}
