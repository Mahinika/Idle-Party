import 'dart:convert';

/// Local party-name gate: length, charset, and an owned block list.
///
/// Empty input becomes [defaultName]. Blocked names return null — callers
/// show a generic "choose another" line and never echo the match.
///
/// [scoreTag] packs a clean name into the Play Games score tag (URI-safe,
/// at most 64 characters) so season ranks can show the party, not the
/// Google account name.
abstract final class PartyNameFilter {
  static const String defaultName = 'The Party';
  static const int minLen = 2;
  static const int maxLen = 16;

  static final RegExp _allowedChars = RegExp(
    r"^[\p{L}\p{N} '\-]+$",
    unicode: true,
  );
  static final RegExp _urlLike = RegExp(
    r'https?|www\.|\.[a-z]{2,}$',
    caseSensitive: false,
  );

  /// Trim, collapse spaces, apply default, or null if illegal / blocked.
  ///
  /// [whenEmpty] replaces [defaultName] for a blank field (pet rename resets
  /// to the species name).
  static String? sanitize(String raw, {String? whenEmpty}) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return whenEmpty ?? defaultName;
    if (trimmed.length < minLen || trimmed.length > maxLen) return null;
    if (!_allowedChars.hasMatch(trimmed)) return null;
    if (_urlLike.hasMatch(trimmed.replaceAll(' ', ''))) return null;
    if (isBlocked(trimmed)) return null;
    return trimmed;
  }

  /// Play score tag for [raw], or the default party when [raw] is empty.
  /// Null only if even the default name cannot be packed.
  static String? scoreTag(String raw) {
    final name = sanitize(raw) ?? defaultName;
    return _encodeTag(name) ?? _encodeTag(defaultName);
  }

  /// Party name stored in a Play score tag, or null when missing / blocked.
  static String? partyNameFromScoreTag(String? tag) {
    if (tag == null) return null;
    final clean = tag.trim();
    if (clean.isEmpty || clean.length > 64) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(clean)) return null;
    try {
      var padded = clean;
      final mod = padded.length % 4;
      if (mod != 0) padded += '=' * (4 - mod);
      final decoded = utf8.decode(base64Url.decode(padded));
      return sanitize(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Name to print on a rank row. Prefers the score tag, then this device's
  /// party, then the account name. Blocked text becomes `Player`.
  static String publicLabel(
    String raw, {
    String? scoreTag,
    String? fallbackParty,
  }) {
    final fromTag = partyNameFromScoreTag(scoreTag);
    if (fromTag != null) return fromTag;
    if (fallbackParty != null) {
      final local = sanitize(fallbackParty);
      if (local != null) return local;
    }
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty || isBlocked(trimmed)) return 'Player';
    return trimmed;
  }

  static String? _encodeTag(String name) {
    final tag = base64Url.encode(utf8.encode(name)).replaceAll('=', '');
    if (tag.isEmpty || tag.length > 64) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(tag)) return null;
    return tag;
  }

  static bool isBlocked(String raw) {
    final tokens = _tokens(raw);
    for (final token in tokens) {
      final collapsed = _collapseRepeats(token);
      if (_allow.contains(token) || _allow.contains(collapsed)) continue;
      if (_shortBanned.contains(token) || _shortBanned.contains(collapsed)) {
        return true;
      }
      if (_longHit(token) || _longHit(collapsed)) return true;
    }
    return _longHit(_compact(raw)) || _longHit(_compact(raw, collapse: true));
  }

  static bool _longHit(String compact) {
    if (compact.isEmpty) return false;
    for (final word in _longBanned) {
      if (compact.contains(word)) return true;
    }
    return false;
  }

  static List<String> _tokens(String raw) {
    final compact = _leet(raw.toLowerCase());
    return [
      for (final part in compact.split(RegExp(r'[^a-z0-9]+')))
        if (part.isNotEmpty) part,
    ];
  }

  static String _compact(String raw, {bool collapse = false}) {
    final s = _leet(raw.toLowerCase()).replaceAll(RegExp(r'[^a-z0-9]'), '');
    return collapse ? _collapseRepeats(s) : s;
  }

  static String _leet(String s) {
    const map = <String, String>{
      '@': 'a',
      '0': 'o',
      '1': 'i',
      '!': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      r'$': 's',
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'ā': 'a',
      'ç': 'c',
      'ć': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ø': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      // Latin lookalikes so a mixed-script slogan still matches.
      'а': 'a',
      'е': 'e',
      'о': 'o',
      'р': 'p',
      'с': 'c',
      'у': 'y',
      'х': 'x',
      'і': 'i',
      'ѕ': 's',
      'һ': 'h',
    };
    final buf = StringBuffer();
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(map[ch] ?? ch);
    }
    return buf
        .toString()
        .replaceAll('\u200b', '')
        .replaceAll('\u200c', '')
        .replaceAll('\u200d', '')
        .replaceAll('\ufeff', '');
  }

  static String _collapseRepeats(String s) {
    if (s.length < 2) return s;
    final buf = StringBuffer(s[0]);
    for (var i = 1; i < s.length; i++) {
      if (s[i] != s[i - 1]) buf.write(s[i]);
    }
    return buf.toString();
  }

  static const Set<String> _allow = {
    'class',
    'classic',
    'bass',
    'assistant',
    'grape',
    'cocktail',
    'scunthorpe',
    'helfire',
    'hellfire',
    'pass',
    'glass',
    'grass',
    'mass',
    'assess',
    'assassin',
  };

  /// Short tokens — whole word only (avoids Scunthorpe).
  static const Set<String> _shortBanned = {
    'ass',
    'hell',
    'damn',
    'tit',
    'cock',
    'dick',
    'piss',
    'crap',
    'slut',
    'whore',
    'sex',
    'spic',
    'coon',
    'gook',
    'paki',
    'beaner',
    'negro',
    'heil',
    'kkk',
    'ss',
    'isis',
    'hamas',
    'blm',
    'maga',
    'antifa',
    'trump',
    'biden',
    'putin',
    'stalin',
    'lenin',
    'marx',
    'woke',
    'tory',
    'labour',
    'labor',
    'liberal',
  };

  /// Longer swears, slurs, hate codes, political slogans — substring after
  /// normalize. Keep this list owned and modest; extend when something slips.
  static const List<String> _longBanned = [
    'fuck',
    'shit',
    'bitch',
    'bastard',
    'cunt',
    'nigger',
    'nigga',
    'fagot',
    'faggot',
    'retard',
    'kike',
    'chink',
    'wetback',
    'trany',
    'tranny',
    '1488',
    'nazi',
    'fascis',
    'democrat',
    'republican',
    'communist',
    'kommunist',
    'demokrat',
    'republikan',
    'socialis',
    'hitler',
    'swastika',
    'siegheil',
    'whitepower',
    'whitesuprem',
    'aryan',
    'kuklux',
    'raghead',
    'towelhead',
    'marxist',
    'altright',
    'farright',
    'farleft',
    'jihad',
    'illiberal',
  ];
}
