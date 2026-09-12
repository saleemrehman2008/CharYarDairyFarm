import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/animal_repo.dart';
import 'package:char_yar_dairy_farm/services/bill_clock.dart';
import 'package:char_yar_dairy_farm/services/bill_repo.dart';
import 'package:char_yar_dairy_farm/services/delivery_repo.dart';
import 'package:char_yar_dairy_farm/util/money.dart';
import 'package:char_yar_dairy_farm/util/phone.dart';
import 'package:char_yar_dairy_farm/widgets/app_shell.dart';

/// Helper so each case reads as the entry a farmer would type.
var _seq = 0;

/// An entry paid as it was written — "Paid now" on the form.
Txn entry({
  required TxnType type,
  required num amount,
  bool paid = true,
  String? customerId,
  String? settlesTxnId,
  String? category,
  String monthId = '2026-09',
}) => Txn(
  id: 'txn${_seq++}',
  date: DateTime(2026, 9, 10),
  monthId: monthId,
  type: type,
  party: 'Someone',
  customerId: customerId,
  category: category ?? type.categories.first,
  amount: amount,
  paid: paid,
  paidAt: paid ? DateTime(2026, 9, 10) : null,
  note: '',
  settlesTxnId: settlesTxnId,
  paidOnCreate: paid,
  createdBy: 'uid',
  createdAt: DateTime(2026, 9, 10),
);

/// An entry booked on credit and settled later, which is how udhaar and
/// supplier bills behave. The cash moves on the settlement row, not here.
Txn creditEntry({
  required TxnType type,
  required num amount,
  required bool settled,
  String? customerId,
  String monthId = '2026-09',
}) => Txn(
  id: 'txn${_seq++}',
  date: DateTime(2026, 9, 10),
  monthId: monthId,
  type: type,
  party: 'Someone',
  customerId: customerId,
  category: type.categories.first,
  amount: amount,
  paid: settled,
  paidAt: settled ? DateTime(2026, 10, 5) : null,
  note: '',
  paidOnCreate: false,
  createdBy: 'uid',
  createdAt: DateTime(2026, 9, 10),
);

/// The receipt or payment "Mark paid" posts against [settles].
Txn settlement({
  required TxnType type,
  required num amount,
  required String settles,
  String monthId = '2026-09',
}) => Txn(
  id: 'txn${_seq++}',
  date: DateTime(2026, 10, 5),
  monthId: monthId,
  type: type,
  party: 'Someone',
  category: type.categories.first,
  amount: amount,
  paid: true,
  paidAt: DateTime(2026, 10, 5),
  note: 'Settles something',
  settlesTxnId: settles,
  paidOnCreate: true,
  createdBy: 'uid',
  createdAt: DateTime(2026, 10, 5),
);

