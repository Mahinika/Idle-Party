import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/town_life.dart';
import 'package:idle_party/ui/shell/home/town_scene.dart';

void main() {
  void expectPacked(Size size, {double textScale = 1, bool wantFolk = true}) {
    final layout = TownSceneLayout.pack(size, textScale: textScale);
    final hits = layout.hitTargets;
    expect(hits, hasLength(5));
    for (var i = 0; i < hits.length; i++) {
      final hit = hits[i];
      expect(hit.width, greaterThanOrEqualTo(GameTheme.minTouch), reason: '$size $hit');
      expect(hit.height, greaterThanOrEqualTo(GameTheme.minTouch), reason: '$size $hit');
      expect(hit.left, greaterThanOrEqualTo(-1), reason: '$hit');
      expect(hit.top, greaterThanOrEqualTo(-1), reason: '$hit');
      expect(hit.right, lessThanOrEqualTo(size.width + 1));
      expect(hit.bottom, lessThanOrEqualTo(size.height + 1));
      for (var j = i + 1; j < hits.length; j++) {
        expect(hit.overlaps(hits[j]), isFalse, reason: '$hit vs ${hits[j]}');
      }
    }
    expect(layout.well.overlaps(layout.guild), isFalse, reason: 'well/guild');
    expect(layout.well.overlaps(layout.vault), isFalse, reason: 'well/vault');
    for (final front in layout.front) {
      expect(layout.well.overlaps(front), isFalse, reason: 'well/front');
    }
    expect(layout.lane.overlaps(layout.guild), isFalse);
    expect(layout.lane.overlaps(layout.vault), isFalse);
    for (final front in layout.front) {
      expect(layout.lane.overlaps(front), isFalse, reason: 'lane/front');
    }
    final buildings = [layout.guild, layout.vault, ...layout.front];
    final labels = layout.labels;
    expect(labels, hasLength(5));
    for (var i = 0; i < labels.length; i++) {
      expect(
        buildings[i].contains(labels[i].center),
        isTrue,
        reason: 'label off the facade ${labels[i]} ${buildings[i]}',
      );
      expect(layout.lane.overlaps(labels[i]), isFalse, reason: 'label in the yard');
      for (var j = i + 1; j < labels.length; j++) {
        expect(labels[i].overlaps(labels[j]), isFalse);
      }
    }
    expect(layout.party.overlaps(layout.lane), isFalse);
    for (final hit in hits) {
      expect(layout.party.overlaps(hit), isFalse, reason: 'party on a building');
    }
    if (wantFolk) {
      expect(layout.folkScale, greaterThan(0), reason: '$size');
      expect(layout.lane.width, greaterThan(70));
    }
  }

  test('A56 square keeps labels on the buildings and the yard clear', () {
    expectPacked(const Size(360, 480));
    expectPacked(const Size(360, 420), textScale: 1.45);
    expectPacked(const Size(360, 460), textScale: 2);
  });

  test('short and narrow squares still separate the taps', () {
    expectPacked(const Size(360, 340), wantFolk: true);
    expectPacked(const Size(360, 280), textScale: 2, wantFolk: false);
    expectPacked(const Size(320, 300), wantFolk: false);
  });

  test('folk poses are deterministic and idle when motion is off', () {
    final still = townFolkFrames(0.4, moving: false);
    expect(still.every((f) => f.column == 0 && f.bob == 0), isTrue);
    final a = townFolkFrames(0, moving: true);
    final b = townFolkFrames(0.22, moving: true);
    expect(a.first.u, isNot(closeTo(b.first.u, 0.05)));
    expect(a.first.column, inInclusiveRange(1, 4));
    expect(townFolkFrames(0, moving: true).first.u, townFolkFrames(0, moving: true).first.u);
    expect(
      townFolkMotionEnabled(quality: VfxQuality.minimal, disableAnimations: false),
      isFalse,
    );
    expect(
      townFolkMotionEnabled(quality: VfxQuality.full, disableAnimations: true),
      isFalse,
    );
    expect(
      townFolkMotionEnabled(quality: VfxQuality.lite, disableAnimations: false),
      isTrue,
    );
  });
}
