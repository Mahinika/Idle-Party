
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/game_director.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../save_import_flow.dart';
import 'save_share_file_stub.dart'
    if (dart.library.io) 'save_share_file_io.dart'
    as save_share;

/// Save export/import — clipboard JSON, no servers involved.
class SaveTransferSection extends StatelessWidget {
  const SaveTransferSection({super.key, required this.director});
  final GameDirector director;

  Future<void> _export(BuildContext context) async {
    final json = director.exportSaveJson();
    await Clipboard.setData(ClipboardData(text: json));
    director.showToast('Save copied to clipboard');
  }

  Future<void> _share(BuildContext context) async {
    final json = director.exportSaveJson();
    final path = await save_share.writeSaveShareFile(json);
    if (path != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              path,
              mimeType: 'application/json',
              name: 'idle_party_save.json',
            ),
          ],
          subject: 'Idle Party save',
        ),
      );
    } else {
      await SharePlus.instance.share(
        ShareParams(text: json, subject: 'Idle Party save'),
      );
    }
    director.showToast('Save ready to share');
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
          style: GameTheme.section(color: GameTheme.parchmentDim),
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
                label: 'SHARE',
                style: GameButtonStyle.grey,
                onPressed: () => _share(context),
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
          'Export copies JSON to clipboard. Share sends a .json file through the system sheet.',
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
      ],
    );
  }
}