import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// One of the four, and the two quite separate pots of money in their name.
///
/// They were one pot until version 2. Profit left in the farm used to be added
/// to what somebody had put in, which meant everybody's share of next month
/// moved every time a month was settled. The four of them intend to leave the
/// lot in for a year and buy more buffaloes with it, and they did not want a
/// ratio that drifted underneath them while they did it.
///
/// So: what came out of a pocket decides the share, and nothing else ever
/// touches it. Profit sits in its own account in the same person's name,
/// where it can be watched, drawn on, and — when a month goes badly — reduced.
class Partner {
  Partner({
    required this.id,
    required this.userId,
    required this.name,
    this.email = '',
    required this.invested,
    required this.profitHeld,
    required this.withdrawn,
    required this.createdAt,
    this.pledged = 0,
  });

  final String id;
  final String userId;
  final String name;

  /// The account this record belongs to, shown under the name.
  ///
  /// One person can hold two accounts on the same farm — a master login and a
  /// co-founder login — and both carry the same display name from Google. The
  /// email is the only thing on screen that tells them apart.
  final String email;

  /// Money this person has handed the farm out of their own pocket.
  ///
  /// The only thing the share ratio is worked out from, and it moves only when
  /// they actually put more in. Profit never joins it.
  final num invested;

  /// What this person undertook to put in, whether it has arrived or not.
  ///
  /// The four of them did not start with four equal pockets or four full
  /// ones. Each said what he would put in and is paying it as he can — some
  /// of it handed to whoever keeps the cash, some of it spent straight on a
  /// buffalo or a load of feed. They were asked which should decide the
  /// share, the promise or the money, and chose the promise: a man's share
  /// is settled the day he says what he is in for, and does not creep up
  /// month by month as he pays it off.
  ///
  /// So this is what the ratio is worked out from — see [ratioBase], which
  /// also covers the man who puts in more than he promised. What has
  /// actually arrived is [invested], and the gap between the two is
  /// [stillToPayIn], which the app says out loud wherever the ratio is
  /// shown: a bigger share than your money is paying for is only fair while
  /// everybody can see it.
  ///
  /// Zero on a record from before any of this, and zero means "nothing
  /// promised" — the ratio then falls back to the money, which is how the
  /// farm has run until now.
  final num pledged;

  /// Their profit, kept in the farm rather than taken.
  ///
  /// Can go below zero, and is meant to: a month that loses money takes its
  /// share out of here, and if the losses run past what has been earned then
  /// the farm has eaten into what they put in and the figure says so. Saleem
  /// was asked and was plain about it — "manfi dikhao chupana ni hy".
  final num profitHeld;

  /// Profit they have actually taken out of the farm, all time.
  final num withdrawn;

  final DateTime createdAt;

  /// Everything of theirs the farm is holding: their own money and the profit
  /// they have not taken.
  ///
  /// Never the share ratio — that is [invested] alone. This is what they would
  /// be owed if the four of them stopped tomorrow.
  num get inTheFarm => invested + profitHeld;

  /// What the share ratio is worked out from: the promise, or the money,
  /// whichever is larger.
  ///
  /// The promise, because that is what they agreed. The money when it is
  /// more, because a man who puts in above what he promised must never be
  /// given a smaller share than his own rupees are paying for — and because
  /// that is also what happens to a record with no promise on it at all,
  /// which is how the farm ran before today.
  num get ratioBase => pledged > invested ? pledged : invested;

  /// What is left of the promise. Zero once it is paid, and never negative
  /// — more than promised is [overPaid], which is a different sentence.
  num get stillToPayIn {
    final left = pledged - invested;
    return left > 0 ? left : 0;
  }

  /// Put in above the promise.
  num get overPaid {
    final over = invested - pledged;
    return pledged > 0 && over > 0 ? over : 0;
  }

  /// Everything promised is in.
  bool get paidInFull => pledged > 0 && invested >= pledged;

  /// No money has ever passed through this record.
  ///
  /// Which makes it safe to delete: there is nothing in it to lose, and no
  /// closed period's figures depend on it.
  bool get isEmpty => invested == 0 && profitHeld == 0 && withdrawn == 0;

  factory Partner.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Partner(
      id: doc.id,
      userId: s(m['userId']),
      name: s(m['name']),
      email: s(m['email']),
      invested: n(m['invested']),
      pledged: n(m['pledged']),
      // `reinvested` is what version 1 called it, when it was capital rather
      // than an account of its own. Records written then still say that.
      profitHeld: m['profitHeld'] == null
          ? n(m['reinvested'])
          : n(m['profitHeld']),
      withdrawn: n(m['withdrawn']),
      createdAt: dtOr(m['createdAt']),
    );
  }
}

/// What share of the profit each of them takes.
///
/// Worked out from what each of them is in for — see [Partner.ratioBase] —
/// and nothing else. Profit held in the farm is deliberately not in here: it
/// belongs to whoever earned it, it is already in their name, and counting it
/// again would move everybody's share every month, which is the whole thing
/// version 2 was asked to stop.
///
/// It is the promise rather than the money that counts, and that was decided
/// deliberately. None of the four could put his whole share in at once, and a
/// ratio that followed the money would have shifted under all of them every
/// time one of them paid an instalment — a month's profit split one way and
/// the next month's another, for reasons nobody could keep in their head. The
/// promise is settled once and the shares are settled with it. What it costs
/// is that a man can hold a share his money has not yet paid for, so the app
/// says what each of them still owes wherever the ratio appears.
///
/// Because the master sets one percentage for all four at a close, everyone
/// keeps back the same proportion, so nobody ends up with more money working
/// in the farm than their share reflects. That rule is what makes this fair,
/// and if it is ever relaxed this has to be revisited.
Map<String, double> ratiosOf(List<Partner> partners) {
  final total = partners.fold<num>(0, (a, p) => a + p.ratioBase);
  if (total <= 0) {
    final even = partners.isEmpty ? 0.0 : 1 / partners.length;
    return {for (final p in partners) p.id: even};
  }
  return {for (final p in partners) p.id: p.ratioBase / total};
}
