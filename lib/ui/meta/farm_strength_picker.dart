import 'package:flutter/material.dart';

import '../../core/farm_intensity.dart';
import '../../core/game_director.dart';
import '../../core/game_state.dart';
import '../chunky_face.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import '../shell/shell_layout.dart';
import '../web_click_bridge.dart';

/// FARM strength (1× / 2× / 4×) — picked before a run beside the KEY dial
/// and ENTER, and from the "FARM n×" chip at the fight seam mid-run.
/// UI only: the math, unlocks and TRY uses live in [FarmIntensity].
class FarmStrengthPicker extends StatelessWidget {
  const FarmStrengthPicker({
    super.key,
    required this.director,
    this.inRun = false,
    this.compact = false,
  });

  final GameDirector director;

  /// Mid-run (seam sheet): a locked tier offers its TRY when one is left.
  final bool inRun;

  /// Town ENTER card: label and tiers on one row, one line under them
  /// (the next unlock rule, or the short blurb).
  final bool compact;

  static const Key pickerKey = ValueKey('farm-strength-picker');
  static Key tierKey(int mult) => ValueKey('farm-strength-$mult');
  static const String title = 'FARM strength';
  static const String compactTitle = 'FARM';

  /// Before a run (KEY sheet, town ENTER): only once a floor is cleared, so
  /// the first-run flow is unchanged.
  static bool showBeforeEnter(GameState s) => s.highestFloorCleared > 0;
  static const String blurb =
      'Stronger packs, more loot. Only on floors you\'ve cleared, in FARM mode.';

  /// Full one-line copy (title + tiers + blurb).
  static String get copyLine =>
      '$title: ${FarmIntensity.allowed.map((m) => '$m×').join(' / ')} — '
      'stronger packs, more loot. Only on floors you\'ve cleared, in FARM mode.';

  /// The tier the player has set (not a running TRY).
  static int pickedMult(GameState s) {
    final picked = s.metaDepth.farmIntensity;
    final clamped = FarmIntensity.allowed.contains(picked) ? picked : 1;
    return clamped.clamp(1, FarmIntensity.maxUnlocked(s));
  }

  /// [unlockLine] short enough for one line under the town ENTER picker at
  /// 1.45 on a 360 dp phone. The full rule stays in the toast and semantics.
  static String compactUnlockLine(GameState s, int mult) {
    if (mult <= 2) return '$mult×: beat a boss (daily chase)';
    final clears = s.metaDepth.lifetimeFloorClears.clamp(0, 20);
    return '$mult×: 20 clears ($clears/20) or Ascend';
  }

  /// Short blurb for the compact picker when every tier is open.
  static const String compactOpenLine = 'Stronger packs, more loot.';

  /// How a locked tier unlocks (mirrors [FarmIntensity.maxUnlocked]).
  static String unlockLine(GameState s, int mult) {
    if (mult <= 2) return '$mult× unlocks with the daily chase (beat a boss).';
    final clears = s.metaDepth.lifetimeFloorClears.clamp(0, 20);
    return '$mult× unlocks after 20 floor clears ($clears/20) or Ascension.';
  }

  /// Seam chip text, e.g. "FARM 2×".
  static String seamLabel(GameState s) =>
      'FARM ${FarmIntensity.effectiveMult(s)}×';

