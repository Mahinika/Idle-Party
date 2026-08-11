import 'dart:async';

import 'package:flutter/material.dart';

import '../core/game_logic.dart';
import '../models/equip_stat_weights.dart';
import '../models/gear_set.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import 'character_equip_panel.dart';
import 'game_theme.dart';

/// Classic WoW-style rarity name colors.
Color itemRarityColor(LootRarity rarity) => switch (rarity) {
      LootRarity.common => const Color(0xFFFFFFFF),
      LootRarity.uncommon => const Color(0xFF1EFF00),
      LootRarity.rare => const Color(0xFF0070DD),
      LootRarity.epic => const Color(0xFFA335EE),
      LootRarity.legendary => const Color(0xFFFF8000),
    };

Color itemRarityBorder(LootRarity rarity) => switch (rarity) {
      LootRarity.common => const Color(0xFF9D9D9D),
      LootRarity.uncommon => const Color(0xFF1EFF00),
      LootRarity.rare => const Color(0xFF0070DD),
      LootRarity.epic => const Color(0xFFA335EE),
      LootRarity.legendary => const Color(0xFFFF8000),
    };

/// WoW-inspired item tooltip body (dark panel, rarity name, stacked stats).
class ItemTooltipCard extends StatelessWidget {
  const ItemTooltipCard({
    super.key,
    required this.item,
    this.hero,
    this.compact = false,
  });

  final EquipmentItem item;
  final PartyHero? hero;
  final bool compact;

  static const _green = Color(0xFF1EFF00);
  static const _red = Color(0xFFFF4040);
  static const _gold = Color(0xFFFFD100);

