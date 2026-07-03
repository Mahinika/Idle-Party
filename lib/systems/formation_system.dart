import '../models/hero.dart';

/// Formation slot defines a position in the battle grid.
class FormationSlot {
  final int row;
  final int column;
  HeroState? hero;

  FormationSlot({required this.row, required this.column, this.hero});
}

/// FormationSystem manages hero positioning and derives position bonuses.
///
/// Update order: step 15 (auxiliary).
class FormationSystem {
  static const int rows = 3;
  static const int columns = 3;

  late final List<List<FormationSlot>> _grid;

  FormationSystem() {
    _grid = List.generate(
      rows,
      (r) => List.generate(columns, (c) => FormationSlot(row: r, column: c)),
    );
  }

  /// Place a hero in a specific slot.
  void placeHero(HeroState hero, int row, int col) {
    _grid[row][col].hero = hero;
  }

  /// Remove a hero from its slot.
  void removeHero(int row, int col) {
    _grid[row][col].hero = null;
  }

  void update(double deltaTime) {
    // Placeholder: position-based buff application (front-row armor, etc.)
  }

  List<HeroState> get frontRow =>
      _grid[0].map((s) => s.hero).whereType<HeroState>().toList();

  List<HeroState> get allHeroes => [
        for (final row in _grid)
          for (final slot in row)
            if (slot.hero != null) slot.hero!,
      ];
}
