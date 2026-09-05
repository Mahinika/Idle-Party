import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/game_icon.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/menu_chrome.dart';

/// Keeps chrome on one theme stack: tokens in GameTheme, pixel icons, no
/// Material Icons / TextButton / emoji / raw hex in menus.
void main() {
  final uiRoot = Directory('lib/ui');

  Iterable<File> dartFiles() => uiRoot
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  const vfxAllow = <String>{
    'spatial_dungeon_view.dart',
    'dungeon_environment.dart',
    'cave_atmosphere.dart',
  };

  final hexColor = RegExp(r'Color\(0x[0-9A-Fa-f]+');
  final materialIcon = RegExp(r'\bIcons\.');
  final textButton = RegExp(r'\bTextButton\s*\(');
  final chromeEmoji = RegExp(r'[🔑⚔◈◆★]');
  final materialBlack = RegExp(r'Colors\.black');

  final choiceChip = RegExp(r'\bChoiceChip\s*\(');
  final expansionTile = RegExp(r'\bExpansionTile\s*\(');

  test('lib/ui chrome does not use Material Icons, TextButton, ChoiceChip, or ExpansionTile', () {
    for (final file in dartFiles()) {
      final text = file.readAsStringSync();
      expect(
        materialIcon.hasMatch(text),
        isFalse,
        reason: '${file.path} uses Icons. — use GameIcon / UiIcon',
      );
      expect(
        textButton.hasMatch(text),
        isFalse,
        reason: '${file.path} uses TextButton — use GameButton / MenuChrome.dialog',
      );
      expect(
        choiceChip.hasMatch(text),
        isFalse,
        reason: '${file.path} uses ChoiceChip — use MenuChrome.segmented / chip',
      );
      expect(
        expansionTile.hasMatch(text),
        isFalse,
        reason: '${file.path} uses ExpansionTile — use MenuChrome.fold',
      );
    }
  });

  test('raw Color(0x) lives in GameTheme or combat VFX files', () {
    for (final file in dartFiles()) {
      final name = file.uri.pathSegments.last;
      if (name == 'game_theme.dart') continue;
      if (vfxAllow.contains(name)) continue;
      final text = file.readAsStringSync();
      expect(
        hexColor.hasMatch(text),
        isFalse,
        reason: '${file.path} has Color(0x) — add a GameTheme token',
      );
    }
  });

  test('chrome copy has no emoji marks', () {
    for (final file in dartFiles()) {
      expect(
        chromeEmoji.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: '${file.path} still has emoji chrome — use GameIcon / plain text',
      );
    }
    for (final path in [
      'lib/core/chase_dispatcher.dart',
      'lib/ui/hub_screen.dart',
      'lib/core/game_director.dart',
    ]) {
      expect(
        chromeEmoji.hasMatch(File(path).readAsStringSync()),
        isFalse,
        reason: '$path still has emoji chrome',
      );
    }
  });

  test('lib/ui does not use Colors.black (except combat VFX)', () {
    for (final file in dartFiles()) {
      final name = file.uri.pathSegments.last;
      if (vfxAllow.contains(name)) continue;
      expect(
        materialBlack.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: '${file.path} uses Colors.black — use GameTheme.ink / shadow',
      );
    }
  });

  test('UiIcon sprites exist on disk', () {
    for (final path in [
      UiIcon.gear,
      UiIcon.power,
      UiIcon.quests,
      UiIcon.trophy,
      UiIcon.more,
      UiIcon.leave,
      UiIcon.gold,
      UiIcon.essence,
      UiIcon.ascend,
      UiIcon.star,
      UiIcon.heart,
      UiIcon.skull,
      UiIcon.flask,
      UiIcon.flaskBlue,
      UiIcon.ring,
      UiIcon.shieldRound,
      UiIcon.settings,
      UiIcon.key,
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('MenuChrome surfaces alias GameTheme tokens', () {
    expect(MenuChrome.scrim, GameTheme.scrim);
    expect(MenuChrome.sheet, GameTheme.sheet);
    expect(MenuChrome.hudWell().color, GameTheme.hudWell);
    expect(GameTheme.buttonBrownTop, isNot(GameTheme.buttonGreyTop));
  });
}
