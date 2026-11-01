/// Compile-time build identity.
///
/// Empty unless the APK is built with `--dart-define=GIT_SHA=<sha>`.
/// Play builds omit it. Test APKs set it so QA can match the commit.
abstract final class BuildStamp {
  static const String gitSha = String.fromEnvironment('GIT_SHA');

  static String shortShaOf(String sha) {
    final trimmed = sha.trim();
    if (trimmed.length <= 7) return trimmed;
    return trimmed.substring(0, 7);
  }

  static String get shortSha => shortShaOf(gitSha);

  /// Version alone, or `version · abc1234` when a SHA was compiled in.
  static String versionLabel(String version, {String? sha}) {
    final short = shortShaOf(sha ?? gitSha);
    if (short.isEmpty) return version;
    return '$version · $short';
  }
}