  static Future<void> openSheet(BuildContext context, GameDirector director) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ListenableBuilder(
        listenable: director,
        builder: (ctx, _) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(ctx).bottom,
          ),
          child: Material(
            color: GameTheme.sheet,
            borderRadius: MenuChrome.sheetRadius,
            child: SingleChildScrollView(
              padding: ShellLayout.sheetPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MenuChrome.sheetHandle(),
                  Stack(
                    children: [
                      FarmStrengthPicker(director: director, inRun: true),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: MenuChrome.sheetCloseX(ctx),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = director.state;
    final current = inRun ? FarmIntensity.effectiveMult(s) : pickedMult(s);
    final locked = [
      for (final m in FarmIntensity.allowed)
        if (!FarmIntensity.canPick(s, m)) m,
    ];
    if (compact) return _compact(s, current, locked);
    return Column(
      key: pickerKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: GameTheme.hint(color: GameTheme.torchHot)),
        const SizedBox(height: 2),
        Row(
          children: [
            for (var i = 0; i < FarmIntensity.allowed.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _tier(s, FarmIntensity.allowed[i], current)),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          blurb,
          textAlign: TextAlign.center,
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
        for (final m in locked)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PixelPadlock(size: 10),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    unlockLine(s, m),
                    textAlign: TextAlign.center,
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
                ),
              ],
            ),
          ),
        if (inRun && locked.isNotEmpty && FarmIntensity.applies(s))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              s.metaDepth.farmTryUsesLeft > 0
                  ? 'Tap a locked tier to TRY it this room · '
                        '${s.metaDepth.farmTryUsesLeft} left'
                  : 'No TRY left.',
              textAlign: TextAlign.center,
              style: GameTheme.hint(color: GameTheme.parchmentDim),
            ),
          ),
      ],
    );
  }

  Widget _compact(GameState s, int current, List<int> locked) {
    return Column(
      key: pickerKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              header: true,
              label: title,
              excludeSemantics: true,
              child: Text(
                compactTitle,
                style: GameTheme.hint(color: GameTheme.torchHot),
              ),
            ),
            const SizedBox(width: 6),
            for (var i = 0; i < FarmIntensity.allowed.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _tier(s, FarmIntensity.allowed[i], current)),
            ],
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked.isNotEmpty) ...[
              const PixelPadlock(size: 10),
              const SizedBox(width: 4),
            ],
            // One line, so the town scene keeps its height (Robert,
            // "Fixa resten" item 5).
            Flexible(
              child: Text(
                locked.isEmpty
                    ? compactOpenLine
                    : compactUnlockLine(s, locked.first),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.hint(color: GameTheme.parchmentDim),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tier(GameState s, int mult, int current) {
    final canPick = FarmIntensity.canPick(s, mult);
    final canTry = inRun && FarmIntensity.canTry(s, mult);
    final selected = current == mult;
    final VoidCallback onTap = canPick
        ? () => director.setFarmIntensity(mult)
        : canTry
        ? () => director.tryFarmIntensity(mult)
        : () => director.showToast(unlockLine(s, mult), life: 2.4);
    final label = canPick
        ? 'FARM $mult×'
        : 'FARM $mult×, locked. ${unlockLine(s, mult)}';
    final face = ChunkyFace(
      key: tierKey(mult),
      tone: selected
          ? ChunkyTone.gold
          : canPick
          ? ChunkyTone.stone
          : ChunkyTone.grey,
      highlight: selected,
      raised: canPick || canTry,
      minHeight: GameTheme.minTouch - 6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!canPick) ...[
            const PixelPadlock(size: 10),
            const SizedBox(width: 4),
          ],
          Text(
            '$mult×',
            style: GameTheme.readable(
              color: selected
                  ? GameTheme.buyGoldText
                  : canPick
                  ? GameTheme.parchment
                  : GameTheme.parchmentDim,
            ),
          ),
        ],
      ),
    );
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        enabled: canPick || canTry,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            child: Center(
              child: SizedBox(width: double.infinity, child: face),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pixel padlock (no emoji font on device).
class PixelPadlock extends StatelessWidget {
  const PixelPadlock({super.key, this.size = 10, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.2),
      painter: _PadlockPainter(color ?? GameTheme.parchmentDim),
    );
  }
}

class _PadlockPainter extends CustomPainter {
  _PadlockPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 5;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    // Shackle: 3 px wide arch on a 5x6 grid.
    canvas.drawRect(Rect.fromLTWH(px, 0, px * 3, px), paint);
    canvas.drawRect(Rect.fromLTWH(px, 0, px, px * 2), paint);
    canvas.drawRect(Rect.fromLTWH(px * 3, 0, px, px * 2), paint);
    // Body.
    canvas.drawRect(Rect.fromLTWH(0, px * 2, size.width, px * 4), paint);
    // Keyhole.
    canvas.drawRect(
      Rect.fromLTWH(px * 2, px * 3, px, px * 2),
      Paint()
        ..color = GameTheme.stoneDeep
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_PadlockPainter old) => old.color != color;
}
