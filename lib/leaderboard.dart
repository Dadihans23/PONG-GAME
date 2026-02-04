import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('leaderboard');
    final List<dynamic> entries = List<dynamic>.from(
      box.get('entries', defaultValue: []) ?? [],
    );
    // Trier par score décroissant
    entries.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return Scaffold(
      backgroundColor: Colors.black12,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.grey),
        title: const Text(
          'C L A S S E M E N T',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                'Aucun score enregistré',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index] as Map;
                final name = entry['name'] ?? 'Inconnu';
                final score = entry['score'] ?? 0;
                final dateStr = entry['date'] as String?;
                String formattedDate = '';
                if (dateStr != null) {
                  final date = DateTime.tryParse(dateStr);
                  if (date != null) {
                    formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                  }
                }

                // Couleurs podium
                Color rankColor;
                IconData? medalIcon;
                if (index == 0) {
                  rankColor = const Color(0xFFFFD700); // Or
                  medalIcon = Icons.emoji_events;
                } else if (index == 1) {
                  rankColor = const Color(0xFFC0C0C0); // Argent
                  medalIcon = Icons.emoji_events;
                } else if (index == 2) {
                  rankColor = const Color(0xFFCD7F32); // Bronze
                  medalIcon = Icons.emoji_events;
                } else {
                  rankColor = Colors.grey;
                  medalIcon = null;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: index < 3
                        ? Border.all(color: rankColor.withOpacity(0.5), width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Rang
                      SizedBox(
                        width: 36,
                        child: medalIcon != null
                            ? Icon(medalIcon, color: rankColor, size: 24)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: rankColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Nom et date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toString(),
                              style: TextStyle(
                                color: index < 3 ? rankColor : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (formattedDate.isNotEmpty)
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Score
                      Text(
                        '$score',
                        style: TextStyle(
                          color: index < 3 ? rankColor : Colors.pink,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
