import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:idle_party/ui/game_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UI fonts are bundled and runtime fetch stays off', () async {
    expect(bundledGoogleFonts, isTrue);
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);

    final assets = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets();
    expect(
      assets.any((path) => path.endsWith('PressStart2P-Regular.ttf')),
      isTrue,
    );
    expect(assets.any((path) => path.endsWith('VT323-Regular.ttf')), isTrue);
    expect(assets.any((path) => path.endsWith('Cinzel-Bold.ttf')), isTrue);

    await GoogleFonts.pendingFonts([
      GoogleFonts.pressStart2p(fontSize: 12),
      GoogleFonts.vt323(fontSize: 17, fontWeight: FontWeight.w600),
      GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700),
      GoogleFonts.vt323TextTheme(ThemeData.dark().textTheme),
    ]);
  });
}
