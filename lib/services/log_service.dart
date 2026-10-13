import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'db.dart';

/// Who is performing a write — every repo takes one so the activity log can
/// say "Saleem added a sale" without each screen plumbing the user through.
class Actor {
  const Actor({required this.uid, required this.name});

  final String uid;
  final String name;

  static const unknown = Actor(uid: '', name: 'Someone');

  factory Actor.of(AppUser user) => Actor(uid: user.uid, name: user.name);
}

/// How many times each person has gone back over an entry already written.
///
/// Four friends have put their savings into this farm, and the question that
/// would sour it is not "did somebody change a figure" — figures get typed
/// wrong and have to be fixed. It is "who has been changing them, and how
/// often, and did they tell me". So the count is kept in front of all four of
/// them rather than left to be worked out by scrolling.
///
/// Busiest first, and alphabetical between people who have done the same
/// number, so the list does not reshuffle itself every time it is opened.
List<({String who, int times})> correctionTally(List<LogEntry> lines) {
  final counts = <String, int>{};
  for (final line in lines) {
    if (!line.kind.changedAnEntry) continue;
    final who = line.who.trim().isEmpty ? 'Someone' : line.who.trim();
    counts[who] = (counts[who] ?? 0) + 1;
  }
  final out = [for (final e in counts.entries) (who: e.key, times: e.value)];
  out.sort((a, b) {
    final byCount = b.times.compareTo(a.times);
    return byCount != 0 ? byCount : a.who.compareTo(b.who);
  });
  return out;
}

class Log {
  Log._();

  /// Fire-and-forget: a failed log line must never block the action itself.
  static Future<void> write(
    Actor actor,
    LogKind kind,
    String what, {
    String? refType,
    String? refId,
  }) async {
    try {
      await Db.logs.add({
        'at': FieldValue.serverTimestamp(),
        'uid': actor.uid,
        'who': actor.name,
        'kind': kind.name,
        'what': what,
        'refType': ?refType,
        'refId': ?refId,
      });
    } catch (_) {
      // Ignored on purpose.
    }
  }
}
