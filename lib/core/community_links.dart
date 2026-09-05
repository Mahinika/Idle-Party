import 'package:url_launcher/url_launcher.dart';

/// Public community links (Discord, etc.).
abstract final class CommunityLinks {
  /// Never-expiring Idle Party Discord invite (`#welcome`).
  static const String discordInviteUrl = 'https://discord.gg/YMz5ZMkEG9';

  /// Opens Discord app / browser so the player can join the server.
  static Future<bool> openDiscord() async {
    final uri = Uri.parse(discordInviteUrl);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
