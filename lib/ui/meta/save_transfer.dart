
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/game_director.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../save_import_flow.dart';

/// Save export/import — clipboard JSON, no servers involved.
class SaveTransferSection extends StatelessWidget {
  const SaveTransferSection({super.key, required this.director});
  final GameDirector director;

  Future<void> _export(BuildContext context) async {
    final json = director.exportSaveJson();
    await Clipboard.setData(ClipboardData(text: json));
    director.showToast('Save copied to clipboard');
  }

  Future<void> _import(BuildContext context) async {
    await SaveImportFlow.fromClipboard(context: context, director: director);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Save transfer (clipboard)',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'EXPORT',
                style: GameButtonStyle.grey,
                onPressed: () => _export(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: 'IMPORT',
                style: GameButtonStyle.grey,
                onPressed: () => _import(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Export copies JSON to clipboard — paste somewhere safe as a backup.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
      ],
    );
  }
}
