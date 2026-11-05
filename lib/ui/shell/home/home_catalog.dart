import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../../core/reinstall_pouch.dart';
import '../../confirm_dialogs.dart';
import '../../game_icon.dart';
import '../../hub/friend_tip_block.dart';
import '../../hub/hub_powerups.dart';
import '../../redeem_coupon_dialog.dart';
import '../whats_new_overlay.dart';
import 'floor_jump_sheet.dart';

enum HomePlace { leftRail, rightRail, menuGrid }

typedef HomeOpen = void Function(
  BuildContext context,
  GameDirector director,
  MenuRouter router,
);

class HomeEntry {
  const HomeEntry({
    required this.id,
    required this.place,
    required this.order,
    required this.icon,
    required this.label,
    required this.visible,
    required this.badge,
    required this.open,
    this.timer,
  });

  final String id;
  final HomePlace place;
  final int order;
  final String icon;
  final String label;
  final bool Function(GameState state, GameDirector director) visible;
  final bool Function(GameState state) badge;
  final String? Function(GameState state)? timer;
  final HomeOpen open;
}

/// Rails and the MENU grid. Add a feature by adding one entry.
abstract final class HomeCatalog {
  static final List<HomeEntry> entries = <HomeEntry>[
    HomeEntry(
      id: 'scrolls',
      place: HomePlace.leftRail,
      order: 10,
      icon: UiIcon.tome,
      label: 'SCROLLS',
      visible: (s, _) => MenuTabs.showScrolls(s),
      badge: (s) => s.metaDepth.adTickets > 0,
      timer: (s) =>
          s.metaDepth.adTickets > 0 ? '${s.metaDepth.adTickets}' : null,
      open: (context, director, _) => openPowerupsSheet(context, director),
    ),
    HomeEntry(
      id: 'watch',
      place: HomePlace.leftRail,
      order: 20,
      icon: UiIcon.star,
      label: 'WATCH',
      visible: (s, _) => MenuTabs.showScrolls(s),
      badge: (_) => false,
      open: (context, director, _) => openPowerupsSheet(context, director),
    ),
    HomeEntry(
      id: 'starter_pouch',
      place: HomePlace.leftRail,
      order: 30,
      icon: UiIcon.gold,
      label: 'POUCH',
      visible: (s, _) => ReinstallPouch.showOffer(s),
      badge: (_) => true,
      open: (context, director, _) => openPowerupsSheet(context, director),
    ),
    HomeEntry(
      id: 'update',
      place: HomePlace.rightRail,
      order: 0,
      icon: UiIcon.star,
      label: 'UPDATE',
      visible: (_, director) => director.showPlayUpdateNotice,
      badge: (_) => true,
      open: (context, director, _) => director.openPlayUpdate(),
    ),
    HomeEntry(
      id: 'quests',
      place: HomePlace.rightRail,
      order: 10,
      icon: UiIcon.quests,
      label: 'QUESTS',
      visible: (s, _) => MenuTabs.showQuests(s),
      badge: (s) => s.missions.any((m) => m.canClaim),
      open: (context, director, router) {
        router.open(MenuRoute.more, more: MoreSection.quests);
      },
    ),
    HomeEntry(
      id: 'vault',
      place: HomePlace.rightRail,
      order: 20,
      icon: UiIcon.chest,
      label: 'VAULT',
      visible: (s, _) =>
          GameLogic.showDailyChase(s) && !s.metaDepth.dailyVaultClaimed,
      badge: (s) =>
          s.metaDepth.dailyVaultClears >= GameLogic.dailyVaultClearTarget,
      open: _openVault,
    ),
    HomeEntry(
      id: 'daily',
      place: HomePlace.rightRail,
      order: 30,
      icon: UiIcon.boots,
      label: 'DAILY',
      visible: (s, _) => GameLogic.showDailyRunOnHub(s),
      badge: (_) => false,
      open: (context, director, _) => confirmDailyRun(context, director),
    ),
    HomeEntry(
      id: 'wisp',
      place: HomePlace.rightRail,
      order: 40,
      icon: UiIcon.flask,
      label: 'WISP',
      visible: (s, _) => s.metaDepth.wispUnlocked,
      badge: (_) => false,
      open: (context, director, _) => openPowerupsSheet(context, director),
    ),
    HomeEntry(
      id: 'menu_quests',
      place: HomePlace.menuGrid,
      order: 10,
      icon: UiIcon.quests,
      label: 'QUESTS',
      visible: (_, _) => true,
      badge: (s) => s.missions.any((m) => m.canClaim),
      open: (context, director, router) {
        router.open(MenuRoute.more, more: MoreSection.quests);
        router.pushSub();
      },
    ),
    HomeEntry(
      id: 'menu_patch',
      place: HomePlace.menuGrid,
      order: 20,
      icon: UiIcon.more,
      label: 'PATCH NOTES',
      visible: (_, _) => true,
      badge: (_) => false,
      open: (context, director, _) => WhatsNewOverlay.show(context, director),
    ),
    HomeEntry(
      id: 'menu_settings',
      place: HomePlace.menuGrid,
      order: 30,
      icon: UiIcon.settings,
      label: 'SETTINGS',
      visible: (_, _) => true,
      badge: (_) => false,
      open: (context, director, router) {
        router.open(MenuRoute.more, more: MoreSection.settings);
        router.pushSub();
      },
    ),
    HomeEntry(
      id: 'menu_info',
      place: HomePlace.menuGrid,
      order: 40,
      icon: UiIcon.more,
      label: 'INFO',
      visible: (_, _) => true,
      badge: (_) => false,
      open: (context, director, router) {
        router.open(MenuRoute.more, more: MoreSection.info);
        router.pushSub();
      },
    ),
    HomeEntry(
      id: 'menu_guides',
      place: HomePlace.menuGrid,
      order: 50,
      icon: UiIcon.tome,
      label: 'GUIDES',
      visible: (_, _) => true,
      badge: (_) => false,
      open: (context, director, router) {
        router.open(MenuRoute.more, more: MoreSection.info, infoPane: 0);
        router.pushSub();
      },
    ),
    HomeEntry(
      id: 'menu_craft',
      place: HomePlace.menuGrid,
      order: 60,
      icon: UiIcon.wand,
      label: 'CRAFT',
      visible: (s, _) => MenuTabs.showCraft(s),
      badge: (_) => false,
      open: (context, director, router) {
        router.open(MenuRoute.more, more: MoreSection.craft);
        router.pushSub();
      },
    ),
    HomeEntry(
      id: 'menu_redeem',
      place: HomePlace.menuGrid,
      order: 70,
      icon: UiIcon.star,
      label: 'REDEEM',
      visible: (_, _) => true,
      badge: (_) => false,
      open: (context, director, _) => showRedeemCouponDialog(context, director),
    ),
    HomeEntry(
      id: 'menu_scrolls',
      place: HomePlace.menuGrid,
      order: 80,
      icon: UiIcon.tome,
      label: 'SCROLLS',
      visible: (s, _) => MenuTabs.showScrolls(s),
      badge: (s) => s.metaDepth.adTickets > 0,
      open: (context, director, _) => openPowerupsSheet(context, director),
    ),
    HomeEntry(
      id: 'menu_watch',
      place: HomePlace.menuGrid,
      order: 81,
      icon: UiIcon.star,
      label: 'WATCH',
      visible: (s, _) => MenuTabs.showScrolls(s),
      badge: (_) => false,
      open: (context, director, _) => openPowerupsSheet(context, director),
    ),
    HomeEntry(
      id: 'menu_vault',
      place: HomePlace.menuGrid,
      order: 82,
      icon: UiIcon.chest,
      label: 'VAULT',
      visible: (s, _) =>
          GameLogic.showDailyChase(s) && !s.metaDepth.dailyVaultClaimed,
      badge: (s) =>
          s.metaDepth.dailyVaultClears >= GameLogic.dailyVaultClearTarget,
      open: _openVault,
    ),
    HomeEntry(
      id: 'menu_daily',
      place: HomePlace.menuGrid,
      order: 83,
      icon: UiIcon.boots,
      label: 'DAILY',
      visible: (s, _) => GameLogic.showDailyRunOnHub(s),
      badge: (_) => false,
      open: (context, director, _) => confirmDailyRun(context, director),
    ),
    HomeEntry(
      id: 'menu_wisp',
      place: HomePlace.menuGrid,
      order: 84,
      icon: UiIcon.flask,
      label: 'WISP',
      visible: (s, _) => s.metaDepth.wispUnlocked,
      badge: (_) => false,
      open: (context, director, _) => openPowerupsSheet(context, director),
    ),
    HomeEntry(
      id: 'menu_pouch',
      place: HomePlace.menuGrid,
      order: 85,
      icon: UiIcon.gold,
      label: 'POUCH',
      visible: (s, _) => ReinstallPouch.showOffer(s),
      badge: (_) => true,
      open: (context, director, _) => openPowerupsSheet(context, director),
    ),
    HomeEntry(
      id: 'menu_update',
      place: HomePlace.menuGrid,
      order: 86,
      icon: UiIcon.star,
      label: 'UPDATE',
      visible: (_, director) => director.showPlayUpdateNotice,
      badge: (_) => true,
      open: (context, director, _) => director.openPlayUpdate(),
    ),
    HomeEntry(
      id: 'menu_floors',
      place: HomePlace.menuGrid,
      order: 90,
      icon: UiIcon.boots,
      label: 'FLOORS',
      visible: (s, _) =>
          s.inDungeon &&
          !s.inGauntlet &&
          !s.inAnyRiftMode &&
          !s.inWorldBoss,
      badge: (_) => false,
      open: (context, director, _) => showFloorJumpSheet(context, director),
    ),
  ];

  static void _openVault(
    BuildContext context,
    GameDirector director,
    MenuRouter router,
  ) {
    final state = director.state;
    final clears = state.metaDepth.dailyVaultClears;
    final target = GameLogic.dailyVaultClearTarget;
    if (!state.metaDepth.dailyVaultClaimed && clears >= target) {
      director.claimDailyVault();
      return;
    }
    director.showToast('Daily Vault $clears/$target', life: 2.2);
    router.open(MenuRoute.more, more: MoreSection.quests);
    router.pushSub();
  }

  static List<HomeEntry> of(HomePlace place) {
    final list = entries.where((e) => e.place == place).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }
}

/// Friend invite sits on the MENU grid. It is a block, not a rail icon.
class HomeFriendTip extends StatelessWidget {
  const HomeFriendTip({super.key, required this.director});

  final GameDirector director;

  @override
  Widget build(BuildContext context) => FriendTipBlock(director: director);
}
