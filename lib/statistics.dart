import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  String _formatDuration(int totalMs) {
    final duration = Duration(milliseconds: totalMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('stats');
    final totalGames = box.get('totalGames', defaultValue: 0) as int;
    final totalPlayTimeMs = box.get('totalPlayTimeMs', defaultValue: 0) as int;
    final bestStreak = box.get('bestStreak', defaultValue: 0) as int;

    return Scaffold(
      backgroundColor: Colors.black12,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.grey),
        title: const Text(
          'S T A T I S T I Q U E S',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          children: [
            _StatCard(
              icon: Icons.sports_esports,
              label: 'Parties jouées',
              value: '$totalGames',
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            _StatCard(
              icon: Icons.timer,
              label: 'Temps total de jeu',
              value: _formatDuration(totalPlayTimeMs),
              color: Colors.pink,
            ),
            const SizedBox(height: 20),
            _StatCard(
              icon: Icons.local_fire_department,
              label: 'Meilleure série',
              value: '$bestStreak renvois',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
