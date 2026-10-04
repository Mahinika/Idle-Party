import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/changelog.dart';

void main() {
  test('Play listing plan leads with first-minute combat', () {
    final md = File('docs/STORE_LISTING.md').readAsStringSync();
    final plan = md.split('### Screenshot plan').last.split('## How we capture')[0];
    expect(plan, contains('out/01_01_combat_a.png'));
    expect(plan, contains('out/02_02_combat_b.png'));
    expect(plan, contains('out/03_03_hub_today.png'));
    expect(plan, contains('Your party fights on its own'));
    expect(plan, contains('They keep fighting while you are away'));
    expect(plan, isNot(contains('| 1 | `marketing/02_todays_chase')));
    expect(plan, isNot(contains('| 2 | `marketing/')));
    expect(plan, isNot(contains('| 3 | `marketing/')));
    expect(plan, isNot(contains('08_keystone')));
  });

  test('preview video opens on the Sandy crawl, not endgame', () {
    final py = File('tool/store_listing/build_preview_video.py').readAsStringSync();
    // The list sits above FPS. Later `len(BEATS)` is the loop, not the plan.
    final listAt = py.indexOf('BEATS');
    final fpsAt = py.indexOf('FPS =', listAt);
    final block = py.substring(listAt, fpsAt < 0 ? py.length : fpsAt);
    final beats = RegExp(
      r'\(\s*([0-9.]+)\s*,\s*"(preview/[^"]+)"',
    ).allMatches(block).toList();
    expect(beats.length, greaterThanOrEqualTo(2));
    expect(beats.first.group(2), 'preview/gameplay_crawl_raw.mp4');
    expect(double.parse(beats.first.group(1)!), greaterThanOrEqualTo(8));
    for (final beat in beats.take(2)) {
      final clip = beat.group(2)!;
      expect(clip.contains('gauntlet'), isFalse, reason: clip);
      expect(clip.contains('_gr_'), isFalse, reason: clip);
      expect(clip.contains('hell'), isFalse, reason: clip);
    }
  });

  test('listing assets are within one patch of the live version', () {
    final md = File('docs/PLAY_STORE.md').readAsStringSync();
    final row = RegExp(
      r'Listing assets freshness \| ([^\|]+)',
    ).firstMatch(md);
    expect(row, isNotNull, reason: 'PLAY_STORE.md freshness row');
    final versions = RegExp(r'(\d+\.\d+\.\d+)')
        .allMatches(row!.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
    expect(versions, hasLength(4));
    final live = ChangelogCatalog.currentVersion.split('.');
    expect(live, hasLength(3));
    final livePatch = int.parse(live[2]);
    for (final listed in versions) {
      final parts = listed.split('.');
      expect(parts[0], live[0], reason: listed);
      expect(parts[1], live[1], reason: listed);
      final drift = (int.parse(parts[2]) - livePatch).abs();
      expect(drift, lessThanOrEqualTo(1), reason: '$listed vs ${live.join('.')}');
    }
  });
}
