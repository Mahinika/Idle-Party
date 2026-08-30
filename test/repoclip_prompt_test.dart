import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/ui/custom_assets.dart';

void main() {
  test('RepoClip prompt stays under 500 chars and matches intro beats', () {
    final prompt = File('docs/REPOCLIP_PROMPT.txt').readAsStringSync().trim();
    expect(prompt.length, lessThanOrEqualTo(500));
    expect(prompt.length, greaterThan(200));
    final lower = prompt.toLowerCase();
    expect(lower, contains('cave mouth'));
    expect(lower, contains('loot'));
    expect(lower, contains('tap the map'));
    expect(lower, contains('first boss'));
    expect(lower, isNot(contains('github')));
    expect(lower, isNot(contains('keystone')));
    expect(lower, isNot(contains('subscribe')));
    expect(lower, isNot(contains('download')));
    expect(lower, contains('pixel'));
  });

  test('trailer brief matches cold-start lore and bans feature soup', () {
    final trailer = File('docs/TRAILER.md').readAsStringSync().toLowerCase();
    expect(trailer, contains('cave mouth'));
    expect(trailer, contains(StoryLore.introTagline.toLowerCase()));
    expect(trailer, contains('no other game'));
    expect(trailer, isNot(contains('keystone')));
    expect(trailer, isNot(contains('gauntlet')));
    expect(trailer, isNot(contains('31 spec')));
  });

  test('boot cinematic stays unbundled until the approved MP4 lands', () {
    expect(CustomAssets.introVideoBundled, isFalse);
    expect(CustomAssets.introVideo, 'assets/video/boot_intro.mp4');
    expect(File('assets/video/boot_intro.mp4').existsSync(), isFalse);
  });
}
