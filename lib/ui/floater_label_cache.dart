import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'game_theme.dart';

/// Layout cache for combat floater text. Fill and outline are two painters.
///
/// Never disposes a painter that may still be used this frame. Lookups may
/// temporarily go over [cap]. Dispose is deferred to the next [beginFrame]
/// (after the previous picture has been recorded) so a just-painted paragraph
/// is not released mid-flush. Eviction drops unused keys first, then the LRU
/// tail, back down to [cap]. The cap is required: keys include snapped alpha,
/// tile size, and the damage text.
abstract final class FloaterLabelCache {
  @visibleForTesting
  static const int cap = 24;

  static final LinkedHashMap<String, TextPainter> _cache =
      LinkedHashMap<String, TextPainter>();

  static final Set<String> _usedThisFrame = <String>{};

  @visibleForTesting
  static int get length => _cache.length;

  /// Marks the start of a paint frame. The previous frame's picture is
  /// finished, so it is now safe to evict down to [cap].
  static void beginFrame() {
    _evictToCap();
    _usedThisFrame.clear();
  }

  /// Ends a paint frame. Does not dispose — the recorder may still hold
  /// paragraphs from this frame until the next [beginFrame].
  static void endFrame() {
    // Dispose is deferred to the next beginFrame.
  }

  static void _evictToCap() {
    if (_cache.length > cap) {
      final unused = <String>[];
      for (final key in _cache.keys) {
        if (!_usedThisFrame.contains(key)) unused.add(key);
      }
      for (final key in unused) {
        if (_cache.length <= cap) break;
        _cache.remove(key)?.dispose();
      }
    }
    while (_cache.length > cap && _cache.isNotEmpty) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest)?.dispose();
    }
  }

  /// Disposes every cached painter. Safe to call twice (no double-dispose).
  @visibleForTesting
  static void reset() {
    for (final painter in _cache.values) {
      painter.dispose();
    }
    _cache.clear();
    _usedThisFrame.clear();
  }

  static String _key({
    required String text,
    required double size,
    required Color color,
    required double maxWidth,
  }) {
    return '${size.toStringAsFixed(2)}|${color.toARGB32()}|'
        '${maxWidth.toStringAsFixed(1)}|$text';
  }

  /// One fill or outline painter. Marks the key as used this frame and never
  /// evicts an in-frame painter; the cache may grow past [cap] until the next [beginFrame].
  static TextPainter of({
    required String text,
    required double size,
    required Color color,
    required double maxWidth,
  }) {
    final key = _key(
      text: text,
      size: size,
      color: color,
      maxWidth: maxWidth,
    );
    _usedThisFrame.add(key);
    final hit = _cache.remove(key);
    if (hit != null) {
      // LRU: a hit moves to the newest end so a hot key survives end-of-frame
      // eviction when the cache is over cap.
      _cache[key] = hit;
      return hit;
    }
    while (_cache.length >= cap && _cache.isNotEmpty) {
      final oldest = _cache.keys.firstWhere(
        (k) => !_usedThisFrame.contains(k),
        orElse: () => '',
      );
      if (oldest.isEmpty) break;
      _cache.remove(oldest)?.dispose();
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: GameTheme.pixelCached(size: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    _cache[key] = painter;
    return painter;
  }

  /// Fill and outline painters for one floater. Either [of] call may miss;
  /// neither lookup can dispose a painter still referenced this frame.
  static ({TextPainter fill, TextPainter outline}) pair({
    required String text,
    required double size,
    required Color color,
    required Color outline,
    required double maxWidth,
  }) {
    return (
      fill: of(text: text, size: size, color: color, maxWidth: maxWidth),
      outline: of(text: text, size: size, color: outline, maxWidth: maxWidth),
    );
  }
}
