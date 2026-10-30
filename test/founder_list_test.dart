import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/theme/tokens.dart';

/// Every name the farm's books know, offered everywhere a name is picked.
///
/// The farm's own complaint: Munawar had five lakh in, was on the Co-founders
/// page and in "Who paid for this?", and was not among the names the entry
/// form offered. He had never opened the app. The list every phone picks from
/// was built out of the users collection, which is a list of people who have
/// signed in — and the farm opens a man's capital record months before he
/// ever does.
///
/// So it is built out of the capital records as well, and a man is on it
/// because the farm's books know him, not because he has held the phone. His
/// user record, when there is one, is the fresher source for how he spells
/// his name, because that is the spelling he gave.
///
/// What this guards is not a figure. It is the thing a missing name causes:
/// somebody types it by hand, spells it his own way, and by the second month
/// no total under that name adds up again.

var _n = 0;

Partner _p({required String name, String userId = ''}) => Partner(
  id: 'rec-${_n++}',
  userId: userId,
  name: name,
  invested: 0,
  pledged: 0,
  profitHeld: 0,
  withdrawn: 0,
  createdAt: DateTime(2026, 10, 1),
);

AppUser _u({
  required String uid,
  required String name,
  Role role = Role.investor,
  UserStatus status = UserStatus.active,
}) => AppUser(
  uid: uid,
  name: name,
  email: '$uid@example.com',
  photoUrl: '',
  role: role,
  status: status,
  address: '',
  mobile: '',
  lang: Lang.en,
  skin: Skin.dark,
  chatSeenAt: null,
  createdAt: DateTime(2026, 10, 1),
);

/// The list, written the way FarmStore writes it.
List<FarmPerson> _offered(List<Partner> partners, List<AppUser> users) {
  final byKey = <String, FarmPerson>{};
  final shutOut = {
    for (final u in users)
      if (u.status == UserStatus.blocked) u.uid,
  };

  for (final p in partners) {
    final name = p.name.trim();
    if (name.isEmpty || shutOut.contains(p.userId)) continue;
    byKey[partyKey(name)] = FarmPerson(
      uid: p.userId.isNotEmpty ? p.userId : p.id,
      name: name,
    );
  }
  for (final u in users) {
    if (!u.role.holdsCapital || u.status == UserStatus.blocked) continue;
    final name = u.name.trim();
    if (name.isEmpty) continue;
    byKey[partyKey(name)] = FarmPerson(uid: u.uid, name: name);
  }

  return byKey.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

List<String> _names(List<Partner> partners, List<AppUser> users) =>
    _offered(partners, users).map((p) => p.name).toList();

void main() {
  group('a name is on the list because the books know him', () {
    test('a co-founder who has never opened the app is still offered', () {
      // Munawar's case, which is how this was found.
      final names = _names(
        [_p(name: 'Munawar Soomro'), _p(name: 'Rafeeq', userId: 'u-rafeeq')],
        [_u(uid: 'u-rafeeq', name: 'Rafeeq')],
      );
      expect(names, contains('Munawar Soomro'));
      expect(names, contains('Rafeeq'));
    });

    test('and he carries an id of his own, or the list would drop him', () {
      // The published list throws away a row with no id on it, so a man
      // with no sign-in is listed under his capital record's own.
      final him = _offered([_p(name: 'Munawar Soomro')], const []).single;
      expect(him.uid, isNotEmpty);
    });

    test('a silent investor is offered like anybody else', () {
      final names = _names(
        [_p(name: 'Quiet Partner', userId: 'u-quiet')],
        [_u(uid: 'u-quiet', name: 'Quiet Partner', role: Role.silent)],
      );
      expect(names, contains('Quiet Partner'));
    });

    test('and the master is on it too, being a co-founder as well', () {
      final names = _names(
        [_p(name: 'Saleem Rehman', userId: 'u-saleem')],
        [_u(uid: 'u-saleem', name: 'Saleem Rehman', role: Role.master)],
      );
      expect(names, contains('Saleem Rehman'));
    });
  });

  group('and off it when the books do not', () {
    test('a customer is nobody the farm hands cash to', () {
      final names = _names(const [], [
        _u(uid: 'u-shop', name: 'Urooj Dairy Shop', role: Role.customer),
      ]);
      expect(names, isEmpty);
    });

    test('nor is a rider, who carries it and owns none of it', () {
      final names = _names(const [], [
        _u(uid: 'u-rider', name: 'Rider', role: Role.staff),
      ]);
      expect(names, isEmpty);
    });

    test('a blocked account goes, record and all', () {
      // Blocked on the user side has to reach his capital record too, or
      // the partners pass would quietly put him back.
      final names = _names(
        [_p(name: 'Gone Away', userId: 'u-gone')],
        [_u(uid: 'u-gone', name: 'Gone Away', status: UserStatus.blocked)],
      );
      expect(names, isEmpty);
    });
  });

  group('one man, one row', () {
    test('a record and a sign-in for the same man list him once', () {
      final names = _names(
        [_p(name: 'Rafeeq', userId: 'u-rafeeq')],
        [_u(uid: 'u-rafeeq', name: 'Rafeeq')],
      );
      expect(names, ['Rafeeq']);
    });

    test('and under the spelling he gave when he signed in', () {
      // The master typed "rafeeq" opening the record; he signed in as
      // "RAFIQUE AHMED". His own is the one the app shows.
      final list = _offered(
        [_p(name: 'rafeeq', userId: 'u-rafeeq')],
        [_u(uid: 'u-rafeeq', name: 'rafeeq')],
      );
      expect(list, hasLength(1));
      expect(list.single.uid, 'u-rafeeq');
    });

    test('the list comes out in name order, so it reads the same twice', () {
      final names = _names([
        _p(name: 'Munawar Soomro'),
        _p(name: 'Asif Soomro'),
        _p(name: 'Ghulam Ali'),
      ], const []);
      expect(names, ['Asif Soomro', 'Ghulam Ali', 'Munawar Soomro']);
    });
  });
}
