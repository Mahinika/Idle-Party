/// Local party-name gate: length, charset, and an owned block list.
///
/// Empty input becomes [defaultName]. Blocked names return null — callers
/// show a generic "choose another" line and never echo the match.
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
  static String? sanitize(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return defaultName;
    if (trimmed.length < minLen || trimmed.length > maxLen) return null;
    if (!_allowedChars.hasMatch(trimmed)) return null;
    if (_urlLike.hasMatch(trimmed.replaceAll(' ', ''))) return null;
    if (isBlocked(trimmed)) return null;
    return trimmed;
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
    'spic',
    'chink',
    'wetback',
    'trany',
    'tranny',
    '1488',
    'nazi',
    'fascis',
    'maga',
    'antifa',
    'democrat',
    'republican',
    'communist',
    'hitler',
  ];
}
