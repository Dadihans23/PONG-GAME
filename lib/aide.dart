import 'package:flutter/material.dart';

class AidePage extends StatelessWidget {
  const AidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.grey),
        title: const Text(
          'A I D E',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildSection(
            icon: Icons.gamepad,
            color: Colors.blueAccent,
            title: 'Controles',
            items: ['Inclinez votre telephone pour deplacer le paddle'],
          ),
          _buildSection(
            icon: Icons.sports_score,
            color: Colors.pink,
            title: 'Objectif',
            items: ['Renvoyez la balle pour marquer des points. Ne la laissez pas passer !'],
          ),
          _buildSection(
            icon: Icons.star,
            color: Colors.orange,
            title: 'Points',
            items: [
              '50 points par renvoi de paddle',
              "100 points si l'adversaire rate la balle",
            ],
          ),
          _buildSection(
            icon: Icons.speed,
            color: Colors.red,
            title: 'Vitesse',
            items: ['La balle accelere tous les 4 renvois'],
          ),
          _buildSection(
            icon: Icons.pause_circle,
            color: Colors.deepPurple,
            title: 'Pause',
            items: ['Appuyez sur le bouton pause en haut a droite pendant la partie'],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 4),
              child: Text(
                item,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
