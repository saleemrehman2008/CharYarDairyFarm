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
/// Worked out from what they have put in and nothing else. Profit held in the
/// farm is deliberately not in here: it belongs to whoever earned it, it is
/// already in their name, and counting it again would move everybody's share
/// every month — which is the whole thing version 2 was asked to stop.
///
/// Because the master sets one percentage for all four at a close, everyone
/// keeps back the same proportion, so nobody ends up with more money working
/// in the farm than their share reflects. That rule is what makes this fair,
/// and if it is ever relaxed this has to be revisited.
Map<String, double> ratiosOf(List<Partner> partners) {
  final total = partners.fold<num>(0, (a, p) => a + p.invested);
  if (total <= 0) {
    final even = partners.isEmpty ? 0.0 : 1 / partners.length;
    return {for (final p in partners) p.id: even};
  }
  return {for (final p in partners) p.id: p.invested / total};
}
