import 'dart:io';

Future<String?> writeSaveShareFile(String json) async {
  final path =
      '${Directory.systemTemp.path}/idle_party_save_${DateTime.now().millisecondsSinceEpoch}.json';
  await File(path).writeAsString(json);
  return path;
}