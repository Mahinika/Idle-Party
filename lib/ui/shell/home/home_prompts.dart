import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/menu_router.dart';
import '../../../core/meta_systems.dart';
import '../../dungeon_art_warmup.dart';
import '../../meta/notify_opt_in.dart';
import '../../meta/offline_welcome.dart';
import '../../meta/play_review_ask_overlay.dart';
import '../discord_thanks_overlay.dart';
import '../whats_new_overlay.dart';

/// When a card may cover the fight. Bosses, wipes, KEY, and Ranked GR wait.
abstract final class HomePrompts {
  static bool calm(GameDirector director) {
    if (director.awaitingWipeChoice) return false;
    final state = director.state;
    if (!state.inDungeon) return true;
    final world = director.spatial;
    if (world == null) return false;
    if (world.bossBannerTimer > 0) return false;
    if (state.keystoneRunActive && state.keystoneTimerMs > 0) return false;
    if (state.inGreaterRift) return false;
    if (world.awaitingExit) return true;
    return !world.enemies.any((e) => e.isAlive);
  }
}

/// Hub startup cards, shown in camp or in a calm fight.
class HomePromptHost extends StatefulWidget {
  const HomePromptHost({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  State<HomePromptHost> createState() => _HomePromptHostState();
}

class _HomePromptHostState extends State<HomePromptHost> {
  bool _started = false;
  bool _offering = false;
  bool _whatsNew = false;
  bool _discord = false;
  bool _notify = false;
  bool _review = false;
  bool _again = false;
  bool _offlineShowing = false;
  bool _cardShown = false;
  bool _returnWaiting = false;
  Object? _shownSummary;
  Future<void>? _offlineFlight;

  GameDirector get director => widget.director;
  MenuRouter get router => widget.router;

  @override
  void initState() {
    super.initState();
    director.addListener(_onDirector);
    router.addListener(_onRouter);
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    director.removeListener(_onDirector);
    router.removeListener(_onRouter);
    super.dispose();
  }

  Future<void> _boot() async {
    if (_started || !mounted) return;
    _started = true;
    unawaited(DungeonArtWarmup.warm(director.state.dungeonId));
    director.ensureMarketListings();
    director.armAwayPromise();
    await _maybeOffline();
    await _offer();
  }

  void _onDirector() {
    if (!mounted || !_started) return;
    if (_offlineShowing || _offlineFlight != null) return;
    if (_returnWaiting || _returnPending()) {
      unawaited(_maybeOffline());
      if (_returnWaiting || _offlineShowing || _returnPending()) return;
    }
    if (_offering) return;
    if (!HomePrompts.calm(director) || router.isOpen) return;
    unawaited(_offer());
  }

  void _onRouter() {
    if (_returnWaiting && !router.isOpen && mounted) {
      unawaited(_maybeOffline());
    }
    if (!_again || router.isOpen || !mounted) return;
    _again = false;
    unawaited(_offer());
  }

  bool _returnPending() {
    if (director.offlineSummary != null) {
      return !identical(director.offlineSummary, _shownSummary);
    }
    return !_cardShown && GameLogic.returnCardWaiting(director.state);
  }

  /// Another card, an open menu, or a live fight. The return waits.
  bool _blocked() {
    if (_offering || router.isOpen || !HomePrompts.calm(director)) return true;
    final route = ModalRoute.of(context);
    return route != null && !route.isCurrent;
  }

  Future<void> _maybeOffline() {
    final existing = _offlineFlight;
    if (existing != null) return existing;
    final done = Completer<void>();
    _offlineFlight = done.future;
    unawaited(() async {
      try {
        await _openReturn();
      } finally {
        if (identical(_offlineFlight, done.future)) _offlineFlight = null;
        if (!done.isCompleted) done.complete();
      }
    }());
    return done.future;
  }

  Future<void> _openReturn() async {
    if (!mounted || _offlineShowing) return;
    final summary = director.offlineSummary;
    final cardOnly =
        summary == null && GameLogic.returnCardWaiting(director.state);
    if (summary == null && !cardOnly) {
      _returnWaiting = false;
      return;
    }
    if (summary != null && identical(summary, _shownSummary)) return;
    if (cardOnly && _cardShown) return;
    if (_blocked()) {
      _returnWaiting = true;
      return;
    }
    _offlineShowing = true;
    _returnWaiting = false;
    if (summary != null) {
      _shownSummary = summary;
    } else {
      _cardShown = true;
    }
    try {
      if (!mounted) return;
      await showOfflineProgressDialog(context, director, router: router);
    } finally {
      _offlineShowing = false;
      final newer = director.offlineSummary;
      if (mounted && newer != null && !identical(newer, _shownSummary)) {
        _returnWaiting = true;
      }
    }
  }

  Future<void> _offer() async {
    if (_offering || !mounted) return;
    if (router.isOpen || !HomePrompts.calm(director)) {
      _again = router.isOpen;
      return;
    }
    _offering = true;
    try {
      if (await _whatsNewCard()) return;
      if (await _discordCard()) return;
      if (await _notifyCard()) return;
      await _reviewCard();
    } finally {
      _offering = false;
    }
  }

  Future<bool> _whatsNewCard() async {
    if (_whatsNew || !mounted) return false;
    if (!HomePrompts.calm(director)) return false;
    if (!MetaSystems.hasUnseenChangelog(director.state)) return false;
    _whatsNew = true;
    await WhatsNewOverlay.show(context, director);
    return true;
  }

  Future<bool> _discordCard() async {
    if (_discord || !mounted) return false;
    if (!HomePrompts.calm(director)) return false;
    if (!DiscordThanksOverlay.shouldOffer(director)) return false;
    _discord = true;
    await DiscordThanksOverlay.show(context, director);
    return true;
  }

  Future<bool> _notifyCard() async {
    if (_notify || !mounted) return false;
    if (!HomePrompts.calm(director)) return false;
    if (director.offlineSummary != null) return false;
    if (!NotifyOptInOverlay.shouldOffer(director)) return false;
    _notify = true;
    await NotifyOptInOverlay.show(context, director);
    return true;
  }

  Future<bool> _reviewCard() async {
    if (_review || !mounted) return false;
    if (!HomePrompts.calm(director)) return false;
    if (!PlayReviewAskOverlay.shouldOffer(director)) return false;
    _review = true;
    await PlayReviewAskOverlay.show(context, director);
    return true;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
