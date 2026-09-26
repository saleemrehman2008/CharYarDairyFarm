import 'package:cloud_firestore/cloud_firestore.dart';

import 'helpers.dart';

/// One line said in the farm's own room.
///
/// The four of them already talk on WhatsApp, and that is exactly the
/// trouble: a figure argued over there sits in a thread with the school run
/// and a forwarded video, and a month later nobody can find it. This room
/// holds only farm talk, next to the books it is about, and it cannot be
/// edited after the fact — what was said is what is there.
class ChatMsg {
  const ChatMsg({
    required this.id,
    required this.text,
    required this.byUid,
    required this.byName,
    required this.at,
    required this.mentions,
  });

  final String id;
  final String text;
  final String byUid;

  /// The name is stored on the line rather than looked up, so an old message
  /// still says who wrote it even after that person's record changes.
  final String byName;

  final DateTime at;

  /// Who was called out by name with an `@`. Held as ids, not as the text,
  /// so a mention survives somebody changing how their name is spelled.
  final List<String> mentions;

  bool mentionsMe(String uid) => mentions.contains(uid);

  factory ChatMsg.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return ChatMsg(
      id: doc.id,
      text: s(m['text']),
      byUid: s(m['byUid']),
      byName: s(m['byName']),
      at: dtOr(m['at']),
      mentions: ((m['mentions'] as List?) ?? const [])
          .map((e) => s(e))
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}
