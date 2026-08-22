import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'web_click_bridge_stub.dart'
    if (dart.library.js_interop) 'web_click_bridge_web.dart';

/// Web automation bridge: label clicks + coordinate taps.
///
/// Cursor's browser tools often cannot deliver trusted CDP mouse events to
/// Flutter CanvasKit. Buttons register here; DOM clicks on semantics nodes
/// (and `window.__idlePartyClick`) invoke the matching [VoidCallback].
///
/// [pushLayer] / [popLayer] scope registrations so hub buttons under a forge
/// overlay (or dialog) are not listed or invoked while the modal is open.
abstract final class WebClickBridge {
  static final Map<String, _Entry> _byKey = <String, _Entry>{};
  static int _pointerSeq = 900000;
  static bool _installed = false;
  static int _layer = 0;
  static double Function()? _getSpeed;
  static void Function(double scale)? _setSpeed;

  /// Wire [GameDirector] speed controls after boot (web playtests).
  static void bindSpeedControls({
    required double Function() getSpeed,
    required void Function(double scale) setSpeed,
  }) {
    _getSpeed = getSpeed;
    _setSpeed = setSpeed;
  }

  static void install() {
    if (_installed || !kIsWeb) return;
    _installed = true;
    installWebClickBridge(
      _invoke,
      _tapAt,
      _listButtons,
      () => _getSpeed?.call() ?? 1,
      (scale) {
        _setSpeed?.call(scale);
        return _getSpeed?.call() ?? scale;
      },
    );
  }

  /// Begin a modal / overlay click scope (hub meta shell, dialogs, sheets).
  static void pushLayer() {
    if (!kIsWeb) return;
    _layer++;
  }

  /// End the current modal scope and drop its registrations.
  static void popLayer() {
    if (!kIsWeb) return;
    if (_layer <= 0) return;
    final dying = _layer;
    _layer--;
    _byKey.removeWhere((_, e) => e.layer == dying);
  }

  static String _key(String label) =>
      label.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  static int get currentLayer => _layer;

  static void register(String label, VoidCallback? onPressed, {int? layer}) {
    if (!kIsWeb) return;
    final key = _key(label);
    if (key.isEmpty) return;
    final at = layer ?? _layer;
    if (onPressed == null) {
      final existing = _byKey[key];
      if (existing != null && existing.layer == at) {
        _byKey.remove(key);
      }
      return;
    }
    _byKey[key] = _Entry(label: label, onPressed: onPressed, layer: at);
  }

  static void unregister(String label) {
    if (!kIsWeb) return;
    // Always drop by label — dispose may run after popLayer moved _layer.
    _byKey.remove(_key(label));
  }

  static Iterable<_Entry> get _activeEntries =>
      _byKey.values.where((e) => e.layer == _layer);

  static VoidCallback? _resolve(String raw) {
    final key = _key(raw);
    if (key.isEmpty) return null;
    final exact = _byKey[key];
    if (exact != null && exact.layer == _layer) return exact.onPressed;

    // Prefix match for dynamic labels ("BAG 0", multiline picker) — not broad
    // contains, which stole taps from unrelated buttons on web.
    _Entry? best;
    var bestLen = -1;
    for (final e in _activeEntries) {
      final ek = _key(e.label);
      if (key.startsWith(ek) || ek.startsWith(key)) {
        if (ek.length > bestLen) {
          best = e;
          bestLen = ek.length;
        }
      }
    }
    return best?.onPressed;
  }

  static bool _invoke(String label) {
    final cb = _resolve(label);
    if (cb == null) return false;
    // After the browser event unwinds so setState/navigation is safe.
    scheduleMicrotask(cb);
    return true;
  }

  static void _tapAt(double x, double y) {
    final pointer = ++_pointerSeq;
    final pos = Offset(x, y);
    final stamp = Duration(
      microseconds: DateTime.now().microsecondsSinceEpoch & 0x7fffffff,
    );
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: pos,
        timeStamp: stamp,
        kind: PointerDeviceKind.touch,
      ),
    );
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: pos,
        timeStamp: stamp,
        kind: PointerDeviceKind.touch,
      ),
    );
  }

  static String _listButtons() {
    final labels = _activeEntries.map((e) => e.label).toList()..sort();
    return labels.join(' | ');
  }
}

class _Entry {
  const _Entry({
    required this.label,
    required this.onPressed,
    required this.layer,
  });
  final String label;
  final VoidCallback onPressed;
  final int layer;
}

/// Registers [label] → [onPressed] while mounted (web automation).
class WebClickScope extends StatefulWidget {
  const WebClickScope({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<WebClickScope> createState() => _WebClickScopeState();
}

class _WebClickScopeState extends State<WebClickScope> {
  String? _registeredLabel;

  /// Layer at first mount — keep underlay buttons on layer 0 when a modal
  /// pushes a higher layer and the parent rebuilds.
  late final int _mountLayer;

  void _sync() {
    if (_registeredLabel != null && _registeredLabel != widget.label) {
      WebClickBridge.unregister(_registeredLabel!);
      _registeredLabel = null;
    }
    if (widget.onPressed != null) {
      WebClickBridge.register(
        widget.label,
        widget.onPressed,
        layer: _mountLayer,
      );
      _registeredLabel = widget.label;
    } else if (_registeredLabel != null) {
      WebClickBridge.unregister(_registeredLabel!);
      _registeredLabel = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _mountLayer = WebClickBridge.currentLayer;
    _sync();
  }

  @override
  void didUpdateWidget(WebClickScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    if (_registeredLabel != null) {
      WebClickBridge.unregister(_registeredLabel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
