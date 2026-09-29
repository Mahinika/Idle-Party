import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

/// SCROLLS → EARN: share a Play link, or paste a friend's code.
class FriendTipBlock extends StatefulWidget {
  const FriendTipBlock({super.key, required this.director});

  final GameDirector director;

  @override
  State<FriendTipBlock> createState() => _FriendTipBlockState();
}

class _FriendTipBlockState extends State<FriendTipBlock> {
  late final TextEditingController _code;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final md = widget.director.state.metaDepth;
    final used = md.friendInviteUsed.isNotEmpty;
    final own = md.friendCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Share Idle Party. You get 10 Ad Tickets when a friend installs and opens the app.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        GameButton(
          label: 'TIP A FRIEND',
          tip: 'Opens the share sheet. Messages, mail, Discord, and more.',
          style: GameButtonStyle.brown,
          onPressed: () => unawaited(widget.director.shareFriendInvite()),
        ),
        if (own.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Your code $own',
            style: GameTheme.body(size: 13, color: GameTheme.torchHot),
          ),
        ],
        const SizedBox(height: 6),
        if (used)
          Text(
            'Friend code already applied.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _codeField()),
              const SizedBox(width: 8),
              GameButton(
                label: 'APPLY',
                style: GameButtonStyle.grey,
                expanded: false,
                dense: true,
                onPressed: () {
                  final raw = _code.text;
                  _code.clear();
                  unawaited(widget.director.applyFriendCode(raw));
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _codeField() {
    return TextField(
      controller: _code,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      style: GameTheme.body(size: 14, color: GameTheme.parchment),
      cursorColor: GameTheme.torchHot,
      onSubmitted: (raw) {
        _code.clear();
        unawaited(widget.director.applyFriendCode(raw));
      },
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Friend code',
        hintStyle: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        filled: true,
        fillColor: GameTheme.panelInset,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          borderSide: BorderSide(color: GameTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          borderSide: BorderSide(color: GameTheme.torch),
        ),
      ),
    );
  }
}
