import 'package:flutter/material.dart';

class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showScore;
  final bool showLives;
  final bool showCoins;
  final bool showLevel;
  final int score;
  final int livesLeft;

  const GameAppBar({
    super.key,
    this.title = 'Game',
    this.showScore = false,
    this.showLives = false,
    this.showCoins = false,
    this.showLevel = false,
    this.score = 0,
    this.livesLeft = 3,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          if (showScore)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.score, color: Colors.white),
                  const SizedBox(width: 4),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                     
                      Text(
                        score.toString(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (showLives)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white),
                  const SizedBox(width: 4),
                  const Text('X', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 2),
                  Text(
                    livesLeft.toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          if (showCoins)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.monetization_on, color: Colors.white),
            ),
          if (showLevel)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.bar_chart, color: Colors.white),
            ),
        ],
      ),
      centerTitle: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
