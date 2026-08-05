import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Installs `window.__idlePartyClick` / `__idlePartyTap` / `__idlePartyButtons`
/// / `__idlePartySetSpeed` / `__idlePartyGetSpeed` and a capture-phase DOM hook.
void installWebClickBridge(
  bool Function(String label) onClick,
  void Function(double x, double y) onTap,
  String Function() listButtons,
  double Function() getSpeed,
  double Function(double scale) setSpeed,
) {
  globalContext.setProperty(
    '__idlePartyClick'.toJS,
    ((JSAny? label) {
      final s = label == null ? '' : (label.dartify()?.toString() ?? '');
      return onClick(s).toJS;
    }).toJS,
  );
  globalContext.setProperty(
    '__idlePartyTap'.toJS,
    ((JSAny? x, JSAny? y) {
      final dx = (x?.dartify() as num?)?.toDouble() ?? 0;
      final dy = (y?.dartify() as num?)?.toDouble() ?? 0;
      onTap(dx, dy);
    }).toJS,
  );
  globalContext.setProperty(
    '__idlePartyButtons'.toJS,
    (() => listButtons().toJS).toJS,
  );
  globalContext.setProperty(
    '__idlePartyGetSpeed'.toJS,
    (() => getSpeed().toJS).toJS,
  );
  globalContext.setProperty(
    '__idlePartySetSpeed'.toJS,
    ((JSAny? scale) {
      final n = (scale?.dartify() as num?)?.toDouble() ?? 1;
      return setSpeed(n).toJS;
    }).toJS,
  );

  // Install capture-phase click → __idlePartyClick bridge.
  globalContext.callMethod('eval'.toJS, _domHookSource.toJS);
}

const _domHookSource = r'''
(function () {
  if (window.__idlePartyDomHooked) return;
  window.__idlePartyDomHooked = true;

  function labelOf(el) {
    return (el.getAttribute('aria-label') || el.textContent || '').trim();
  }

  function buttonFromEvent(e) {
    var el = e.target;
    while (el && el !== document) {
      if (el.tagName === 'FLT-SEMANTICS' && el.getAttribute('role') === 'button') {
        return el;
      }
      el = el.parentElement;
    }
    return null;
  }

  document.addEventListener('click', function (e) {
    var btn = buttonFromEvent(e);
    if (!btn) return;
    if (btn.getAttribute('aria-disabled') === 'true') return;
    if (typeof window.__idlePartyClick !== 'function') return;
    var ok = window.__idlePartyClick(labelOf(btn));
    if (ok) {
      e.preventDefault();
      e.stopImmediatePropagation();
    }
  }, true);
})();
''';
