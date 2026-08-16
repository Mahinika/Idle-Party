import 'package:flutter/material.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../models/loot.dart';
import '../game_theme.dart';
import '../kenney_sprite.dart';

Color rarityBorderColor(LootRarity rarity) => switch (rarity) {
  LootRarity.common => const Color(0xFF5A5040),
  LootRarity.uncommon => const Color(0xFF70C050),
  LootRarity.rare => const Color(0xFF5090E0),
  LootRarity.epic => GameTheme.borderLit,
  LootRarity.legendary => const Color(0xFFFF8C40),
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

bool isUpgradeForAny(GameState state, EquipmentItem item) {
  for (final hero in state.heroes) {
    if (GameLogic.compareForHero(
      hero,
      item,
      pairingStash: state.gearStash,
    ).isUpgrade) {
      return true;
    }
  }
  return false;
}

bool isBestStashItem(GameState state, EquipmentItem item) {
  if (!isUpgradeForAny(state, item)) return false;
  var bestDelta = 0;
  for (final stashItem in state.gearStash) {
    for (final hero in state.heroes) {
      final cmp = GameLogic.compareForHero(
        hero,
        stashItem,
        pairingStash: state.gearStash,
      );
      if (cmp.isUpgrade && cmp.powerDelta > bestDelta) {
        bestDelta = cmp.powerDelta;
      }
    }
  }
  for (final hero in state.heroes) {
    final cmp = GameLogic.compareForHero(
      hero,
      item,
      pairingStash: state.gearStash,
    );
    if (cmp.isUpgrade && cmp.powerDelta >= bestDelta) return true;
  }
  return false;
}

class ShellChip extends StatelessWidget {
  const ShellChip({super.key, required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: GameTheme.stone.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: GameTheme.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KenneySprite(asset: icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GameTheme.pixel(
              size: GameTheme.hudPixel,
              color: GameTheme.torchHot,
            ),
          ),
        ],
      ),
    );
  }
}

class FlexTabs {
  FlexTabs({
    required this.vsync,
    required int length,
    required this.onChanged,
    int initialIndex = 0,
  }) {
    _build(length, initialIndex);
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
