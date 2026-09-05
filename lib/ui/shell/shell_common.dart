import 'package:flutter/material.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../models/loot.dart';
import '../game_theme.dart';

Color rarityBorderColor(LootRarity rarity) => switch (rarity) {
  LootRarity.common => GameTheme.rarityCommon,
  LootRarity.uncommon => GameTheme.rarityUncommon,
  LootRarity.rare => GameTheme.rarityRare,
  LootRarity.epic => GameTheme.borderLit,
  LootRarity.legendary => GameTheme.rarityLegendary,
};

String patternGlyph(ProjectilePattern pattern) => switch (pattern) {
  ProjectilePattern.single => 'S',
  ProjectilePattern.spread => 'P',
  ProjectilePattern.arc => 'A',
  ProjectilePattern.pierce => 'X',
};

String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  if (n >= 1000) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
  return '$n';
}

bool isSoulboundItem(EquipmentItem item) => item.id.startsWith('soulbound_');

bool isUpgradeForAny(GameState state, EquipmentItem item) =>
    GameLogic.autoEquipWouldWear(state, item.id);

bool isBestStashItem(GameState state, EquipmentItem item) =>
    GameLogic.isBestPlannedStashItem(state, item.id);

/// Tab controller whose length can grow as menus unlock (progressive tabs).
///
/// Callers drive it with a tab **id** (see `MenuRouter`) and hand it the list
/// of ids that are visible right now; unlocking MERGE must not change what the
/// tab you were on means.
class FlexTabs {
  FlexTabs({
    required this.vsync,
    required int length,
    required this.onChanged,
    int initialIndex = 0,
  }) {
    _build(length, initialIndex);
  }

  /// Keeps the rail in step with [ids] and jumps to [selected].
  void syncToId<T>(List<T> ids, T selected) {
    if (ids.isEmpty) return;
    sync(ids.length);
    // A tap is already sliding to its target; snapping back here would eat it.
    if (controller.indexIsChanging) return;
    final want = ids.indexOf(selected);
    if (want >= 0 && want != controller.index) {
      controller.index = want;
    }
  }

  final TickerProvider vsync;
  final ValueChanged<int> onChanged;
  late TabController controller;

  int get index => controller.index;

  /// Call from build once the visible tab count is known.
  void sync(int length) {
    if (length < 1 || controller.length == length) return;
    final keep = controller.index.clamp(0, length - 1);
    final old = controller;
    _build(length, keep);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void animateTo(int index) {
    controller.animateTo(index.clamp(0, controller.length - 1));
  }

  void _build(int length, int initialIndex) {
    controller = TabController(
      length: length,
      vsync: vsync,
      initialIndex: initialIndex.clamp(0, length - 1),
    );
    controller.addListener(() {
      if (!controller.indexIsChanging) onChanged(controller.index);
    });
  }

  void dispose() => controller.dispose();
}

/// Count / star drawn on a nav icon when that menu has something to do.
