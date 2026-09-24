/// Public cast surface for kit runners outside [SpatialCombat]'s private core.
///
/// Named casts and [AbilityEffectRunner] call these through [SpatialCombat]
/// (spawn / hurt / rage / CD / floaters) and [AbilityEffectRunner] (spend, damage,
/// heal, announce). Keep new shared helpers here or as public [SpatialCombat]
/// methods — do not grow a second combat sim.
library;

export 'ability_effects.dart' show AbilityEffectRunner;
export 'kit_migrated_casts.dart' show KitNamedCasts;
export 'spatial_combat.dart'
    show
        SpatialCombat,
        SpatialActor,
        SpatialWorld,
        SpatialTeam,
        actorIsTank,
        actorIsHealer,
        actorIsMeleeDps;
