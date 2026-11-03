import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';

/// Rebuilds only when [select] returns a new value.
///
/// The fight keeps listening to every combat tick. Rails, the top bar, and
/// the upgrade panel must not.
class DirectorSelect<T> extends StatefulWidget {
  const DirectorSelect({
    super.key,
    required this.director,
    required this.select,
    required this.builder,
  });

  final GameDirector director;
  final T Function(GameState state) select;
  final Widget Function(BuildContext context, GameState state) builder;

  @override
  State<DirectorSelect<T>> createState() => _DirectorSelectState<T>();
}

class _DirectorSelectState<T> extends State<DirectorSelect<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.select(widget.director.state);
    widget.director.addListener(_onDirector);
  }

  @override
  void didUpdateWidget(covariant DirectorSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.director != widget.director) {
      oldWidget.director.removeListener(_onDirector);
      widget.director.addListener(_onDirector);
      _value = widget.select(widget.director.state);
    }
  }

  @override
  void dispose() {
    widget.director.removeListener(_onDirector);
    super.dispose();
  }

  void _onDirector() {
    final next = widget.select(widget.director.state);
    if (next == _value) return;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.director.state);
}
