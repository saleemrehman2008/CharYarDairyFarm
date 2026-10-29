import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/theme/tokens.dart';

/// Rafeeq runs the farm's account as well as his own.
///
/// The farm gave him that job long before the app had any way of saying so.
/// Every entry he made came out under his own name, and the farm's own
/// account could be reached only by typing its name into the handler field
/// and remembering to — which is how a purchase split two ways left the
/// rest of it sitting on Rafeeq as money out of his own pocket.
///
/// So he wears a hat. These are the two sums behind it: who is offered it,
/// and whose hands the money passes through while it is on. Everything else
/// it does — the entry form opening with the farm's name in it, the accounts
/// page opening on the farm's account, the band across the top — follows
/// from this one answer.
///
/// What it is not is a role. He signs in as himself, the log names him, his
/// own holding stays his own. It grants him nothing he could not already
/// have typed by hand.

var _n = 0;

Partner _p({required String name, String? userId, bool keepsCash = false}) =>
    Partner(
      id: 'p${_n++}',
      userId: userId ?? 'u$_n',
      name: name,
      invested: 0,
      pledged: 0,
      profitHeld: 0,
      withdrawn: 0,
      keepsCash: keepsCash,
      createdAt: DateTime(2026, 10, 1),
    );

/// Who is offered the hat, written the way FarmStore writes it.
bool _runsTheFarmAccount(String uid, List<Partner> partners) {
  if (uid.isEmpty) return false;
  final keeper = partners.where((p) => p.keepsCash).firstOrNull;
  return keeper?.userId == uid;
}

/// Whose hands, written the way Session writes it.
String _handsOf({required String name, required bool asFarm}) =>
    asFarm ? farmAccountName : name;

void main() {
  group('who is offered the hat', () {
    final rafeeq = _p(name: 'Rafeeq', userId: 'u-rafeeq', keepsCash: true);
    final ghulam = _p(name: 'Ghulam Ali', userId: 'u-ghulam');
    final herd = [ghulam, rafeeq];

    test('whoever keeps the farm\'s cash', () {
      expect(_runsTheFarmAccount('u-rafeeq', herd), isTrue);
    });

    test('and nobody else, however much of his own is in the farm', () {
      expect(_runsTheFarmAccount('u-ghulam', herd), isFalse);
    });

    test('nobody at all while the farm has named no keeper', () {
      expect(_runsTheFarmAccount('u-rafeeq', [ghulam]), isFalse);
    });

    test('and never an account with no name on it', () {
      // A signed-out phone, or a record that has not been claimed yet. An
      // empty id must not match an empty userId and let anybody through.
      expect(_runsTheFarmAccount('', herd), isFalse);
      expect(
        _runsTheFarmAccount('', [_p(name: 'Nobody', userId: '')]),
        isFalse,
      );
    });
  });

  group('whose hands the money passes through', () {
    test('his own, with the hat off', () {
      expect(_handsOf(name: 'Rafeeq', asFarm: false), 'Rafeeq');
    });

    test('the farm\'s own account, with it on', () {
      expect(_handsOf(name: 'Rafeeq', asFarm: true), farmAccountName);
    });

    test('and it is the farm account by the name the books know', () {
      // Not a second spelling of it. Every figure that counts the farm
      // account's cash matches on this one string.
      expect(
        partyKey(_handsOf(name: 'Rafeeq', asFarm: true)),
        partyKey(farmAccountName),
      );
    });
  });

  group('the hat is remembered, and it is off by default', () {
    AppUser who({bool asFarm = false}) => AppUser(
      uid: 'u-rafeeq',
      name: 'Rafeeq',
      email: 'r@example.com',
      photoUrl: '',
      role: Role.investor,
      status: UserStatus.active,
      address: '',
      mobile: '',
      lang: Lang.en,
      skin: Skin.dark,
      asFarm: asFarm,
      chatSeenAt: null,
      createdAt: DateTime(2026, 10, 1),
    );

    test('a record that has never been asked wears none', () {
      expect(who().asFarm, isFalse);
    });

    test('and one that has been, wears what it was given', () {
      expect(who(asFarm: true).asFarm, isTrue);
    });

    test('wearing it changes nothing about who he is', () {
      // The point of the whole thing: it is the hat, not the man. His role
      // is what it was, and so is every door the rules open for him.
      expect(who(asFarm: true).role, Role.investor);
      expect(who(asFarm: true).name, 'Rafeeq');
      expect(who(asFarm: true).uid, who().uid);
    });
  });
}
