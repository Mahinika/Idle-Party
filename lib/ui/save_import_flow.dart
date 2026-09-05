import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';

/// Clipboard save import shared by title RESTORE SAVE and MORE → SETTINGS.
abstract final class SaveImportFlow {
  static Future<bool> fromClipboard({
    required BuildContext context,
    required GameDirector director,
  }) async {
    final data = await Clipboard.getData('text/plain');
    final raw = data?.text;
    if (raw == null || raw.isEmpty) {
      director.showToast('Clipboard is empty');
      return false;
    }
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Import save?',
        content: Text(
          'This replaces your current save with the clipboard contents. '
          'This cannot be undone.',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          MenuChrome.dialogCancel(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GameButton(
            label: 'IMPORT',
            style: GameButtonStyle.red,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    final success = director.importSaveJson(raw);
    director.showToast(success ? 'Save imported' : 'Could not read that save');
    return success;
  }
}
