/// Player-facing copy for party crowd-control chips on the fight strip.
abstract final class PartyCcHint {
  static const String slow =
      'SLOW — this hero attacks at 65% speed until the timer runs out. '
      'Wait it out or use a dispel if your kit has one.';

  static const String root =
      'ROOT — this hero cannot move until the timer runs out.';

  static const String hex =
      'HEX — reduced damage until the timer runs out.';

  static String forLabels(List<String> labels) {
    if (labels.isEmpty) return '';
    if (labels.contains('ROOT')) return root;
    if (labels.contains('SLOW')) return slow;
    if (labels.contains('HEX')) return hex;
    return labels.join(' · ');
  }
}