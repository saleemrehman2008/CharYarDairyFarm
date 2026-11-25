// Reading the books the way somebody who knows farms would read them.
//
// The farm asked for a page that does the thinking: are we all right at
// this speed, and which zone is losing money. What it gets is arithmetic —
// every line of it checkable against the ledger by hand, which is the
// whole point between four partners.

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/verdict.dart';
import 'package:char_yar_dairy_farm/services/zones.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Txn _row({
  required TxnType type,
  required String category,
  required num amount,
  int month = 11,
  int day = 10,
  num paidSoFar = -1,
}) {
  final on = DateTime(2026, month, day);
  final settled = paidSoFar < 0 ? amount : paidSoFar;
  return Txn(
    id: 'v${_n++}',
    date: on,
    monthId: '2026-${month.toString().padLeft(2, '0')}',
    type: type,
    party: 'Somebody',
    category: category,
    amount: amount,
    paid: settled >= amount,
    paidOnCreate: settled >= amount,
    paidSoFar: settled,
    note: '',
    createdBy: 'u1',
    createdAt: on,
  );
}

Txn _sale(num amount, {int month = 11, num paidSoFar = -1}) => _row(
  type: TxnType.sale,
  category: milkCategory,
  amount: amount,
  month: month,
  paidSoFar: paidSoFar,
);

Txn _spent(String category, num amount, {int month = 11}) => _row(
  type: TxnType.expense,
  category: category,
  amount: amount,
  month: month,
);

/// A month that earned properly: ten lakh in, eight out, two left.
List<Txn> _good({int month = 11}) => [
  _sale(1000000, month: month),
  _spent('Fodder / feed', 550000, month: month),
  _spent(salariesCategory, 120000, month: month),
  _spent('Rent', 40000, month: month),
  _spent('Transport', 90000, month: month),
];

bool _has(MonthRead r, Note note) => r.findings.any((f) => f.note == note);

Finding _find(MonthRead r, Note note) =>
    r.findings.firstWhere((f) => f.note == note);

MonthRead _read(
  List<Txn> now, {
  List<Txn> before = const [],
  List<Txn> owedToUs = const [],
  List<Txn> owedByUs = const [],
}) => readTheBooks(
  now: now,
  before: before,
  owedToUs: owedToUs,
  owedByUs: owedByUs,
);

