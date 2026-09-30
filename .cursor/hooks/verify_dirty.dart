/// Per-chat edit list for the stop hook.
///
/// One file used to hold every chat's edits. Whichever chat finished next
/// got the "commit these files" nudge. Entries are keyed by conversation id
/// so the nudge stays in the chat that saved the files.
import 'dart:convert';
import 'dart:io';

const verifyDirtyPath = '.cursor/hooks/.verify-dirty';

String? conversationId(Map<String, dynamic> payload) {
  for (final key in <String>[
    'conversation_id',
    'conversationId',
    'session_id',
  ]) {
    final v = payload[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

Map<String, List<String>> readDirty() {
  final file = File(verifyDirtyPath);
  if (!file.existsSync()) return <String, List<String>>{};
  final raw = file.readAsStringSync().trim();
  if (raw.isEmpty) return <String, List<String>>{};
  if (!raw.startsWith('{')) {
    // Old shared list. Drop it so a different chat cannot be nudged.
    try {
      file.deleteSync();
    } catch (_) {}
    return <String, List<String>>{};
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, List<String>>{};
    final byChat = decoded['byChat'];
    if (byChat is! Map) return <String, List<String>>{};
    final out = <String, List<String>>{};
    for (final entry in byChat.entries) {
      final id = entry.key.toString();
      final paths = entry.value;
      if (paths is! List) continue;
      final clean = <String>[
        for (final p in paths)
          if (p is String && p.trim().isNotEmpty) p.trim(),
      ];
      if (clean.isNotEmpty) out[id] = clean;
    }
    return out;
  } catch (_) {
    return <String, List<String>>{};
  }
}

void writeDirty(Map<String, List<String>> byChat) {
  final file = File(verifyDirtyPath);
  if (byChat.isEmpty) {
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    return;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    jsonEncode(<String, dynamic>{
      'byChat': <String, List<String>>{
        for (final e in byChat.entries) e.key: e.value,
      },
    }),
  );
}

void addDirtyPath(String chatId, String path) {
  final byChat = readDirty();
  final paths = byChat.putIfAbsent(chatId, () => <String>[]);
  if (!paths.contains(path)) paths.add(path);
  writeDirty(byChat);
}

/// Paths this chat edited. Does not remove them.
List<String> dirtyPathsFor(String chatId) {
  return List<String>.from(readDirty()[chatId] ?? const <String>[]);
}

/// Drop this chat's entry after a green check, so the nudge fires once.
void clearDirtyChat(String chatId) {
  final byChat = readDirty();
  if (byChat.remove(chatId) == null) return;
  writeDirty(byChat);
}