  @override
  Widget build(BuildContext context) {
    final slotLabel =
        CharacterEquipPanel.slotLabels[item.slot] ?? item.slot.name;
    final type = _typeLine(item);
    final binding = item.id.startsWith('soulbound_') || item.isApex
        ? 'Soulbound'
        : 'Binds when equipped';
    final gold = GameLogic.equipmentGoldValue(item);
    final essence = GameLogic.equipmentEssenceValue(item);

    EquipmentItem? worn;
    var intoSlot = item.slot;
    var powerDelta = 0;
    var comparing = false;
    var alreadyEquipped = false;
    if (hero != null) {
      final cmp = GameLogic.compareForHero(hero!, item);
      intoSlot = cmp.intoSlot;
      powerDelta = cmp.powerDelta;
      worn = hero!.itemIn(intoSlot);
      if (worn?.id == item.id) {
        alreadyEquipped = true;
        worn = null;
        comparing = false;
      } else {
        comparing = true;
      }
    }

    final statRows = _compareStatRows(item, worn);
    final ilvlDelta = comparing
        ? item.effectiveItemLevel - (worn?.effectiveItemLevel ?? 0)
        : 0;

    String? setHeader;
    final setLines = <({String text, bool active})>[];
    final setId = item.setId;
    if (setId != null && setId.isNotEmpty) {
      final wornCount =
          hero == null ? 0 : GearSets.wornCount(hero!.equipped, setId);
      final name = GearSets.displayName(setId);
      setHeader = '$name ($wornCount/4)';
      setLines.add((
        text: '2 piece: +stats',
        active: wornCount >= 2,
      ));
      setLines.add((
        text: '4 piece: +stats · 10% set proc on auto',
        active: wornCount >= 4,
      ));
    }

    final wornSlotLabel =
        CharacterEquipPanel.slotLabels[intoSlot] ?? intoSlot.name;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: compact ? 220 : 248,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          decoration: BoxDecoration(
            color: const Color(0xF0140C08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: itemRarityBorder(item.rarity).withValues(alpha: 0.85),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: GameTheme.body(size: 12, color: GameTheme.parchment),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: GameTheme.body(
                    size: 15,
                    color: itemRarityColor(item.rarity),
                  ),
                ),
                const SizedBox(height: 2),
                _StatCompareRow(
                  label: 'Item Level ${item.effectiveItemLevel}',
                  labelColor: _gold,
                  delta: comparing ? ilvlDelta : null,
                  emphasizeDelta: true,
                ),
                Text(
                  binding,
                  style: GameTheme.body(
                    size: 12,
                    color: GameTheme.parchment,
                  ),
                ),
                if (item.isApex)
                  Text(
                    'Apex Rank ${item.apexRank}'
                    '${item.apexClassId != null ? ' · ${item.apexClassId}' : ''}',
                    style: GameTheme.body(
                      size: 12,
                      color: _gold,
                    ),
                  ),
                if (alreadyEquipped) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Currently equipped',
                    style: GameTheme.body(size: 12, color: _gold),
                  ),
                ],
                if (comparing) ...[
                  const SizedBox(height: 4),
                  Text(
                    worn == null
                        ? 'vs empty ${_titleCase(wornSlotLabel)}'
                        : 'vs ${worn.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _titleCase(slotLabel),
                        style: GameTheme.body(
                          size: 12,
                          color: GameTheme.parchment,
                        ),
                      ),
                    ),
                    if (type != null)
                      Text(
                        type,
                        style: GameTheme.body(
                          size: 12,
                          color: GameTheme.parchment,
                        ),
                      ),
                  ],
                ),
                if (item.slot == EquipmentSlot.weapon ||
                    item.weaponType != null) ...[
                  Text(
                    _weaponSwingLine(item),
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.parchment,
                    ),
                  ),
                ],
                if (statRows.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final row in statRows)
                    _StatCompareRow(
                      label: row.value == 0
                          ? row.name
                          : '${row.value > 0 ? '+' : ''}${row.value} ${row.name}',
                      labelColor: row.value == 0
                          ? GameTheme.parchmentDim
                          : _green,
                      delta: comparing ? row.delta : null,
                      emphasizeDelta: true,
                    ),
                ],
                if (item.effectLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _effectCompareLine(item, worn),
                ],
                if (hero != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    EquipStatWeights.priorityBlurb(hero!.spec),
                    style: GameTheme.body(
                      size: 11,
                      color: _gold,
                    ),
                  ),
                ],
                if (item.affinity != null && item.affinity!.isNotEmpty)
                  Text(
                    _affinityLine(item.affinity!, hero),
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                if (setHeader != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    setHeader,
                    style: GameTheme.body(
                      size: 12,
                      color: _gold,
                    ),
                  ),
                  for (final line in setLines)
                    Text(
                      line.text,
                      style: GameTheme.body(
                        size: 11,
                        color: line.active
                            ? _green
                            : GameTheme.parchmentDim,
                      ),
                    ),
                ],
                if (comparing) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (powerDelta > 0
                              ? _green
                              : (powerDelta < 0 ? _red : GameTheme.parchmentDim))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: powerDelta > 0
                            ? _green
                            : (powerDelta < 0
                                ? _red
                                : GameTheme.parchmentDim),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      powerDelta > 0
                          ? 'UPGRADE  Score ${GameLogic.formatDelta(powerDelta)}'
                          : (powerDelta < 0
                              ? 'WEAKER  Score ${GameLogic.formatDelta(powerDelta)}'
                              : 'SAME SCORE'),
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 12,
                        color: powerDelta > 0
                            ? _green
                            : (powerDelta < 0
                                ? _red
                                : GameTheme.parchmentDim),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Sell: $gold gold · Scrap: $essence essence',
                  style: GameTheme.body(
                    size: 11,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _effectCompareLine(EquipmentItem item, EquipmentItem? worn) {
    final neu = item.effectLabel;
    final old = worn?.effectLabel ?? '';
    String? deltaText;
    Color? deltaColor;
    if (worn != null) {
      if (neu != old) {
        if (old.isEmpty) {
          deltaText = 'NEW';
          deltaColor = _green;
        } else if (neu.isEmpty) {
          deltaText = 'LOST';
          deltaColor = _red;
        } else {
          deltaText = 'CHG';
          deltaColor = _gold;
        }
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Equip: $neu',
            style: GameTheme.body(size: 12, color: _green),
          ),
        ),
        if (deltaText != null)
          Text(
            deltaText,
            style: GameTheme.body(size: 11, color: deltaColor!),
          ),
      ],
    );
  }

  static String? _typeLine(EquipmentItem item) {
    if (item.armorType != null) {
      return _titleCase(item.armorType!.name);
    }
    if (item.slot == EquipmentSlot.offHand) {
      return switch (item.offHandKind ?? OffHandKind.shield) {
        OffHandKind.shield => 'Shield',
        OffHandKind.frill => 'Held In Off-hand',
        OffHandKind.weapon => 'Off Hand',
      };
    }
    if (item.weaponType != null) {
      final hand = switch (item.handed) {
        WeaponHanded.twoHand => 'Two-Hand',
        WeaponHanded.oneHand => 'One-Hand',
        null => null,
      };
      final wt = _titleCase(item.weaponType!.name);
      return hand == null ? wt : '$hand $wt';
    }
    return null;
  }

  static String _weaponSwingLine(EquipmentItem item) {
    final pattern = switch (item.pattern) {
      ProjectilePattern.single => 'Single',
      ProjectilePattern.spread => 'Spread',
      ProjectilePattern.arc => 'Arc',
      ProjectilePattern.pierce => 'Pierce',
    };
    if (item.attackBonus > 0) {
      return 'Attack Power +${item.attackBonus} · $pattern';
    }
    return 'Pattern: $pattern';
  }

  /// Union of candidate + worn stats so lost stats show as red deltas.
  static List<({String name, int value, int delta})> _compareStatRows(
    EquipmentItem item,
    EquipmentItem? worn,
  ) {
    final rows = <({String name, int value, int delta})>[];
    void add(String name, int neu, int old) {
      if (neu == 0 && old == 0) return;
      rows.add((name: name, value: neu, delta: neu - old));
    }

    add('Armor', item.resolvedArmor, worn?.resolvedArmor ?? 0);
    add('Strength', item.strengthBonus, worn?.strengthBonus ?? 0);
    add('Agility', item.agilityBonus, worn?.agilityBonus ?? 0);
    add('Stamina', item.resolvedStamina, worn?.resolvedStamina ?? 0);
    add('Intellect', item.intellectBonus, worn?.intellectBonus ?? 0);
    add('Spirit', item.spiritBonus, worn?.spiritBonus ?? 0);
    add('Spell Power', item.spellPowerBonus, worn?.spellPowerBonus ?? 0);
    add('Attack Power', item.attackBonus, worn?.attackBonus ?? 0);
    add('Mp5', item.mp5Bonus, worn?.mp5Bonus ?? 0);
    add('Crit %', item.critChanceBonus, worn?.critChanceBonus ?? 0);
    add('Haste %', item.attackSpeedBonus, worn?.attackSpeedBonus ?? 0);
    add('Move %', item.moveSpeedBonus, worn?.moveSpeedBonus ?? 0);
    return rows;
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    final lower = raw.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  static String _affinityLine(String affinity, PartyHero? hero) {
    final pretty = _titleCase(affinity);
    if (hero == null) return 'Affinity: $pretty';
    final match = hero.spec.gearAffinity.name == affinity.toLowerCase();
    if (match) {
      return 'Affinity: $pretty · matches ${hero.spec.shortLabel}';
    }
    return 'Affinity: $pretty · weak for ${hero.spec.shortLabel}';
  }
}

