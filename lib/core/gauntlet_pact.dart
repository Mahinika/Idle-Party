/// How this Gauntlet climb plays. Picked on the way in. The party still
/// walks and fights on its own.
enum GauntletPact { might, ward, greed }

abstract final class GauntletPacts {
  static GauntletPact? parse(String raw) => switch (raw) {
    'might' => GauntletPact.might,
    'ward' => GauntletPact.ward,
    'greed' => GauntletPact.greed,
    _ => null,
  };

  static String title(GauntletPact pact) => switch (pact) {
    GauntletPact.might => 'MIGHT',
    GauntletPact.ward => 'WARD',
    GauntletPact.greed => 'GREED',
  };

  static String blurb(GauntletPact pact) => switch (pact) {
    GauntletPact.might => 'The party hits harder.',
    GauntletPact.ward => 'The party takes less.',
    GauntletPact.greed => 'Double essence. The party is softer.',
  };

  static double attackMul(GauntletPact? pact) =>
      pact == GauntletPact.might ? 1.2 : 1;

  static double defenseMul(GauntletPact? pact) => switch (pact) {
    GauntletPact.ward => 1.25,
    GauntletPact.greed => 0.85,
    _ => 1,
  };

  static int essence(int base, GauntletPact? pact) {
    if (pact != GauntletPact.greed || base <= 0) return base;
    return base * 2;
  }
}
