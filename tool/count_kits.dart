import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';

void main() {
  var total = 0;
  for (final s in HeroSpecId.values) {
    final n = ClassKits.forSpec(s).length;
    total += n;
    print('${s.name}: $n');
  }
  print('TOTAL rows: ${ClassKits.all.length}');
  print('unique ids: ${ClassKits.all.map((d) => d.id).toSet().length}');
  print('SUM specs: $total');
}