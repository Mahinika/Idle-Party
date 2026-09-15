import 'dart:async';

import 'package:flutter/material.dart';

import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Simple ENTER picker: left arrow · number · right arrow.
class RiftTierPickerDialog extends StatefulWidget {
  const RiftTierPickerDialog({
    super.key,
    required this.title,
    required this.prefix,
    required this.minusLabel,
    required this.plusLabel,
    required this.enterLabel,
    required this.initial,
    required this.minTier,
    required this.maxTier,
    required this.blurb,
    this.onStep,
  });

  final String title;
  final String prefix;
  final String minusLabel;
  final String plusLabel;
  final String Function(int tier) enterLabel;
  final int initial;
  final int minTier;
  final int maxTier;
  final String blurb;
  final ValueChanged<int>? onStep;

  @override
  State<RiftTierPickerDialog> createState() => _RiftTierPickerDialogState();
}

class _RiftTierPickerDialogState extends State<RiftTierPickerDialog> {
  late int _tier;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _tier = widget.initial.clamp(widget.minTier, widget.maxTier);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _set(int next) {
    final t = next.clamp(widget.minTier, widget.maxTier);
    if (t == _tier) return;
    setState(() => _tier = t);
    widget.onStep?.call(t);
  }

  void _startHold(int delta) {
    _hold?.cancel();
    _hold = Timer.periodic(const Duration(milliseconds: 70), (_) {
      _set(_tier + delta);
      if (_tier == widget.minTier || _tier == widget.maxTier) {
        _hold?.cancel();
        _hold = null;
      }
    });
  }

  void _stopHold() {
    _hold?.cancel();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    return MenuChrome.dialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.blurb,
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Listener(
                onPointerUp: (_) => _stopHold(),
                onPointerCancel: (_) => _stopHold(),
                child: GestureDetector(
                  onLongPressStart: _tier > widget.minTier
                      ? (_) => _startHold(-1)
                      : null,
                  onLongPressEnd: (_) => _stopHold(),
                  child: GameIconButton(
                    glyph: UiGlyph.prev,
                    label: widget.minusLabel,
                    size: 18,
                    color: GameTheme.torchHot,
                    width: GameTheme.minTouch,
                    height: GameTheme.minTouch,
                    onPressed:
                        _tier > widget.minTier ? () => _set(_tier - 1) : null,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${widget.prefix}$_tier',
                  textAlign: TextAlign.center,
                  style: GameTheme.menuTitle(size: 28),
                ),
              ),
              Listener(
                onPointerUp: (_) => _stopHold(),
                onPointerCancel: (_) => _stopHold(),
                child: GestureDetector(
                  onLongPressStart:
                      _tier < widget.maxTier ? (_) => _startHold(1) : null,
                  onLongPressEnd: (_) => _stopHold(),
                  child: GameIconButton(
                    glyph: UiGlyph.next,
                    label: widget.plusLabel,
                    size: 18,
                    color: GameTheme.torchHot,
                    width: GameTheme.minTouch,
                    height: GameTheme.minTouch,
                    onPressed:
                        _tier < widget.maxTier ? () => _set(_tier + 1) : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        GameButton(
          label: 'CANCEL',
          style: GameButtonStyle.grey,
          expanded: false,
          onPressed: () => Navigator.pop(context),
        ),
        GameButton(
          label: widget.enterLabel(_tier),
          style: GameButtonStyle.brown,
          expanded: false,
          onPressed: () => Navigator.pop(context, _tier),
        ),
      ],
    );
  }
}
