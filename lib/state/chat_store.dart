import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/db.dart';

/// The farm's room, held open for as long as the app is.
///
/// Small and separate from [FarmStore] on purpose: the room is the one part
/// of the app that has to keep listening while you are looking at something
/// else, because the whole point of the dot on the tab is that it appears
/// without you going and checking.
class ChatStore extends ChangeNotifier {
  ChatStore() {
    _sub = Db.watchChat().listen(
      (rows) {
        _msgs = rows;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        // Almost always the rules not being published yet. Say so on the
        // screen rather than spinning for ever.
        _error = '$e';
        _loading = false;
        notifyListeners();
      },
    );
  }

  StreamSubscription<List<ChatMsg>>? _sub;
  List<ChatMsg> _msgs = const [];
  bool _loading = true;
  String? _error;

  /// Newest first, which is how Firestore hands them over and how the list
  /// is drawn — a chat sits at the bottom, so the list is built upside down.
  List<ChatMsg> get messages => _msgs;

  bool get loading => _loading;
  String? get error => _error;

  int unreadFor(String uid, DateTime? seenAt) => unreadIn(_msgs, uid, seenAt);

  bool mentionedSince(String uid, DateTime? seenAt) =>
      mentionedIn(_msgs, uid, seenAt);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// How many lines in [msgs] this person has not seen yet.
///
/// Their own lines never count: nobody needs a red dot telling them they
/// said something. A person who has never opened the room sees everything
/// there as new, which is right — it is all new to them.
///
/// The boundary is "after", not "at or after", because the mark is written
/// with the server's own clock at the moment of reading: counting the
/// instant itself would leave the last line you read sitting unread.
int unreadIn(List<ChatMsg> msgs, String uid, DateTime? seenAt) => msgs
    .where((m) => m.byUid != uid && (seenAt == null || m.at.isAfter(seenAt)))
    .length;

/// Whether any of those unread lines called this person out by name. Worth
/// knowing on its own: being named is not the same as there being traffic.
bool mentionedIn(List<ChatMsg> msgs, String uid, DateTime? seenAt) => msgs.any(
  (m) =>
      m.byUid != uid &&
      m.mentionsMe(uid) &&
      (seenAt == null || m.at.isAfter(seenAt)),
);
