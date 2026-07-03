class Pet {
  final String id;
  final String name;
  final String description;
  final double baseBonus;
  final String bonusType; // "dps", "hp", "cooldown"
  int level;

  Pet({
    required this.id,
    required this.name,
    required this.description,
    required this.baseBonus,
    required this.bonusType,
    this.level = 0,
  });

  double get currentBonus => level * baseBonus;
}

class PetSystem {
  final Map<String, Pet> _pets = {};

  PetSystem() {
    _registerPets();
  }

  void _registerPets() {
    _pets['pet_dragon'] = Pet(
      id: 'pet_dragon',
      name: 'Baby Drake',
      description: 'Provides +3% total DPS per level.',
      baseBonus: 0.03,
      bonusType: 'dps',
    );
    _pets['pet_turtle'] = Pet(
      id: 'pet_turtle',
      name: 'Ancient Turtle',
      description: 'Provides +4% total HP per level.',
      baseBonus: 0.04,
      bonusType: 'hp',
    );
    _pets['pet_fairy'] = Pet(
      id: 'pet_fairy',
      name: 'Forest Fairy',
      description: 'Provides +2% cooldown speed per level.',
      baseBonus: 0.02,
      bonusType: 'cooldown',
    );
  }

  List<Pet> get activePets => _pets.values.toList();

  Pet? getPet(String petId) {
    return _pets[petId];
  }

  double getUpgradeCost(String petId) {
    final pet = getPet(petId);
    if (pet == null) return 0.0;
    return (pet.level + 1) * 200.0; // Costs gold
  }

  bool tryUpgradePet(String petId, double availableGold, Function(double cost) onDeduct) {
    final pet = getPet(petId);
    if (pet == null) return false;

    final cost = getUpgradeCost(petId);
    if (availableGold >= cost) {
      pet.level++;
      onDeduct(cost);
      return true;
    }
    return false;
  }

  double getDpsBonusMultiplier() {
    return _pets['pet_dragon']?.currentBonus ?? 0.0;
  }

  double getHpBonusMultiplier() {
    return _pets['pet_turtle']?.currentBonus ?? 0.0;
  }

  double getCooldownBonus() {
    return _pets['pet_fairy']?.currentBonus ?? 0.0;
  }
}