class _StatCompareRow extends StatelessWidget {
  const _StatCompareRow({
    required this.label,
    required this.labelColor,
    this.delta,
    this.emphasizeDelta = false,
  });

  final String label;
  final Color labelColor;
  final int? delta;
  final bool emphasizeDelta;

  static const _green = Color(0xFF1EFF00);
  static const _red = Color(0xFFFF4040);

  @override
  Widget build(BuildContext context) {
    final d = delta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GameTheme.body(size: 12, color: labelColor),
            ),
          ),
          if (d != null && d != 0)
            Text(
              GameLogic.formatDelta(d),
              style: GameTheme.body(
                size: emphasizeDelta ? 13 : 12,
                color: d > 0 ? _green : _red,
              ),
            ),
        ],
      ),
    );
  }
}
/// Phone-first item tooltip: **long-press** opens a centered card + scrim.
/// Hover still works for wide web playtest. Short tap is left to the child
/// (select / equip) so bag selection stays usable.
class ItemTooltipAnchor extends StatefulWidget {
  const ItemTooltipAnchor({
    super.key,
    required this.item,
    required this.child,
    this.hero,
    this.enabled = true,
  });

  /// Portrait / phone sheet threshold (matches GEAR wide layout break).
  static const double phoneMaxWidth = 520;

  final EquipmentItem item;
  final Widget child;
  final PartyHero? hero;
  final bool enabled;

  @override
  State<ItemTooltipAnchor> createState() => _ItemTooltipAnchorState();
}

