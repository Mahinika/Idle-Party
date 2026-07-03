enum MultiplierCategory {
  weather,
  event,
  dungeon,
  buff,
  debuff,
  skill,
  formation,
  relic,
  pet,
  rune,
  artifact,
  combat,
}

/// [DpsPipeline] is the central damage and multiplier calculator for the game engine.
///
/// It implements a category-based scaling approach designed to prevent runaway
/// exponential scaling typical of same-source modifiers in idle RPG games.
///
/// ### Stacking Rules:
/// - **Additive Within Category**: All multipliers added to a specific [MultiplierCategory]
///   are summed together first (e.g., +15% and +10% bonuses yield a `1.25` multiplier for that category).
/// - **Multiplicative Between Categories**: The final multiplier is computed by multiplying
///   the resulting sums of each distinct category (e.g., `Category A Multiplier * Category B Multiplier`).
class DpsPipeline {
  final Map<MultiplierCategory, List<double>> _multipliers = {};

  DpsPipeline() {
    clear();
  }

  void clear() {
    _multipliers.clear();
    for (var category in MultiplierCategory.values) {
      _multipliers[category] = [];
    }
  }

  /// Adds a multiplier bonus (e.g., 0.15 for a +15% increase, or -0.10 for a -10% decrease)
  /// to a specific category. Within each category, scaling is additive to prevent
  /// runaway exponential scaling of same-source effects.
  void addBonus(MultiplierCategory category, double value) {
    _multipliers[category]?.add(value);
  }

  /// Calculates the final value based on the base and category-based multiplication.
  double process(double baseValue) {
    double totalMultiplier = 1.0;
    
    _multipliers.forEach((category, list) {
      if (list.isNotEmpty) {
        double categoryMultiplier = 1.0;
        for (var val in list) {
          categoryMultiplier += val;
        }
        // Clamping to 0 to prevent negative multipliers from reversing effects
        if (categoryMultiplier < 0) {
          categoryMultiplier = 0.0;
        }
        totalMultiplier *= categoryMultiplier;
      }
    });

    return baseValue * totalMultiplier;
  }
}
