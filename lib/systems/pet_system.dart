/// A pet that provides passive bonuses.
class PetDefinition {
  final String id;
  final String name;
  final double idleBonus;   // idle reward multiplier
  final double attackBonus; // flat attack addition

  const PetDefinition({
    required this.id,
    required this.name,
    required this.idleBonus,
    required this.attackBonus,
  });

  factory PetDefinition.fromJson(Map<String, dynamic> json) => PetDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        idleBonus: (json['idleBonus'] as num?)?.toDouble() ?? 0.0,
        attackBonus: (json['attackBonus'] as num?)?.toDouble() ?? 0.0,
      );
}

/// PetSystem manages unlocked pets and their passive contributions.
///
/// Update order: step 13 (meta progression).
class PetSystem {
  final List<PetDefinition> _catalogue = [];
  final List<String> _activePetIds = [];

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _catalogue
      ..clear()
      ..addAll(
        data
            .where((d) => d['type'] == 'pet')
            .map(PetDefinition.fromJson),
      );
  }

  void activatePet(String id) {
    if (!_activePetIds.contains(id)) _activePetIds.add(id);
  }

  void deactivatePet(String id) => _activePetIds.remove(id);

  double get totalIdleBonus => _activePets
      .fold(0.0, (sum, p) => sum + p.idleBonus);

  double get totalAttackBonus => _activePets
      .fold(0.0, (sum, p) => sum + p.attackBonus);

  List<PetDefinition> get _activePets => _activePetIds
      .map((id) {
        try {
          return _catalogue.firstWhere((p) => p.id == id);
        } catch (_) {
          return null;
        }
      })
      .whereType<PetDefinition>()
      .toList();

  void update(double deltaTime) {
    // Passive effects are read by other systems via totalIdleBonus etc.
  }
}
