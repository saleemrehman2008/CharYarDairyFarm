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
