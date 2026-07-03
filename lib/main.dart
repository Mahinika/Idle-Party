import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/game_director.dart';

void main() {
  runApp(const IdlePartyApp());
}

class IdlePartyApp extends StatelessWidget {
  const IdlePartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Party',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B2D8B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

/// GameScreen bootstraps the engine, loads assets and runs the tick loop.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameDirector _director;
  Timer? _tickTimer;
  bool _initialized = false;
  String _statusMessage = 'Loading…';

  @override
  void initState() {
    super.initState();
    _director = GameDirector();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final data = await _loadGameData();
      await _director.initialize(data);
      _startTickLoop();
      if (mounted) {
        setState(() {
          _initialized = true;
          _statusMessage = 'Engine running';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Error: $e');
      }
    }
  }

  Future<GameData> _loadGameData() async {
    Future<List<Map<String, dynamic>>> loadJson(String path) async {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }

    return GameData(
      heroes: await loadJson('lib/data/heroes.json'),
      enemies: await loadJson('lib/data/enemies.json'),
      skills: await loadJson('lib/data/skills.json'),
      items: await loadJson('lib/data/items.json'),
      dungeonModifiers: await loadJson('lib/data/dungeon_modifiers.json'),
      weather: await loadJson('lib/data/weather.json'),
      events: await loadJson('lib/data/events.json'),
    );
  }

  void _startTickLoop() {
    // 20 ticks per second (50 ms interval).
    const tickInterval = Duration(milliseconds: 50);
    const deltaTime = 0.05; // seconds per tick
    _tickTimer = Timer.periodic(tickInterval, (_) {
      _director.tick(deltaTime);
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _director.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A2E),
      appBar: AppBar(
        title: const Text('Idle Party'),
        backgroundColor: const Color(0xFF2D1B4E),
        foregroundColor: Colors.white,
      ),
      body: _initialized ? _buildGameUi() : _buildLoadingUi(),
    );
  }

  Widget _buildLoadingUi() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.purple),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildGameUi() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(director: _director),
          const SizedBox(height: 16),
          const Text(
            'Game engine is running.\n'
            'The 15-step update pipeline executes 20× per second.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Simple status card that rebuilds periodically to show live engine state.
class _StatusCard extends StatefulWidget {
  final GameDirector director;

  const _StatusCard({required this.director});

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = widget.director.economySystem.gold.toStringAsFixed(0);
    final dps = widget.director.teamDpsSystem.teamDps.toStringAsFixed(1);
    final weather =
        widget.director.weatherSystem.activeCondition?.name ?? 'None';
    final prestige = widget.director.prestigeSystem.prestigeLevel;

    return Card(
      color: const Color(0xFF2D1B4E),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Engine Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.white24),
            _Row('Gold', gold),
            _Row('Team DPS', dps),
            _Row('Weather', weather),
            _Row('Prestige Level', '$prestige'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
