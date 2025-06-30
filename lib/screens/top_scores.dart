import 'package:flutter/material.dart';
import '../components/local_storage_service.dart';

class TopScores extends StatefulWidget {
  const TopScores({super.key});

  @override
  State<TopScores> createState() => _TopScoresState();
}

class _TopScoresState extends State<TopScores> {
  List<int> scores = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final scoresString = await LocalStorageService.getString('top_scores');
    if (scoresString != null && scoresString.isNotEmpty) {
      final List<int> loaded = scoresString.split(',').map((e) => int.tryParse(e) ?? 0).toList();
      loaded.sort((a, b) => b.compareTo(a));
      setState(() {
        scores = loaded;
        isLoading = false;
      });
    } else {
      setState(() {
        scores = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Scores'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : scores.isEmpty
              ? const Center(child: Text('No scores yet!', style: TextStyle(fontSize: 18)))
              : ListView.separated(
                  itemCount: scores.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Text('#${index + 1}', style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text('Score: ${scores[index]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
    );
  }
}
