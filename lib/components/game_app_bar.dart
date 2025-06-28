import 'package:flutter/material.dart';

class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showScore;
  final bool showLives;
  final bool showCoins;
  final bool showLevel;

  const GameAppBar({
    super.key,
    this.title = 'Game',
    this.showScore = false,
    this.showLives = false,
    this.showCoins = false,
    this.showLevel = false,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.score, color: Colors.white),
            ),
          if (showLives)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.favorite, color: Colors.white),
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