class _ItemTooltipAnchorState extends State<ItemTooltipAnchor> {
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _anchorKey = GlobalKey();
  Timer? _showTimer;
  Timer? _hideTimer;
  var _phoneSheet = false;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_portal.isShowing) _portal.hide();
    super.dispose();
  }

  void _showNow({required bool phoneSheet}) {
    if (!widget.enabled) return;
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _phoneSheet = phoneSheet;
    if (!_portal.isShowing) _portal.show();
  }

  void _hideNow() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_portal.isShowing) _portal.hide();
  }

  void _scheduleShow() {
    if (!widget.enabled) return;
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || !widget.enabled) return;
      _phoneSheet = false;
      if (!_portal.isShowing) _portal.show();
    });
  }

  void _scheduleHide() {
    if (_phoneSheet) return;
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_portal.isShowing) _portal.hide();
    });
  }

  void _cancelHide() {
    _hideTimer?.cancel();
  }

  Rect? _anchorRectInOverlay(BuildContext overlayContext) {
    final anchorCtx = _anchorKey.currentContext;
    if (anchorCtx == null) return null;
    final anchorBox = anchorCtx.findRenderObject() as RenderBox?;
    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (anchorBox == null ||
        overlayBox == null ||
        !anchorBox.hasSize ||
        !overlayBox.hasSize) {
      return null;
    }
    final origin = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return origin & anchorBox.size;
  }

  @override
  Widget build(BuildContext context) {
    final phone =
        MediaQuery.sizeOf(context).width < ItemTooltipAnchor.phoneMaxWidth;

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayContext) {
        final screen = MediaQuery.sizeOf(overlayContext);
        final card = ItemTooltipCard(
          item: widget.item,
          hero: widget.hero,
          compact: phone || _phoneSheet,
        );

        if (_phoneSheet || phone) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hideNow,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (screen.width - 24).clamp(160.0, 280.0),
                    maxHeight: screen.height * 0.72,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(child: card),
                  ),
                ),
              ),
            ],
          );
        }

        final target = _anchorRectInOverlay(overlayContext);
        if (target == null) return const SizedBox.shrink();

        return CustomSingleChildLayout(
          delegate: _ItemTooltipLayoutDelegate(
            target: target,
            screen: screen,
          ),
          child: MouseRegion(
            onEnter: (_) => _cancelHide(),
            onExit: (_) => _scheduleHide(),
            child: card,
          ),
        );
      },
      child: GestureDetector(
        key: _anchorKey,
        behavior: HitTestBehavior.deferToChild,
        onLongPress: () => _showNow(phoneSheet: true),
        child: phone
            ? widget.child
            : MouseRegion(
                onEnter: (_) => _scheduleShow(),
                onExit: (_) => _scheduleHide(),
                child: widget.child,
              ),
      ),
    );
  }
}

/// Places the tip beside the slot and keeps the full card inside the viewport
/// for every bag row (top rows flip below / clamp; bottom rows flip above).
class _ItemTooltipLayoutDelegate extends SingleChildLayoutDelegate {
  _ItemTooltipLayoutDelegate({
    required this.target,
    required this.screen,
  });

  final Rect target;
  final Size screen;

  static const double _pad = 8;
  static const double _gap = 10;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: (screen.width - _pad * 2).clamp(120.0, 248.0),
      maxHeight: screen.height - _pad * 2,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Prefer left of the slot (bag sits on the right); fall back to right.
    var x = target.left - childSize.width - _gap;
    if (x < _pad) {
      x = target.right + _gap;
    }
    if (x + childSize.width > screen.width - _pad) {
      x = (screen.width - childSize.width - _pad).clamp(_pad, screen.width);
    }

    final spaceAbove = target.top - _pad;
    final spaceBelow = screen.height - target.bottom - _pad;

    double y;
    // Top rows: not enough room above → place below the slot.
    if (spaceAbove < childSize.height + _gap && spaceBelow >= spaceAbove) {
      y = target.bottom + _gap;
      if (y + childSize.height > screen.height - _pad) {
        y = screen.height - childSize.height - _pad;
      }
    } else if (spaceBelow < childSize.height + _gap &&
        spaceAbove > spaceBelow) {
      // Bottom rows: place above the slot.
      y = target.top - childSize.height - _gap;
      if (y < _pad) y = _pad;
    } else {
      // Middle: vertically center on the slot, then clamp.
      y = target.center.dy - childSize.height / 2;
      y = y.clamp(_pad, screen.height - childSize.height - _pad);
    }

    if (y < _pad) y = _pad;
    if (y + childSize.height > screen.height - _pad) {
      y = (screen.height - childSize.height - _pad).clamp(_pad, screen.height);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _ItemTooltipLayoutDelegate oldDelegate) {
    return target != oldDelegate.target || screen != oldDelegate.screen;
  }
}