Partner partner(String id, {num invested = 0, num reinvested = 0}) => Partner(
  id: id,
  userId: 'u$id',
  name: 'Partner $id',
  invested: invested,
  reinvested: reinvested,
  withdrawn: 0,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('money formatting', () {
    test('groups the Pakistani way', () {
      expect(groupPk(0), '0');
      expect(groupPk(999), '999');
      expect(groupPk(1000), '1,000');
      expect(groupPk(99999), '99,999');
      expect(groupPk(123456), '1,23,456');
      expect(groupPk(12345678), '1,23,45,678');
      expect(rs(123456), 'Rs 1,23,456');
    });

    test('keeps the sign outside the rupees', () {
      expect(groupPk(-123456), '-1,23,456');
      expect(signedRs(5000, incoming: true), '+ Rs 5,000');
      expect(signedRs(5000, incoming: false), '− Rs 5,000');
    });

    test('rolls the month id over a year boundary', () {
      expect(nextMonthId('2026-09'), '2026-10');
      expect(nextMonthId('2026-12'), '2027-01');
    });
  });

  group('Books', () {
    final monthTxns = [
      entry(type: TxnType.sale, amount: 50000),
      creditEntry(
        type: TxnType.sale,
        amount: 20000,
        settled: false,
        customerId: 'c1',
      ),
      entry(type: TxnType.purchase, amount: 12000),
      creditEntry(type: TxnType.purchase, amount: 3000, settled: false),
      entry(type: TxnType.expense, amount: 5000),
      entry(type: TxnType.receipt, amount: 1000),
      entry(type: TxnType.payment, amount: 500),
    ];
    final unpaid = monthTxns.where((t) => !t.paid).toList();

    final books = Books(
      monthId: '2026-09',
      openingCash: 10000,
      capital: 400000,
      monthTxns: monthTxns,
      unpaidTxns: unpaid,
    );

    test('profit counts unpaid entries too', () {
      expect(books.sales, 70000);
      expect(books.costs, 20000);
      expect(books.profit, 50000);
    });

    test('capital the partners put in is money the farm can spend', () {
      // 400000 capital + 10000 opening + 50000 paid sale + 1000 receipt
      //        − 12000 paid purchase − 5000 paid expense − 500 payment
      expect(books.cash, 443500);
      // The same figure without the partners' capital is what carries forward.
      expect(books.operatingCash, 43500);
    });

    test('profit is not touched by capital', () {
      expect(books.profit, 50000);
    });

    test('receivables and payables split by entry type', () {
      expect(books.receivable, 20000);
      expect(books.payable, 3000);
    });

    test('rolling receivables takes them out of the shareable profit', () {
      expect(books.profitToShare(arIncluded: true), 50000);
      expect(books.profitToShare(arIncluded: false), 30000);
    });

    test('an empty month is all zeroes, not a crash', () {
      final empty = Books.empty('2026-10');
      expect(empty.profit, 0);
      expect(empty.cash, 0);
      expect(empty.profitBar, 0);
    });
  });

  group('credit does not move the balance until it is settled', () {
    Books booksOf(List<Txn> txns, {num opening = 0, num capital = 0}) => Books(
      monthId: '2026-09',
      openingCash: opening,
      capital: capital,
      monthTxns: txns,
      unpaidTxns: txns.where((t) => !t.paid).toList(),
    );

    test('an unpaid bill sits in payables and leaves cash alone', () {
      final books = booksOf([
        creditEntry(type: TxnType.expense, amount: 15000, settled: false),
      ], capital: 100000);
      expect(books.payable, 15000);
      expect(books.cash, 100000);
      // It still counts against profit — the farm owes it either way.
      expect(books.profit, -15000);
    });

    test('an unpaid sale sits in receivables and leaves cash alone', () {
      final books = booksOf([
        creditEntry(type: TxnType.sale, amount: 7200, settled: false),
      ], capital: 100000);
      expect(books.receivable, 7200);
      expect(books.cash, 100000);
    });

    test('marking it paid moves the cash exactly once', () {
      final bill = creditEntry(
        type: TxnType.purchase,
        amount: 400000,
        settled: true,
      );
      final books = booksOf([
        bill,
        settlement(type: TxnType.payment, amount: 400000, settles: bill.id),
      ], capital: 2200000);
      // Not 1,400,000, which is what counting both rows would give.
      expect(books.cash, 1800000);
      expect(books.payable, 0);
    });

    test('settling last month carries the cash into this month', () {
      // The sale was booked and closed in September; the money arrives in
      // October, so only the settlement row is in this month's ledger.
      final books = booksOf([
        settlement(
          type: TxnType.receipt,
          amount: 10000,
          settles: 'septemberSale',
          monthId: '2026-10',
        ),
      ], opening: 5000);
      expect(books.cash, 15000);
    });
  });

  group('cattle and equipment are owned, not spent', () {
    // The farm's first month: 22 lakh of capital, 25 lakh of buffalo, a bag of
    // feed and one day's milk.
    final monthTxns = [
      entry(
        type: TxnType.purchase,
        amount: 2500000,
        category: 'Cattle purchase',
      ),
      entry(type: TxnType.purchase, amount: 400000, category: 'Fodder / feed'),
      entry(type: TxnType.sale, amount: 7200, category: 'Milk'),
    ];
    final books = Books(
      monthId: '2026-09',
      openingCash: 0,
      capital: 2200000,
      monthTxns: monthTxns,
      unpaidTxns: const [],
    );

    test('the buffalo are held out of the running costs', () {
      expect(books.assetsBought, 2500000);
      expect(books.costs, 400000);
    });

    test('profit reflects the month, not the herd', () {
      // Without this the month would show a 28.9 lakh "loss" for buying stock.
      expect(books.profit, 7200 - 400000);
    });

    test('but the cash for them is still gone', () {
      // 2,200,000 capital + 7,200 milk − 2,500,000 cattle − 400,000 feed
      expect(books.cash, -692800);
    });

    test('feed and salaries are still ordinary costs', () {
      final running = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 0,
        monthTxns: [
          entry(type: TxnType.expense, amount: 30000, category: 'Salaries'),
          entry(type: TxnType.expense, amount: 8000, category: 'Rent'),
        ],
        unpaidTxns: const [],
      );
      expect(running.assetsBought, 0);
      expect(running.costs, 38000);
    });
  });

  group('mobile numbers', () {
    test('a Pakistani mobile is eleven digits starting 03', () {
      expect(Phone.isValid('03001234567'), isTrue);
      expect(Phone.isValid('0300 1234567'), isTrue);
      expect(Phone.isValid('0300-123-4567'), isTrue);
    });

    test('the extra digit that slipped through before is caught', () {
      expect(Phone.isValid('030012345678'), isFalse);
      expect(Phone.isValid('0300123456'), isFalse);
    });

    test('a number that is not a mobile is refused', () {
      expect(Phone.isValid('02112345678'), isFalse);
      expect(Phone.isValid(''), isFalse);
      expect(Phone.isValid('not a number'), isFalse);
    });

    test('country code and missing zero are both understood', () {
      expect(Phone.normalise('+92 300 1234567'), '03001234567');
      expect(Phone.normalise('00923001234567'), '03001234567');
      expect(Phone.normalise('3001234567'), '03001234567');
      expect(Phone.isValid('+923001234567'), isTrue);
    });

    test('however it was typed, it is stored one way', () {
      const written = ['0300 1234567', '0300-1234567', '+92 300 1234567'];
      for (final w in written) {
        expect(Phone.normalise(w), '03001234567');
      }
    });

    test('it reads back the way people say it', () {
      expect(Phone.pretty('03001234567'), '0300 1234567');
      expect(Phone.pretty('+923001234567'), '0300 1234567');
    });
  });

  group('khaata bills carry what is left over', () {
    Bill billOf({
      required num thisMonth,
      num previousBalance = 0,
      num paid = 0,
      String monthId = '2026-09',
    }) => Bill(
      id: 'ahmed_$monthId',
      customerId: 'ahmed',
      customerName: 'Ahmed',
      monthId: monthId,
      litres: thisMonth / 180,
      thisMonth: thisMonth,
      previousBalance: previousBalance,
      paid: paid,
      createdAt: DateTime(2026, 9, 30),
    );

    test('a fresh bill is just the month', () {
      final bill = billOf(thisMonth: 6600);
      expect(bill.total, 6600);
      expect(bill.balance, 6600);
      expect(bill.statusLabel, 'Unpaid');
    });

    test('paying part of it leaves the rest owing', () {
      // Saleem's own example: a 6,600 bill, 6,000 handed over.
      final bill = billOf(thisMonth: 6600, paid: 6000);
      expect(bill.balance, 600);
      expect(bill.isPartPaid, isTrue);
      expect(bill.isSettled, isFalse);
      expect(bill.statusLabel, 'Part paid');
    });

    test('the 600 turns up again on next month\'s bill', () {
      final next = billOf(
        thisMonth: 5400,
        previousBalance: 600,
        monthId: '2026-10',
      );
      expect(next.total, 6000);
      expect(next.balance, 6000);
    });

    test('paying in full settles it', () {
      final bill = billOf(thisMonth: 6600, paid: 6600);
      expect(bill.balance, 0);
      expect(bill.isSettled, isTrue);
      expect(bill.statusLabel, 'Paid');
    });

    test('overpaying does not leave a phantom balance', () {
      final bill = billOf(thisMonth: 6600, paid: 7000);
      expect(bill.isSettled, isTrue);
    });
  });

  group('the daily round', () {
    Delivery dayOf(String customerId, int day, num litres, {num rate = 180}) =>
        Delivery(
          id: '${customerId}_2026-09-$day',
          customerId: customerId,
          customerName: customerId,
          date: DateTime(2026, 9, day),
          monthId: '2026-09',
          litres: litres,
          rate: rate,
          slot: 'morning',
          deliveredByName: 'Rafique',
          createdAt: DateTime(2026, 9, day),
        );

    test('a day is worth its litres at that customer\'s rate', () {
      expect(dayOf('ahmed', 1, 4).amount, 720);
      expect(dayOf('bilal', 1, 4, rate: 170).amount, 680);
    });

    test('the month adds up per customer, not across them', () {
      final month = [
        dayOf('ahmed', 1, 4),
        dayOf('ahmed', 2, 4),
        dayOf('ahmed', 3, 2),
        dayOf('bilal', 1, 5, rate: 170),
      ];
      expect(DeliveryRepo.litresIn(month, 'ahmed'), 10);
      expect(DeliveryRepo.amountIn(month, 'ahmed'), 1800);
      expect(DeliveryRepo.amountIn(month, 'bilal'), 850);
    });

    test('the same day from two phones is one record', () {
      // The id is the customer and the day, so the second write overwrites.
      expect(
        Delivery.idFor('ahmed', DateTime(2026, 9, 4)),
        Delivery.idFor('ahmed', DateTime(2026, 9, 4, 18, 30)),
      );
    });
  });

  group('bills raise themselves at month end', () {
    Delivery day(String monthId, int d) => Delivery(
      id: 'ahmed_$monthId-$d',
      customerId: 'ahmed',
      customerName: 'Ahmed',
      date: DateTime.parse('$monthId-${d.toString().padLeft(2, '0')}'),
      monthId: monthId,
      litres: 4,
      rate: 180,
      slot: 'morning',
      deliveredByName: 'Rafique',
      createdAt: DateTime.parse('$monthId-${d.toString().padLeft(2, '0')}'),
    );

    test('nothing is due in the middle of the month', () {
      final due = BillRepo.dueNow([
        day('2026-09', 1),
        day('2026-09', 15),
      ], now: DateTime(2026, 9, 15, 20));
      expect(due, isEmpty);
    });

    test('the last day of the month raises it', () {
      final due = BillRepo.dueNow([
        day('2026-09', 1),
        day('2026-09', 30),
      ], now: DateTime(2026, 9, 30, 21));
      expect(due.keys, ['2026-09']);
      expect(due['2026-09']!.length, 2);
    });

    test('a short month knows its own last day', () {
      final feb = [day('2027-02', 28)];
      expect(BillRepo.dueNow(feb, now: DateTime(2027, 2, 27)), isEmpty);
      expect(BillRepo.dueNow(feb, now: DateTime(2027, 2, 28)), isNotEmpty);
      // 2028 is a leap year, so the 28th is no longer the end.
      final leap = [day('2028-02', 28)];
      expect(BillRepo.dueNow(leap, now: DateTime(2028, 2, 28)), isEmpty);
      expect(BillRepo.dueNow(leap, now: DateTime(2028, 2, 29)), isNotEmpty);
    });

    test('milk left over from a finished month is billed on sight', () {
      // Nobody opened the app on the 31st of August — it still gets billed.
      final due = BillRepo.dueNow([
        day('2026-08', 20),
        day('2026-09', 2),
      ], now: DateTime(2026, 9, 3));
      expect(due.keys, ['2026-08']);
      expect(due['2026-08']!.length, 1);
    });

    test('each month is billed on its own statement', () {
      final due = BillRepo.dueNow([
        day('2026-07', 4),
        day('2026-08', 20),
      ], now: DateTime(2026, 9, 3));
      expect(due.keys.toSet(), {'2026-07', '2026-08'});
    });

    test('no milk, no bill', () {
      expect(BillRepo.dueNow(const [], now: DateTime(2026, 9, 30)), isEmpty);
    });

    test('a day already on a bill is never due again', () {
      // The round billed this customer at eight in the evening; the 11 o'clock
      // sweep must find nothing left of it.
      final stamped = [
        Delivery(
          id: 'ahmed_2026-09-30',
          customerId: 'ahmed',
          customerName: 'Ahmed',
          date: DateTime(2026, 9, 30),
          monthId: '2026-09',
          litres: 4,
          rate: 180,
          slot: 'morning',
          deliveredByName: 'Rafique',
          billed: true,
          billId: 'ahmed_2026-09',
          createdAt: DateTime(2026, 9, 30),
        ),
      ];
      expect(stamped.single.isBilled, isTrue);
      // The unbilled stream never carries it, and raise() skips it anyway.
      expect(
        stamped.where((d) => !d.isBilled).toList(),
        isEmpty,
        reason: 'a stamped day cannot be billed a second time',
      );
    });

    test('the last day of the month is the last day, whatever month it is', () {
      expect(isLastDayOfMonth(DateTime(2026, 9, 30)), isTrue);
      expect(isLastDayOfMonth(DateTime(2026, 9, 29)), isFalse);
      expect(isLastDayOfMonth(DateTime(2026, 10, 31)), isTrue);
      expect(isLastDayOfMonth(DateTime(2027, 2, 28)), isTrue);
      expect(isLastDayOfMonth(DateTime(2028, 2, 28)), isFalse);
      expect(daysInMonth(DateTime(2028, 2, 1)), 29);
    });
  });

  group('the cattle register', () {
    Animal animal({
      String tag = 'B-01',
      String name = '',
      Species species = Species.buffalo,
      Sex sex = Sex.female,
      AnimalStatus status = AnimalStatus.onFarm,
      num dailyLitres = 0,
      DateTime? bornOn,
      DateTime? nextDueOn,
      String? motherId,
    }) => Animal(
      id: tag,
      tag: tag,
      name: name,
      species: species,
      sex: sex,
      status: status,
      photoUrl: 'x',
      dailyLitres: dailyLitres,
      bornOn: bornOn,
      motherId: motherId,
      nextDueOn: nextDueOn,
      createdAt: DateTime(2026, 1, 1),
    );

    test('the tag letter says what the animal is', () {
      expect(AnimalRepo.formatTag(Species.buffalo.tagLetter, 1), 'B-01');
      expect(AnimalRepo.formatTag(Species.cow.tagLetter, 7), 'C-07');
      expect(AnimalRepo.formatTag(Species.goat.tagLetter, 12), 'G-12');
      expect(AnimalRepo.formatTag(Species.qurbani.tagLetter, 3), 'Q-03');
      // Past a hundred the tag simply grows.
      expect(AnimalRepo.formatTag('B', 142), 'B-142');
    });

    test('the register reads B-2 before B-10, not after', () {
      final sorted = [
        animal(tag: 'B-10'),
        animal(tag: 'C-01'),
        animal(tag: 'B-02'),
        animal(tag: 'B-01'),
      ]..sort(Animal.byTag);
      expect(sorted.map((a) => a.tag).toList(), [
        'B-01',
        'B-02',
        'B-10',
        'C-01',
      ]);
    });

    test('only buffalo and cows are asked about milk', () {
      expect(Species.buffalo.milks, isTrue);
      expect(Species.cow.milks, isTrue);
      expect(Species.goat.milks, isFalse);
      expect(Species.qurbani.milks, isFalse);
    });

    test(
      'a vaccination due next week shows up, one due next month does not',
      () {
        final now = DateTime(2026, 9, 12);
        expect(animal(nextDueOn: DateTime(2026, 9, 15)).dueSoon(now), isTrue);
        expect(animal(nextDueOn: DateTime(2026, 10, 20)).dueSoon(now), isFalse);
      },
    );

    test('a date gone by is overdue', () {
      final now = DateTime(2026, 9, 12);
      final late = animal(nextDueOn: DateTime(2026, 9, 1));
      expect(late.overdue(now), isTrue);
      expect(late.dueSoon(now), isTrue);
      expect(animal(nextDueOn: DateTime(2026, 9, 12)).overdue(now), isFalse);
    });

    test('an animal that has left the farm stops asking for anything', () {
      final sold = animal(
        status: AnimalStatus.sold,
        nextDueOn: DateTime(2026, 1, 1),
        dailyLitres: 6,
      );
      expect(sold.dueSoon(DateTime(2026, 9, 12)), isFalse);
      expect(sold.overdue(DateTime(2026, 9, 12)), isFalse);
      expect(sold.isMilking, isFalse, reason: 'she is not here to milk');
    });

    test('age reads in months until two years, then in years', () {
      final born = DateTime(
        DateTime.now().year - 3,
        DateTime.now().month,
        DateTime.now().day,
      );
      expect(animal(bornOn: born).ageLabel, '3 yr');
      expect(animal(bornOn: null).ageLabel, isNull);
    });

    test('the tag is the name when there is no name', () {
      expect(animal(tag: 'B-04').label, 'B-04');
      expect(animal(tag: 'B-04', name: 'Kaali').label, 'B-04 Kaali');
      expect(
        animal(tag: 'G-02', species: Species.goat, sex: Sex.male).summary,
        startsWith('Goat · Male'),
      );
    });

    test('a calf knows it was born here', () {
      expect(animal(motherId: 'B-01').bornHere, isTrue);
      expect(animal().bornHere, isFalse);
    });

    test('what costs money is written down as costing money', () {
      // The kinds that send an entry to the books, and the ones that do not.
      expect(EventKind.vaccination.costable, isTrue);
      expect(EventKind.insemination.costable, isTrue);
      expect(EventKind.treatment.costable, isTrue);
      expect(EventKind.milkReading.costable, isFalse);
      expect(EventKind.calving.costable, isFalse);
    });

    test('only the ones that come round again ask for a next date', () {
      expect(EventKind.vaccination.repeats, isTrue);
      expect(EventKind.pregnancyCheck.repeats, isTrue);
      expect(EventKind.illness.repeats, isFalse);
    });

    test('bought, sold and died are not offered as a choice', () {
      // They are written by the register itself, when the animal arrives or
      // leaves — picking them from a list would leave the books untouched.
      expect(EventKind.chooseable, isNot(contains(EventKind.bought)));
      expect(EventKind.chooseable, isNot(contains(EventKind.sold)));
      expect(EventKind.chooseable, isNot(contains(EventKind.died)));
      expect(EventKind.chooseable, contains(EventKind.vaccination));
    });

    test('a cattle purchase is an asset, a vet bill is not', () {
      // What the register books has to agree with how the books treat it.
      expect(assetCategories, contains('Cattle purchase'));
      expect(assetCategories, isNot(contains('Vet & medicine')));
      expect(TxnType.purchase.categories, contains('Vet & medicine'));
      expect(TxnType.sale.categories, contains('Cattle sale'));
    });
  });

  group('the page fits the screen it is on', () {
    test('a phone keeps its margins and all of its width', () {
      expect(PageBody.sidePad(360), 16);
      expect(PageBody.sidePad(412), 16);
      // A big phone in landscape is still not a tablet.
      expect(PageBody.sidePad(700), 16);
    });

    test('a tablet holds the column to a readable width', () {
      // The 1205 pt tablet the farm is testing on: 720 of content, centred.
      expect(PageBody.sidePad(1205), (1205 - 720) / 2);
      expect(1205 - 2 * PageBody.sidePad(1205), PageBody.maxContent);
    });
  });

  group('the 11 o\'clock sweep', () {
    test('an app opened in the afternoon waits until tonight', () {
      final wait = BillClock.untilNextRun(DateTime(2026, 9, 30, 14, 30));
      expect(wait, const Duration(hours: 8, minutes: 30));
    });

    test('an app opened after eleven waits for tomorrow night', () {
      final wait = BillClock.untilNextRun(DateTime(2026, 9, 30, 23, 10));
      expect(wait, const Duration(hours: 23, minutes: 50));
    });

    test('a phone left open all night runs once a night, not in a loop', () {
      // Right after the run, the next one is a day away — never zero, which
      // would spin.
      final wait = BillClock.untilNextRun(DateTime(2026, 9, 30, 23));
      expect(wait, const Duration(hours: 24));
      expect(wait > Duration.zero, isTrue);
    });
  });

  group('the money breakdown adds up', () {
    // Saleem's real first month: 42 lakh in from four co-founders, 25 lakh of
    // buffalo, 4 lakh of feed, two days of milk — one paid, one on udhaar.
    const money = MoneySummary(
      capital: 4200000,
      assets: 2500000,
      runningCosts: 400000,
      sales: 14400,
      cash: 1307200,
      receivable: 7200,
      payable: 0,
    );

    test('reading down the card lands on what the farm actually holds', () {
      expect(money.expected, 1314400);
      expect(money.farmMoney, 1314400);
      expect(money.reconciles, isTrue);
    });

    test('cash and the unpaid sale together are the farm money', () {
      expect(money.cash + money.receivable, money.farmMoney);
    });

    test('a missing entry shows up as a mismatch', () {
      const wrong = MoneySummary(
        capital: 4200000,
        assets: 2500000,
        runningCosts: 400000,
        sales: 14400,
        // Someone spent 4 lakh without booking it.
        cash: 907200,
        receivable: 7200,
        payable: 0,
      );
      expect(wrong.reconciles, isFalse);
    });
  });

  group('share ratios', () {
    test('follow capital including reinvested profit', () {
      final partners = [
        partner('a', invested: 300000),
        partner('b', invested: 100000, reinvested: 100000),
      ];
      final ratios = ratiosOf(partners);
      expect(ratios['a'], closeTo(0.6, 1e-9));
      expect(ratios['b'], closeTo(0.4, 1e-9));
    });

    test('split evenly before anyone has put money in', () {
      final ratios = ratiosOf([partner('a'), partner('b'), partner('c')]);
      expect(ratios['a'], closeTo(1 / 3, 1e-9));
    });

    test('shareOut rounds to whole rupees and honours each choice', () {
      final partners = [
        partner('a', invested: 60000),
        partner('b', invested: 40000),
      ];
      final shares = shareOut(
        partners: partners,
        profitToShare: 50001,
        choices: {'a': 'reinvest'},
      );
      expect(shares.map((s) => s.share).toList(), [30001, 20000]);
      expect(shares.first.isReinvested, isTrue);
      // Anyone not given a choice defaults to taking the cash.
      expect(shares.last.choice, 'withdraw');
    });

    test('every rupee is handed out, even when it will not divide', () {
      final partners = [partner('a', invested: 1), partner('b', invested: 1)];
      final shares = shareOut(
        partners: partners,
        profitToShare: 101,
        choices: const {},
      );
      expect(shares.fold<num>(0, (a, s) => a + s.share), 101);
    });

    test('three equal partners still add up', () {
      final partners = [
        partner('a', invested: 1),
        partner('b', invested: 1),
        partner('c', invested: 1),
      ];
      final shares = shareOut(
        partners: partners,
        profitToShare: 100,
        choices: const {},
      );
      expect(shares.fold<num>(0, (a, s) => a + s.share), 100);
    });
  });

  group('udhaar limit', () {
    test('is litres x rate x 30 x 1.2, rounded up to a thousand', () {
      // 5 * 200 * 30 * 1.2 = 36000
      expect(UdhaarAccount.suggestLimit(5, 200), 36000);
      // 4 * 210 * 30 * 1.2 = 30240 -> 31000
      expect(UdhaarAccount.suggestLimit(4, 210), 31000);
    });
  });

  group('order status', () {
    test('advances one step at a time and then stops', () {
      expect(OrderStatus.newOrder.next, OrderStatus.preparing);
      expect(OrderStatus.preparing.next, OrderStatus.out);
      expect(OrderStatus.out.next, OrderStatus.delivered);
      expect(OrderStatus.delivered.next, isNull);
      expect(OrderStatus.delivered.advanceLabel, isNull);
    });

    test('open means not delivered and not cancelled', () {
      expect(OrderStatus.out.isOpen, isTrue);
      expect(OrderStatus.delivered.isOpen, isFalse);
      expect(OrderStatus.cancelled.isOpen, isFalse);
      expect(OrderStatus.cancelled.step, 0);
    });
  });
}
