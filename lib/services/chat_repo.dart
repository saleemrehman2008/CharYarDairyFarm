import 'package:cloud_firestore/cloud_firestore.dart';

import 'db.dart';
import 'log_service.dart';

/// Saying something in the farm's room, and marking that you have read it.
///
/// There is no edit and no delete. Four people are keeping books together
/// and the whole reason this room exists rather than a WhatsApp group is
/// that nobody can go back and change what they said about a figure. The
/// rules enforce the same thing on the server.
class ChatRepo {
  ChatRepo._();

  /// Post a line. Returns nothing useful — the stream brings it back.
  static Future<void> say({
    required Actor by,
    required String text,
    List<String> mentions = const [],
  }) async {
    final body = text.trim();
    if (body.isEmpty) return;
    await Db.chat.add({
      'text': body,
      'byUid': by.uid,
      'byName': by.name,
      // The server's clock, not the phone's. Two founders whose phones
      // disagree by ten minutes would otherwise see the conversation in two
      // different orders.
      'at': FieldValue.serverTimestamp(),
      'mentions': mentions.toSet().toList(),
    });
  }

  /// Everything up to now has been read by this person.
  ///
  /// Kept as one time on their own record rather than a read-receipt per
  /// message: the count on the tab only has to answer "is there anything
  /// new", and a receipt for every line from every person would be four
  /// writes for every sentence said.
  static Future<void> markSeen(String uid) async {
    try {
      await Db.users.doc(uid).set({
        'chatSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // A failed mark just means the dot stays on. Never worth a message.
    }
  }
}