void main() {
  group('did it earn', () {
    test('a month that earned says so, and says the share', () {
      final r = _read(_good());
      // 1,000,000 in, 800,000 out, 200,000 left — a fifth.
      expect(r.net, 200000);
      expect(_find(r, Note.healthy).share, closeTo(0.20, 0.0001));
      expect(_find(r, Note.healthy).tone, Tone.good);
      expect(r.tone, Tone.good);
    });

    test('a month that earned a little says that instead', () {
      final r = _read([..._good(), _spent('Transport', 120000)]);
      // 80,000 left of a million: eight per cent.
      expect(_has(r, Note.thin), isTrue);
      expect(_has(r, Note.healthy), isFalse);
      expect(_find(r, Note.thin).tone, Tone.watch);
    });

    test('and a month that lost money says it first', () {
      final r = _read([..._good(), _spent('Fodder / feed', 300000)]);
      expect(r.net, -100000);
      expect(r.findings.first.note, Note.losing);
      expect(r.findings.first.amount, 100000);
      expect(r.tone, Tone.bad);
    });

    test('a loss is not also called a thin month', () {
      // One thing said once. Two findings for one fact is how a page
      // stops being read.
      final r = _read([..._good(), _spent('Fodder / feed', 300000)]);
      expect(_has(r, Note.thin), isFalse);
      expect(_has(r, Note.healthy), isFalse);
    });
  });

  group('the zone to go after', () {
    test('is named, with what it is past its band by', () {
      final r = _read([..._good(), _spent('Fodder / feed', 150000)]);
      // Feed is 700,000 of 1,000,000; the band stops at 650,000.
      final f = _find(r, Note.zoneOver);
      expect(f.zone, Zone.feed);
      expect(f.amount, 50000);
      expect(f.tone, Tone.bad);
    });

    test('and a month with every zone in its band names nothing', () {
      expect(_has(_read(_good()), Note.zoneOver), isFalse);
    });
  });

  group('the running cost', () {
    test('is called out when it has eaten nearly everything', () {
      final r = _read([..._good(), _spent('Transport', 120000)]);
      // 920,000 out of 1,000,000 in.
      expect(_find(r, Note.spendHigh).share, closeTo(0.92, 0.0001));
    });

    test('and is not said twice on a month that already lost money', () {
      final r = _read([..._good(), _spent('Fodder / feed', 300000)]);
      expect(_has(r, Note.spendHigh), isFalse);
    });
  });

  group('the pace', () {
    test('says nothing at all when there is nothing before it', () {
      final r = _read(_good());
      expect(r.hasBefore, isFalse);
      expect(r.pace, 0);
      expect(_has(r, Note.faster), isFalse);
      expect(_has(r, Note.slower), isFalse);
      expect(_has(r, Note.steady), isFalse);
    });

    test('calls a better stretch better, and by how much', () {
      // 200,000 now against 100,000 before.
      final before = [
        ..._good(month: 10),
        _spent('Transport', 100000, month: 10),
      ];
      final r = _read(_good(), before: before);
      expect(r.netBefore, 100000);
      expect(_find(r, Note.faster).amount, 100000);
      expect(r.pace, closeTo(1.0, 0.0001));
    });

    test('calls a worse stretch worse', () {
      final before = _good(month: 10);
      final now = [..._good(), _spent('Transport', 100000)];
      final r = _read(now, before: before);
      expect(_find(r, Note.slower).amount, 100000);
      expect(_find(r, Note.slower).tone, Tone.watch);
      expect(r.pace, closeTo(-0.5, 0.0001));
    });

    test('and a tenth either way is not a change, it is a month', () {
      final before = _good(month: 10);
      final now = [..._good(), _spent('Transport', 10000)];
      final r = _read(now, before: before);
      // 190,000 against 200,000: five per cent.
      expect(_has(r, Note.steady), isTrue);
      expect(_find(r, Note.steady).tone, Tone.good);
    });
  });

  group('what is outside the farm', () {
    test('what is still to come in is counted off the entries', () {
      final owed = [_sale(80000, paidSoFar: 30000)];
      final r = _read(_good(), owedToUs: owed);
      expect(r.toCome, 50000);
      expect(_find(r, Note.toCome).amount, 50000);
    });

    test('and owing more than is coming in is a thing worth saying', () {
      final r = _read(
        _good(),
        owedToUs: [_sale(40000, paidSoFar: 0)],
        owedByUs: [
          _row(
            type: TxnType.purchase,
            category: 'Fodder / feed',
            amount: 90000,
            paidSoFar: 0,
          ),
        ],
      );
      expect(_has(r, Note.owingMore), isTrue);
      expect(_has(r, Note.toPay), isFalse);
      expect(_find(r, Note.owingMore).tone, Tone.watch);
    });

    test('while owing less than is coming in is not', () {
      final r = _read(
        _good(),
        owedToUs: [_sale(90000, paidSoFar: 0)],
        owedByUs: [
          _row(
            type: TxnType.purchase,
            category: 'Fodder / feed',
            amount: 40000,
            paidSoFar: 0,
          ),
        ],
      );
      expect(_has(r, Note.toPay), isTrue);
      expect(_has(r, Note.owingMore), isFalse);
    });
  });

  group('the order', () {
    test('puts what to do something about at the top', () {
      final r = _read([..._good(), _spent('Fodder / feed', 150000)]);
      expect(r.findings.first.tone, Tone.bad);
      // Worst first, all the way down — never a bad line under a good one.
      const rank = {Tone.bad: 0, Tone.watch: 1, Tone.good: 2};
      final order = [for (final f in r.findings) rank[f.tone]!];
      expect(order, [...order]..sort());
    });

    test('and the good news still reaches the page, underneath', () {
      final r = _read(_good(), owedToUs: [_sale(50000, paidSoFar: 0)]);
      expect(r.findings.last.tone, Tone.good);
    });
  });

  group('the stretch before', () {
    final ledger = [
      for (var d = 1; d <= 30; d++)
        _row(
          type: TxnType.sale,
          category: milkCategory,
          amount: 1000,
          month: 10,
          day: d,
        ),
      for (var d = 1; d <= 30; d++)
        _row(
          type: TxnType.sale,
          category: milkCategory,
          amount: 2000,
          month: 11,
          day: d,
        ),
    ];

    test('of a whole month is the whole month before it', () {
      // Not the thirty days before 1 November, which would start on the
      // 2nd of October. Last month means last month.
      final now = ledger.where((t) => t.monthId == '2026-11').toList();
      final was = theStretchBefore(ledger, now);
      expect(was.length, 30);
      expect(was.every((t) => t.date.month == 10), isTrue);
    });

    test('of a part month is the same length ending the day before', () {
      // The 10th to the 19th of November: ten days, looking back at the
      // 31st of October to the 9th of November.
      final now = ledger
          .where(
            (t) => t.date.month == 11 && t.date.day >= 10 && t.date.day <= 19,
          )
          .toList();
      final was = theStretchBefore(ledger, now);
      expect(now.length, 10);
      expect(was.length, 9); // the ledger has nothing on 31 October
      expect(was.map((t) => t.date.day).reduce((a, b) => a < b ? a : b), 1);
      expect(was.map((t) => t.date.day).reduce((a, b) => a > b ? a : b), 9);
    });

    test('and is empty when there is nothing behind it', () {
      final first = ledger.where((t) => t.monthId == '2026-10').toList();
      expect(theStretchBefore(first, first), isEmpty);
    });

    test('and never hands back a row that is already on the page', () {
      final now = ledger.where((t) => t.monthId == '2026-11').toList();
      final ids = {for (final t in now) t.id};
      expect(
        theStretchBefore(ledger, now).any((t) => ids.contains(t.id)),
        isFalse,
      );
    });
  });

  group('a stretch with nothing in it', () {
    test('says nothing rather than making something up', () {
      final r = _read(const []);
      expect(r.isEmpty, isTrue);
      expect(r.findings, isEmpty);
      expect(r.tone, Tone.good);
      expect(r.pace, 0);
    });
  });
}
