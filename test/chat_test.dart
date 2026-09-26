import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/state/chat_store.dart';

/// The dot on the Chat tab.
///
/// It is the only part of the room with any arithmetic in it, and it is the
/// part that will be complained about: a dot that will not clear, or one
/// that never appears, is the sort of thing that makes a person stop
/// opening the tab at all.

var _n = 0;

ChatMsg _say(
  String by,
  String text, {
  required int minute,
  List<String> at = const [],
}) => ChatMsg(
  id: 'm${_n++}',
  text: text,
  byUid: by,
  byName: by,
  at: DateTime(2026, 9, 26, 10, minute),
  mentions: at,
);

DateTime _clock(int minute) => DateTime(2026, 9, 26, 10, minute);

void main() {
  final room = [
    _say('saleem', 'Feed came in today', minute: 1),
    _say('ali', 'How much', minute: 2),
    _say('saleem', 'Forty bags, @Rafeeq check it', minute: 3, at: ['rafeeq']),
    _say('rafeeq', 'Seen', minute: 4),
  ];

  group('what counts as unread', () {
    test('everything, to somebody who has never opened the room', () {
      // Except their own. Ali said one of the four.
      expect(unreadIn(room, 'ali', null), 3);
    });

    test('nothing you said yourself', () {
      expect(unreadIn(room, 'saleem', null), 2);
      expect(unreadIn(room, 'rafeeq', null), 3);
    });

    test('only what was said after you last looked', () {
      expect(unreadIn(room, 'ali', _clock(2)), 2);
      expect(unreadIn(room, 'ali', _clock(3)), 1);
    });

    test('the line you were looking at does not stay unread', () {
      // Marked at the same instant as the last line. Counting "at or after"
      // here would leave a dot that no amount of opening the tab clears.
      expect(unreadIn(room, 'ali', _clock(4)), 0);
    });

    test('nothing, once you have read to the end', () {
      expect(unreadIn(room, 'ali', _clock(9)), 0);
      expect(unreadIn(room, 'saleem', _clock(9)), 0);
    });

    test('an empty room is not a notification', () {
      expect(unreadIn(const [], 'ali', null), 0);
    });
  });

  group('being called out by name', () {
    test('is noticed', () {
      expect(mentionedIn(room, 'rafeeq', null), isTrue);
    });

    test('and is not, for everybody else in the room', () {
      expect(mentionedIn(room, 'ali', null), isFalse);
      expect(mentionedIn(room, 'saleem', null), isFalse);
    });

    test('stops counting once it has been read', () {
      expect(mentionedIn(room, 'rafeeq', _clock(3)), isFalse);
    });

    test('mentioning yourself is not a message to yourself', () {
      final own = [
        _say('saleem', 'note to me @Saleem', minute: 5, at: ['saleem']),
      ];
      expect(mentionedIn(own, 'saleem', null), isFalse);
      expect(unreadIn(own, 'saleem', null), 0);
    });
  });

  group('a line, once said', () {
    test('carries the name it was said under', () {
      // Stored on the message rather than looked up, so it still reads
      // right after somebody's record changes.
      expect(room.first.byName, 'saleem');
    });

    test('knows who it was aimed at, by id and not by spelling', () {
      expect(room[2].mentionsMe('rafeeq'), isTrue);
      expect(room[2].mentionsMe('Rafeeq'), isFalse);
    });
  });
}
