import 'package:flutter/material.dart';
import 'package:pong_game/entername.dart';
import 'package:pong_game/hompage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<int>('scores');
  await Hive.openBox('settings');
  await Hive.openBox('leaderboard');
  await Hive.openBox('stats');

  // Migration one-time : ancien topscore vers leaderboard
  final scoresBox = Hive.box<int>('scores');
  final leaderboardBox = Hive.box('leaderboard');
  final oldTopScore = scoresBox.get('topscore', defaultValue: 0) ?? 0;
  if (oldTopScore > 0 && !leaderboardBox.containsKey('migrated')) {
    List<dynamic> entries = List<dynamic>.from(leaderboardBox.get('entries', defaultValue: []) ?? []);
    entries.add({
      'name': 'Joueur',
      'score': oldTopScore,
      'date': DateTime.now().toIso8601String(),
    });
    leaderboardBox.put('entries', entries);
    leaderboardBox.put('migrated', true);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pong Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _playLoaderSound();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _audioPlayer.stop();
        final settingsBox = Hive.box('settings');
        final savedPseudo = settingsBox.get('pseudo') as String?;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NamePage(savedPseudo: savedPseudo),
          ),
        );
      }
    });
  }

  Future<void> _playLoaderSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/loader.mp3'));
    } catch (e) {
      print('Loader sound error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "P O N G",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 60),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade800,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.pink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "${(_controller.value * 100).toInt()}%",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              const Text(
                "Chargement...",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
