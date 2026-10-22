import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/services/sheet_sync.dart';

/// Whose job the Google Sheet is.
///
/// It belongs to one Google account — the master's. A co-founder's phone
/// asks for the Sheets permission when he signs in, so it holds a token of
/// its own, and Google then quite rightly refuses it somebody else's
/// spreadsheet.
///
/// Two things went wrong with that refusal being treated as a failure. It
/// was written into a setting every phone reads, so one co-founder opening
/// his app turned "Sheets synced" red on the master's screen a minute after
/// his own sync had worked. And it came back round every forty-five seconds
/// for as long as the app stayed open, asking a question whose answer
/// cannot change.
void main() {
  group('the four answers a sync can give', () {
    test('a refusal is its own answer, apart from a failure', () {
      // The distinction the farm was missing: whether the farm has a
      // problem, or this handset simply has no business writing.
      expect(SyncResult.denied, isNot(SyncResult.failed));
      expect(SyncResult.denied, isNot(SyncResult.notReady));
    });

    test('and only one of the four means the Sheet is up to date', () {
      expect(
        SyncResult.values.where((r) => r == SyncResult.written),
        hasLength(1),
      );
    });

    test('every answer is accounted for', () {
      // A new one added without deciding whether it retries is how a change
      // gets stranded in the app and never reaches the Sheet.
      expect(SyncResult.values, hasLength(5));
      expect(SyncResult.values.map((r) => r.name).toSet(), {
        'written',
        'skipped',
        'failed',
        'notReady',
        'denied',
      });
    });

    test('a fresh app has not been refused anything', () {
      // It is asked once and remembered for the run, so it must start
      // clean — a phone that was refused yesterday still tries today.
      expect(SheetSync.deniedHere, isFalse);
    });

    test('and stopping clears it, so the next sign-in asks again', () {
      // A different person signing in on the same handset is a different
      // Google account, and his answer may well be yes.
      SheetSync.stop();
      expect(SheetSync.deniedHere, isFalse);
    });
  });
}
