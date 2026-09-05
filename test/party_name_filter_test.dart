import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/party_name_filter.dart';

void main() {
  test('empty becomes The Party', () {
    expect(PartyNameFilter.sanitize(''), PartyNameFilter.defaultName);
    expect(PartyNameFilter.sanitize('   '), PartyNameFilter.defaultName);
  });

  test('allows fantasy party names and Scunthorpe-safe words', () {
    expect(PartyNameFilter.sanitize('The Ember Guard'), 'The Ember Guard');
    expect(PartyNameFilter.sanitize('Cave Company'), 'Cave Company');
    expect(PartyNameFilter.sanitize("O'Brien-9"), "O'Brien-9");
    expect(PartyNameFilter.sanitize('Class Act'), 'Class Act');
    expect(PartyNameFilter.sanitize('Hellfire'), 'Hellfire');
    expect(PartyNameFilter.sanitize('Bass Camp'), 'Bass Camp');
    expect(PartyNameFilter.sanitize('The Assassin'), 'The Assassin');
  });

  test('rejects length, charset, and urls', () {
    expect(PartyNameFilter.sanitize('A'), isNull);
    expect(PartyNameFilter.sanitize('ThisNameIsWayTooLong'), isNull);
    expect(PartyNameFilter.sanitize('We <3 Gold'), isNull);
    expect(PartyNameFilter.sanitize('www.bad.com'), isNull);
  });

  test('blocks swears after leet and spacing', () {
    expect(PartyNameFilter.sanitize('sh1t'), isNull);
    expect(PartyNameFilter.sanitize('f u c k'), isNull);
    expect(PartyNameFilter.sanitize('fuuuck'), isNull);
    expect(PartyNameFilter.sanitize('Ass'), isNull);
  });

  test('blocks slurs and political slogans without echoing them', () {
    expect(PartyNameFilter.sanitize('n4z1'), isNull);
    expect(PartyNameFilter.sanitize('MAGA'), isNull);
    expect(PartyNameFilter.sanitize('Antifa'), isNull);
    expect(
      PartyNameFilter.isBlocked(String.fromCharCodes(const [110, 105, 103, 103, 101, 114])),
      isTrue,
    );
    expect(PartyNameFilter.isBlocked('democrat'), isTrue);
    expect(PartyNameFilter.isBlocked('republican'), isTrue);
  });
}
