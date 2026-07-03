/// DPS Pipeline – category-based multiplicative damage system.
///
/// Design:
///   Each damage category (e.g. 'base', 'skill', 'relic', 'weather') holds
///   a list of multipliers that are applied multiplicatively within the
///   category.  Final DPS = baseDamage × Π(category totals).
///
/// Adding a new multiplier type never requires modifying this class – callers
/// register their own category name and value.
class DpsPipeline {
  final Map<String, List<double>> _categories = {};

  /// Register a multiplier under [category].
  /// Multiple multipliers in the same category are multiplied together.
  void addMultiplier(String category, double value) {
    _categories.putIfAbsent(category, () => []).add(value);
  }

  /// Remove all multipliers under [category].
  void clearCategory(String category) {
    _categories.remove(category);
  }

  /// Clear all registered multipliers.
  void clearAll() => _categories.clear();

  /// Compute the combined multiplier across all categories.
  double computeMultiplier() {
    var result = 1.0;
    for (final list in _categories.values) {
      for (final m in list) {
        result *= m;
      }
    }
    return result;
  }

  /// Apply the pipeline to a raw damage value.
  double apply(double rawDamage) => rawDamage * computeMultiplier();

  /// List registered categories (useful for debug / UI).
  List<String> get categories => List.unmodifiable(_categories.keys);

  /// Return a snapshot of current state for diagnostics.
  Map<String, double> categoryTotals() => {
        for (final entry in _categories.entries)
          entry.key:
              entry.value.fold(1.0, (acc, m) => acc * m),
      };
}
