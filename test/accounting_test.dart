import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';
import 'package:char_yar_dairy_farm/services/animal_repo.dart';
import 'package:char_yar_dairy_farm/services/bill_clock.dart';
import 'package:char_yar_dairy_farm/services/bill_repo.dart';
import 'package:char_yar_dairy_farm/services/delivery_repo.dart';
import 'package:char_yar_dairy_farm/services/photo_store.dart';
import 'package:char_yar_dairy_farm/services/rider_repo.dart';
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

Partner partner(String id, {num invested = 0, num held = 0}) => Partner(
  id: id,
  userId: 'u$id',
  name: 'Partner $id',
  invested: invested,
  profitHeld: held,
  withdrawn: 0,
  createdAt: DateTime(2026, 1, 1),
);

/// A khaata house on the round, taking so many litres a day.
UdhaarAccount _khaataStop(String id, num litres) => UdhaarAccount(
  uid: id,
  name: id,
  address: '',
  mobile: '',
  slot: 'morning',
  litresPerDay: litres,
  rate: 220,
  balance: 0,
  status: UdhaarStatus.approved,
  createdAt: DateTime(2026, 9, 1),
);

void main() {
  milkTests();
  flowTests();
  advanceTests();

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
      // Money in with no sale against it. Spelled out rather than left to the
      // first category in the list, which is an advance — somebody else's
      // money, and never income.
      entry(type: TxnType.receipt, amount: 1000, category: 'Other receipt'),
      // Settles something already booked, so it moves cash and nothing else.
      entry(type: TxnType.payment, amount: 500, settlesTxnId: 'txn3'),
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
      // 70,000 sold and 1,000 taken in against no sale at all, less
      // 20,000 of running costs.
      expect(books.otherIncome, 1000);
      expect(books.profit, 51000);
    });

    test('a receipt that settles nothing is the only record of it', () {
      // The mirror of rent paid straight out: money came in and no sale
      // anywhere says so, so this row is all there is. Counted as income,
      // or the cash rises and the profit never notices.
      final without = Books(
        monthId: '2026-09',
        openingCash: 10000,
        capital: 400000,
        monthTxns: monthTxns.where((t) => t.type != TxnType.receipt).toList(),
        unpaidTxns: unpaid,
      );
      expect(without.otherIncome, 0);
      expect(books.profit - without.profit, 1000);
      expect(books.cash - without.cash, 1000, reason: 'and the cash too');
    });

    test('a payment that settles something is not a second cost', () {
      // The purchase it settles was counted when it was booked. Counting the
      // payment as well would charge the farm twice for one bag of feed.
      expect(books.loosePayments, 0);
      expect(books.costs, 20000);
    });

    test('a payment that settles nothing is the only record of the money', () {
      // Rent paid straight out, with no expense booked against it. The rupees
      // have left the farm and this row is all there is to say so, so it is a
      // cost — otherwise the cash falls and the profit never notices.
      final withRent = Books(
        monthId: '2026-09',
        openingCash: 10000,
        capital: 400000,
        monthTxns: [
          ...monthTxns,
          entry(type: TxnType.payment, amount: 25000, category: 'Rent'),
        ],
        unpaidTxns: unpaid,
      );

      expect(withRent.loosePayments, 25000);
      expect(withRent.costs, 45000);
      expect(withRent.profit, 26000);
    });

    test("a co-founder's share is money out, but not a cost", () {
      // It is the farm's earnings going to the people who own them, not the
      // price of running the place.
      final afterClose = Books(
        monthId: '2026-09',
        openingCash: 10000,
        capital: 400000,
        monthTxns: [
          ...monthTxns,
          entry(
            type: TxnType.payment,
            amount: 50000,
            category: profitShareCategory,
          ),
        ],
        unpaidTxns: unpaid,
      );

      expect(afterClose.loosePayments, 0);
      expect(afterClose.costs, 20000);
      expect(afterClose.profit, 51000);
    });

    test('capital the partners put in is money the farm can spend', () {
      // 400000 capital + 10000 opening + 50000 paid sale + 1000 receipt
      //        − 12000 paid purchase − 5000 paid expense − 500 payment
      expect(books.cash, 443500);
      // The same figure without the partners' capital is what carries forward.
      expect(books.operatingCash, 43500);
    });

    test('profit is not touched by capital', () {
      expect(books.profit, 51000);
    });

    test('receivables and payables split by entry type', () {
      expect(books.receivable, 20000);
      expect(books.payable, 3000);
    });

    test('rolling receivables takes them out of the shareable profit', () {
      expect(books.profitToShare(arIncluded: true), 51000);
      expect(books.profitToShare(arIncluded: false), 31000);
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
      photoUrl: '',
      thumb: 'x',
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

  group('an order can run over several days', () {
    OrderItem milk(List<String> days, {num qty = 1}) => OrderItem(
      productId: 'milk',
      name: 'Fresh milk',
      qty: qty,
      price: 220,
      unit: 'L',
      dayKeys: days,
    );

    OrderItem ghee(List<String> days) => OrderItem(
      productId: 'ghee',
      name: 'Deesi Ghee',
      qty: 1,
      price: 2000,
      unit: 'kg',
      dayKeys: days,
    );

    /// One order, built the way the app builds one: every item carrying the
    /// days it is wanted on.
    FarmOrder orderOf({
      required List<OrderItem> items,
      List<String> done = const [],
      String slot = 'morning',
      OrderStatus status = OrderStatus.newOrder,
      String mode = 'delivery',
    }) {
      final days = <String>{for (final i in items) ...i.dayKeys}.toList()
        ..sort();
      return FarmOrder(
        id: 'o1',
        number: '1042',
        customerId: 'c1',
        customerName: 'Ahmed',
        address: 'House 4',
        mobile: '03001234567',
        items: items,
        total: items.fold<num>(0, (t, i) => t + i.total),
        mode: mode,
        slot: slot,
        repeat: days.length > 1 ? 'days' : 'once',
        dayKeys: days,
        doneDays: done,
        pay: PayMethod.cod,
        status: status,
        createdAt: DateTime(2026, 9, 12),
      );
    }

    test('a week of milk is a week of money, not one day of it', () {
      final week = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-14', '2026-09-15']),
        ],
      );
      expect(week.total, 660);
      expect(week.amountOn('2026-09-13'), 220);
      expect(week.isMultiDay, isTrue);
    });

    test('one day is still one day', () {
      final one = orderOf(
        items: [
          milk(['2026-09-13']),
        ],
      );
      expect(one.total, 220);
      expect(one.amountOn('2026-09-13'), 220);
      expect(one.isMultiDay, isFalse);
    });

    test('the ghee goes out once, not every day the milk does', () {
      // Saleem's own case: milk for four days and one kilo of ghee. One set
      // of days across the order would have delivered four kilos of ghee.
      final order = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-14', '2026-09-15', '2026-09-16']),
          ghee(['2026-09-13']),
        ],
      );
      expect(order.total, 220 * 4 + 2000);
      expect(order.dayKeys.length, 4);

      // The first day carries both; the rest are milk alone.
      expect(order.amountOn('2026-09-13'), 2220);
      expect(order.amountOn('2026-09-14'), 220);
      expect(order.itemsOn('2026-09-13').length, 2);
      expect(order.itemsOn('2026-09-14').single.name, 'Fresh milk');
    });

    test('every day added up is the whole order, no more and no less', () {
      final order = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-14']),
          ghee(['2026-09-14']),
        ],
      );
      final summed = order.dayKeys.fold<num>(
        0,
        (t, d) => t + order.amountOn(d),
      );
      expect(summed, order.total);
    });

    test('a day nothing was ordered for costs nothing', () {
      final order = orderOf(
        items: [
          milk(['2026-09-13']),
        ],
      );
      expect(order.amountOn('2026-09-20'), 0);
      expect(order.itemsOn('2026-09-20'), isEmpty);
    });

    test('the round sees it on every day it was ordered for', () {
      final week = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-14', '2026-09-15']),
        ],
      );
      expect(week.dueOn('2026-09-14'), isTrue);
      expect(week.dueOn('2026-09-16'), isFalse);
    });

    test('a day delivered drops off the round and the rest stay', () {
      final week = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-14', '2026-09-15']),
        ],
        done: ['2026-09-13'],
      );
      expect(week.deliveredOn('2026-09-13'), isTrue);
      expect(week.daysLeft, ['2026-09-14', '2026-09-15']);
      expect(week.allDaysDone, isFalse);
    });

    test('the order is finished only when its last day is', () {
      final week = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-14']),
        ],
        done: ['2026-09-13', '2026-09-14'],
      );
      expect(week.daysLeft, isEmpty);
      expect(week.allDaysDone, isTrue);
    });

    test('each day says which one it is', () {
      final week = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-14', '2026-09-15']),
        ],
      );
      expect(week.dayLabel('2026-09-13'), 'day 1 of 3');
      expect(week.dayLabel('2026-09-15'), 'day 3 of 3');
      // A single day needs no such label.
      expect(
        orderOf(
          items: [
            milk(['2026-09-13']),
          ],
        ).dayLabel('2026-09-13'),
        '',
      );
    });

    test('consecutive days read as a span, scattered ones as a list', () {
      final run = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-14', '2026-09-15']),
        ],
      );
      expect(run.daysText, contains('(3 days)'));
      final scattered = orderOf(
        items: [
          milk(['2026-09-13', '2026-09-16']),
        ],
      );
      expect(scattered.daysText, contains(','));
      expect(scattered.daysText, isNot(contains('days)')));
    });

    test('an order from before days existed still has one', () {
      // Read back off a document with no days on the items: the whole thing
      // is one drop, on the day it was placed.
      final legacy = FarmOrder(
        id: 'old',
        number: '900',
        customerId: 'c1',
        customerName: 'Ahmed',
        address: '',
        mobile: '',
        items: const [
          OrderItem(
            productId: 'milk',
            name: 'Fresh milk',
            qty: 1,
            price: 220,
            unit: 'L',
          ),
        ],
        total: 220,
        mode: 'delivery',
        slot: 'morning',
        repeat: 'once',
        dayKeys: [dayKeyOf(DateTime(2026, 9, 1))],
        doneDays: const [],
        pay: PayMethod.cod,
        status: OrderStatus.newOrder,
        createdAt: DateTime(2026, 9, 1),
      );
      expect(legacy.dueOn('2026-09-01'), isTrue);
      expect(legacy.amountOn('2026-09-01'), 220);
      // An item with no days of its own belongs to whatever day is asked for.
      expect(legacy.itemsOn('2026-09-01'), isNotEmpty);
    });

    test('the rider collects for an order and nothing for a khaata', () {
      final cash = orderOf(
        items: [
          milk(['2026-09-13']),
        ],
      );
      expect(cash.toCollectOn('2026-09-13'), 220);

      // The same order on a khaata: the milk goes out, the money does not.
      final onKhaata = FarmOrder(
        id: 'o2',
        number: '1043',
        customerId: 'c1',
        customerName: 'Ahmed',
        address: '',
        mobile: '',
        items: [
          milk(['2026-09-13']),
        ],
        total: 220,
        mode: 'delivery',
        slot: 'morning',
        repeat: 'once',
        dayKeys: const ['2026-09-13'],
        doneDays: const [],
        pay: PayMethod.udhaar,
        status: OrderStatus.newOrder,
        createdAt: DateTime(2026, 9, 12),
      );
      expect(onKhaata.amountOn('2026-09-13'), 220);
      expect(onKhaata.toCollectOn('2026-09-13'), 0);
    });

    test('an item with no days of its own is a legacy order, not a daily', () {
      // dueOn is true for an empty list so an order saved before items had
      // days still shows up. Checkout must therefore never let a line be
      // saved without days — this is the rule that makes that safe.
      const dayless = OrderItem(
        productId: 'ghee',
        name: 'Deesi Ghee',
        qty: 1,
        price: 2000,
        unit: 'kg',
      );
      expect(dayless.dueOn('2026-09-13'), isTrue);
      expect(dayless.dueOn('2027-01-01'), isTrue);
      expect(dayless.total, 2000, reason: 'one delivery, not many');

      // With days, it goes out on those days and no others.
      final dated = ghee(['2026-09-13']);
      expect(dated.dueOn('2026-09-13'), isTrue);
      expect(dated.dueOn('2026-09-14'), isFalse);
    });

    test('a day key is the same string however it is written', () {
      expect(dayKeyOf(DateTime(2026, 9, 5)), '2026-09-05');
      expect(dayKeyOf(DateTime(2026, 9, 5, 23, 59)), '2026-09-05');
      expect(dayFromKey('2026-09-05'), DateTime(2026, 9, 5));
      expect(dayFromKey('rubbish'), isNull);
    });

    test('a missing list is an empty list, not a crash', () {
      expect(strings(null), isEmpty);
      expect(strings('not a list'), isEmpty);
      expect(strings(['2026-09-13', '']), ['2026-09-13']);
    });
  });

  group('photos fit inside the record', () {
    /// A picture roughly the shape and busyness of a real photo — flat colour
    /// would compress to nothing and prove nothing.
    Uint8List photoOf(int w, int h) {
      final im = img.Image(width: w, height: h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          im.setPixelRgb(x, y, (x * 7) % 256, (y * 13) % 256, (x + y) % 256);
        }
      }
      return Uint8List.fromList(img.encodeJpg(im, quality: 95));
    }

    test('a photo comes back small enough for a Firestore document', () {
      final photo = shrinkPhoto(photoOf(1200, 900));
      // A document stops at a megabyte; base64 is a third bigger than the
      // bytes it carries. Both sizes have to clear that with room to spare.
      expect(photo.full.length, lessThan(Photos.maxEncoded));
      expect(photo.thumb.length, lessThan(photo.full.length));
      expect(photo.thumb, isNotEmpty);
    });

    test('an oversized photo is shrunk until it fits, not rejected', () {
      // What a phone hands over when the picker's resize did not happen.
      final photo = shrinkPhoto(photoOf(2400, 1800));
      expect(photo.full.length, lessThan(Photos.maxEncoded));
    });

    test('the thumbnail is small enough to sit in a long list', () {
      final photo = shrinkPhoto(photoOf(1200, 900));
      // A hundred animals at this size is a megabyte for the whole register,
      // read once and then cached.
      expect(photo.thumb.length, lessThan(30 * 1024));
    });

    test('what goes in comes back out', () {
      final photo = shrinkPhoto(photoOf(400, 300));
      final bytes = Photos.decode(photo.thumb);
      expect(bytes, isNotNull);
      expect(img.decodeImage(bytes!)!.width, Photos.thumbWidth);
    });

    test('nothing at all is not a crash', () {
      expect(Photos.decode(null), isNull);
      expect(Photos.decode(''), isNull);
      expect(Photos.decode('not base64 at all !!'), isNull);
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

  group('a rider\'s day has to close', () {
    RiderDay dayOf({
      num loaded = 0,
      num delivered = 0,
      num spotLitres = 0,
      num spotCash = 0,
      num collected = 0,
      num returned = 0,
      num received = 0,
      RiderDayStatus status = RiderDayStatus.open,
    }) => RiderDay(
      id: 'r1_2026-09-12',
      riderId: 'r1',
      riderName: 'Rafique',
      dayKey: '2026-09-12',
      status: status,
      loadedLitres: loaded,
      deliveredLitres: delivered,
      spotLitres: spotLitres,
      spotCash: spotCash,
      collectedCash: collected,
      returnedLitres: returned,
      receivedCash: received,
      createdAt: DateTime(2026, 9, 12),
    );

    test('the milk adds up when everywhere it went is accounted for', () {
      // 20 out: 12 on the round, 5 to orders, 2 sold on the road, 1 back.
      final day = dayOf(loaded: 20, delivered: 17, spotLitres: 2, returned: 1);
      expect(day.milkUnaccounted, 0);
      expect(day.milkAddsUp, isTrue);
    });

    test('milk that went nowhere shows up as a gap', () {
      final day = dayOf(loaded: 20, delivered: 12, spotLitres: 2, returned: 1);
      expect(day.milkUnaccounted, 5);
      expect(day.milkAddsUp, isFalse);
    });

    test('the cash in his hand is what he took, less what was taken in', () {
      final day = dayOf(collected: 1100, spotCash: 440);
      expect(day.cashInHand, 1540);

      final after = dayOf(collected: 1100, spotCash: 440, received: 1540);
      expect(after.cashInHand, 0);
    });

    test('a founder counting short leaves the rest against the rider', () {
      // He said 8,400; 8,000 was counted.
      final day = dayOf(collected: 8400, received: 8000);
      expect(day.cashInHand, 400);
    });

    test('an untouched day is empty, and a day with milk on it is not', () {
      expect(dayOf().isEmpty, isTrue);
      expect(dayOf(loaded: 20).isEmpty, isFalse);
      expect(dayOf(collected: 100).isEmpty, isFalse);
    });

    test('the load sheet groups stops by what each one takes', () {
      final sheet = RiderRepo.loadSheet(
        khaata: [
          _khaataStop('a', 5),
          _khaataStop('b', 5),
          _khaataStop('c', 5),
          _khaataStop('d', 1),
        ],
        orders: const [],
        dayKey: '2026-09-12',
        slot: 'morning',
      );
      // Three houses on five litres, one on a litre: 16 L to load.
      expect(sheet.length, 2);
      expect(sheet.first.litres, 5);
      expect(sheet.first.stops, 3);
      expect(sheet.first.total, 15);
      expect(sheet.fold<num>(0, (a, l) => a + l.total), 16);
    });

    test('only what is sold by the litre goes in the milk can', () {
      // A kilo of ghee is not milk and has no business in the load.
      final order = FarmOrder(
        id: 'o1',
        number: '1',
        customerId: 'c1',
        customerName: 'Ahmed',
        address: '',
        mobile: '',
        items: const [
          OrderItem(
            productId: 'milk',
            name: 'Fresh milk',
            qty: 3,
            price: 220,
            unit: 'L',
            dayKeys: ['2026-09-12'],
          ),
          OrderItem(
            productId: 'ghee',
            name: 'Deesi Ghee',
            qty: 1,
            price: 2000,
            unit: 'kg',
            dayKeys: ['2026-09-12'],
          ),
        ],
        total: 2660,
        mode: 'delivery',
        slot: 'morning',
        repeat: 'once',
        dayKeys: const ['2026-09-12'],
        doneDays: const [],
        pay: PayMethod.cod,
        status: OrderStatus.newOrder,
        createdAt: DateTime(2026, 9, 12),
      );
      expect(RiderRepo.milkIn(order, '2026-09-12'), 3);
      expect(order.amountOn('2026-09-12'), 2660);
    });
  });

  group('cash on a motorcycle is not the farm\'s cash', () {
    Books booksWith({required num withRider}) => Books(
      monthId: '2026-09',
      openingCash: 0,
      capital: 0,
      monthTxns: [entry(type: TxnType.sale, amount: 5000)],
      unpaidTxns: const [],
      withRider: withRider,
    );

    test('a sale the rider is still carrying is held out of the cash', () {
      expect(booksWith(withRider: 0).cash, 5000);
      expect(booksWith(withRider: 1540).cash, 3460);
      // Every rupee is still there when the rider's pocket is counted in.
      expect(booksWith(withRider: 1540).cashIncludingRiders, 5000);
    });

    test('the money breakdown still adds up with cash on the road', () {
      const money = MoneySummary(
        capital: 100000,
        assets: 0,
        runningCosts: 0,
        sales: 5000,
        cash: 103460,
        receivable: 0,
        payable: 0,
        withRider: 1540,
      );
      expect(money.farmMoney, 105000);
      expect(money.expected, 105000);
      expect(money.reconciles, isTrue);
    });
  });

  group('an order list narrows to three', () {
    FarmOrder at(OrderStatus status) => FarmOrder(
      id: status.name,
      number: '1',
      customerId: 'c1',
      customerName: 'Ahmed',
      address: '',
      mobile: '',
      items: const [],
      total: 220,
      mode: 'delivery',
      slot: 'morning',
      repeat: 'once',
      dayKeys: const ['2026-09-12'],
      doneDays: const [],
      pay: PayMethod.cod,
      status: status,
      createdAt: DateTime(2026, 9, 12),
    );

    final all = [
      at(OrderStatus.newOrder),
      at(OrderStatus.preparing),
      at(OrderStatus.out),
      at(OrderStatus.delivered),
      at(OrderStatus.cancelled),
    ];

    test('pending is everything still to do', () {
      expect(OrderFilter.pending.apply(all).length, 3);
    });

    test('completed is what was delivered, and nothing else', () {
      final done = OrderFilter.completed.apply(all);
      expect(done.length, 1);
      expect(done.single.status, OrderStatus.delivered);
    });

    test('a cancelled order is neither, and shows only under All', () {
      expect(
        OrderFilter.pending.apply(all).map((o) => o.status),
        isNot(contains(OrderStatus.cancelled)),
      );
      expect(
        OrderFilter.completed.apply(all).map((o) => o.status),
        isNot(contains(OrderStatus.cancelled)),
      );
      expect(OrderFilter.all.apply(all).length, 5);
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
    test('follow what came out of a pocket, and nothing else', () {
      // Version 1 counted profit left in the farm as capital, so this used to
      // come out 60/40. It was changed on purpose: the four of them mean to
      // keep everything in for a year, and a share that moved underneath them
      // every month while they did it was the thing they asked to stop.
      final partners = [
        partner('a', invested: 300000),
        partner('b', invested: 100000, held: 100000),
      ];
      final ratios = ratiosOf(partners);
      expect(ratios['a'], closeTo(0.75, 1e-9));
      expect(ratios['b'], closeTo(0.25, 1e-9));
    });

    test('split evenly before anyone has put money in', () {
      final ratios = ratiosOf([partner('a'), partner('b'), partner('c')]);
      expect(ratios['a'], closeTo(1 / 3, 1e-9));
    });

    test('shareOut rounds to whole rupees', () {
      final partners = [
        partner('a', invested: 60000),
        partner('b', invested: 40000),
      ];
      final shares = shareOut(partners: partners, profit: 50001);
      expect(shares.map((s) => s.share).toList(), [30001, 20000]);
    });

    test('every rupee is handed out, even when it will not divide', () {
      final partners = [partner('a', invested: 1), partner('b', invested: 1)];
      final shares = shareOut(partners: partners, profit: 101);
      expect(shares.fold<num>(0, (a, s) => a + s.share), 101);
    });

    test('three equal partners still add up', () {
      final partners = [
        partner('a', invested: 1),
        partner('b', invested: 1),
        partner('c', invested: 1),
      ];
      final shares = shareOut(partners: partners, profit: 100);
      expect(shares.fold<num>(0, (a, s) => a + s.share), 100);
    });
  });

  group('what a khaata comes to in a month', () {
    UdhaarAccount khaata({required num litres, required num rate}) =>
        UdhaarAccount(
          uid: 'c1',
          name: 'Ahmed',
          address: 'House 4',
          mobile: '03001234567',
          slot: 'morning',
          litresPerDay: litres,
          rate: rate,
          balance: 0,
          status: UdhaarStatus.approved,
          createdAt: DateTime(2026, 9, 1),
        );

    test('litres a day at their own rate, across thirty days', () {
      // Saleem's own example: 2 L a day at Rs 220.
      expect(khaata(litres: 2, rate: 220).monthlyEstimate, 13200);
      expect(khaata(litres: 5, rate: 200).monthlyEstimate, 30000);
      expect(khaata(litres: 1.5, rate: 210).monthlyEstimate, 9450);
    });

    test('nothing ordered is nothing owed', () {
      expect(khaata(litres: 0, rate: 220).monthlyEstimate, 0);
    });

    test('the line reads the way it would be said out loud', () {
      expect(
        khaata(litres: 2, rate: 220).monthlyLine,
        '2 L/day × Rs 220 × 30 days ≈ Rs 13,200 a month',
      );
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

/// Milk in and milk out.
///
/// The farm took on a neighbouring farm's milk — bought at a hundred and
/// eighty, sold on at two hundred — and asked how to see that apart from its
/// own. Run through the ordinary totals the two vanish into each other: the
/// rupees still come out right, but the month reads as one the buffaloes had,
/// and some of it was somebody else's milk passing through.
Txn _milk({
  required TxnType type,
  required num litres,
  required num rate,
  MilkShift? shift,
  String? category,
  String unit = 'L',
}) => Txn(
  id: 'milk${_seq++}',
  date: DateTime(2026, 9, 10),
  monthId: '2026-09',
  type: type,
  party: type == TxnType.sale ? 'Ali' : 'Sharif Dairy',
  category:
      category ?? (type == TxnType.sale ? milkCategory : milkBoughtInCategory),
  qty: litres,
  unit: unit,
  rate: rate,
  amount: litres * rate,
  paid: true,
  paidOnCreate: true,
  note: '',
  shift: shift,
  createdBy: 'uid',
  createdAt: DateTime(2026, 9, 10),
);

void milkTests() {
  group('milk the farm produced itself', () {
    final book = MilkBook.from([
      _milk(
        type: TxnType.sale,
        litres: 100,
        rate: 200,
        shift: MilkShift.morning,
      ),
      _milk(
        type: TxnType.sale,
        litres: 60,
        rate: 200,
        shift: MilkShift.evening,
      ),
    ]);

    test('all of it counts as the herd own milk', () {
      expect(book.soldLitres, 160);
      expect(book.ownLitres, 160);
      expect(book.boughtLitres, 0);
    });

    test('and there is no trade to report', () {
      expect(book.trades, isFalse);
      // The margin is simply the milk income when nothing was bought in.
      expect(book.marginPk, 32000);
    });

    test('the day splits where it was said to', () {
      expect(book.morningLitres, 100);
      expect(book.eveningLitres, 60);
      expect(book.unsaidLitres, 0);
    });
  });

  group('milk bought off another farm and sold on', () {
    // A hundred litres in at 180, a hundred and eighty out at 200.
    final rows = [
      _milk(type: TxnType.purchase, litres: 100, rate: 180),
      _milk(
        type: TxnType.sale,
        litres: 180,
        rate: 200,
        shift: MilkShift.morning,
      ),
    ];
    final book = MilkBook.from(rows);

    test('the two sides are counted apart', () {
      expect(book.soldLitres, 180);
      expect(book.boughtLitres, 100);
      expect(book.soldPk, 36000);
      expect(book.boughtPk, 18000);
    });

    test('the herd is credited only with what was actually its own', () {
      // Eighty litres, not a hundred and eighty. This is the whole point.
      expect(book.ownLitres, 80);
    });

    test('the margin is what the milk itself left', () {
      expect(book.marginPk, 18000);
      expect(book.trades, isTrue);
    });

    test('the rates read back as they were paid and charged', () {
      expect(book.boughtRate, 180);
      expect(book.soldRate, 200);
    });

    test('and the ledger still adds up the ordinary way', () {
      // The split is a way of reading the same rows, not a second set of
      // them: sales and costs are untouched by any of it.
      final books = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 100000,
        monthTxns: rows,
        unpaidTxns: const [],
      );
      expect(books.sales, 36000);
      expect(books.costs, 18000);
      expect(books.profit, 18000);
    });
  });

  group('what the split refuses to guess', () {
    test('litres entered before the question was asked are held apart', () {
      final book = MilkBook.from([
        _milk(type: TxnType.sale, litres: 40, rate: 200),
        _milk(
          type: TxnType.sale,
          litres: 60,
          rate: 200,
          shift: MilkShift.morning,
        ),
      ]);
      expect(book.morningLitres, 60);
      expect(book.eveningLitres, 0);
      expect(book.unsaidLitres, 40);
      // They are still milk, and still sold. Only the half is unknown.
      expect(book.soldLitres, 100);
    });

    test('a bulk deal with no litres on it adds money but not milk', () {
      // One figure, no quantity — working the litres back out of the rate
      // would be inventing a number the farm never wrote down.
      final book = MilkBook.from([
        Txn(
          id: 'bulk',
          date: DateTime(2026, 9, 10),
          monthId: '2026-09',
          type: TxnType.sale,
          party: 'Counter',
          category: milkCategory,
          amount: 5000,
          paid: true,
          paidOnCreate: true,
          note: '',
          createdBy: 'uid',
          createdAt: DateTime(2026, 9, 10),
        ),
      ]);
      expect(book.soldPk, 5000);
      expect(book.soldLitres, 0);
    });

    test('milk measured in anything but litres is not counted as litres', () {
      final book = MilkBook.from([
        _milk(type: TxnType.sale, litres: 20, rate: 250, unit: 'kg'),
      ]);
      expect(book.soldLitres, 0);
      expect(book.soldPk, 5000);
    });

    test('more bought in than sold is shown, not hidden', () {
      // Milk still in the tank, or an entry somebody got wrong. Either way
      // the farm should see it rather than have it clamped to nothing.
      final book = MilkBook.from([
        _milk(type: TxnType.purchase, litres: 100, rate: 180),
        _milk(
          type: TxnType.sale,
          litres: 40,
          rate: 200,
          shift: MilkShift.evening,
        ),
      ]);
      expect(book.ownLitres, -60);
      expect(book.marginPk, 8000 - 18000);
    });

    test('a deleted row is not milk at all', () {
      final live = _milk(
        type: TxnType.sale,
        litres: 50,
        rate: 200,
        shift: MilkShift.morning,
      );
      final gone = Txn(
        id: 'gone',
        date: DateTime(2026, 9, 10),
        monthId: '2026-09',
        type: TxnType.sale,
        party: 'Ali',
        category: milkCategory,
        qty: 999,
        unit: 'L',
        rate: 200,
        amount: 199800,
        paid: true,
        paidOnCreate: true,
        note: '',
        shift: MilkShift.morning,
        createdBy: 'uid',
        createdAt: DateTime(2026, 9, 10),
        deletedAt: DateTime(2026, 9, 11),
      );
      expect(MilkBook.from([live, gone]).soldLitres, 50);
    });

    test('feed and medicine are not milk bought in', () {
      final book = MilkBook.from([
        _milk(
          type: TxnType.purchase,
          litres: 10,
          rate: 100,
          category: 'Fodder / feed',
        ),
      ]);
      expect(book.boughtLitres, 0);
      expect(book.trades, isFalse);
    });

    test('nothing at all is an empty book, and the card stays off', () {
      expect(MilkBook.from(const []).isEmpty, isTrue);
    });
  });

  group('which entries have to say the milking', () {
    test('a milk sale does', () {
      expect(
        _milk(type: TxnType.sale, litres: 10, rate: 200).needsShift,
        isTrue,
      );
    });

    test('so does milk bought in', () {
      expect(
        _milk(type: TxnType.purchase, litres: 10, rate: 180).needsShift,
        isTrue,
      );
    });

    test('ghee does not, because it is not a milking', () {
      expect(
        _milk(
          type: TxnType.sale,
          litres: 2,
          rate: 3000,
          category: 'Ghee',
          unit: 'kg',
        ).needsShift,
        isFalse,
      );
    });

    test('and neither does money coming in against a milk bill', () {
      expect(entry(type: TxnType.receipt, amount: 32000).needsShift, isFalse);
    });
  });
}

/// Two buttons instead of five.
///
/// The farm looked at Sale / Purchase / Expense / Receipt / Payment and said
/// the words did not tell anybody what they did. They were right: the
/// difference between them is not a difference between things that happen on
/// a farm, it is a difference in what the books do afterwards. So the form
/// now asks only which way the money went, and the heading decides the rest.
///
/// That shifts the whole burden onto the mapping below, which is why it is
/// checked here heading by heading. Get one wrong and money lands in the
/// profit that should not be there, or a cost disappears — silently, with
/// nothing on screen to show for it.
void flowTests() {
  group('which way the money went', () {
    test('every heading on offer maps to something', () {
      for (final flow in MoneyFlow.values) {
        for (final (name, type) in flow.choices) {
          expect(flow.typeOf(name), type, reason: name);
        }
      }
    });

    test('money in is earnings, except the two that are not', () {
      const flow = MoneyFlow.incoming;
      expect(flow.typeOf(milkCategory), TxnType.sale);
      expect(flow.typeOf('Cattle sale'), TxnType.sale);
      // An advance is somebody else's money and a loan instalment is the
      // farm's own coming back. Neither is a rupee earned.
      expect(flow.typeOf(advanceCategory), TxnType.receipt);
      expect(flow.typeOf(loanRepaidCategory), TxnType.receipt);
    });

    test('money out separates what is bought from what is used up', () {
      const flow = MoneyFlow.outgoing;
      expect(flow.typeOf('Cattle purchase'), TxnType.purchase);
      expect(flow.typeOf('Equipment'), TxnType.purchase);
      expect(flow.typeOf('Salaries'), TxnType.expense);
      expect(flow.typeOf('Rent'), TxnType.expense);
      expect(flow.typeOf(advanceReturnCategory), TxnType.payment);
    });

    test('a heading nobody listed counts, rather than slipping through', () {
      // Money in under a typed word is earned; money out under one is spent.
      // The other way round, cash would move and the profit would never
      // notice, and the books would stop adding up by exactly that much.
      expect(MoneyFlow.incoming.typeOf('Tubewell water sold'), TxnType.sale);
      expect(MoneyFlow.outgoing.typeOf('Trolley repair'), TxnType.purchase);
    });

    test('no heading is offered in both directions', () {
      // A word on both lists is a trap: the same heading would be earnings
      // one day and a cost the next, and the summary would add them together.
      final coming = MoneyFlow.incoming.categories.map(partyKey).toSet();
      final going = MoneyFlow.outgoing.categories.map(partyKey).toSet();
      expect(coming.intersection(going), isEmpty);
    });

    test('nothing the app posts for itself is on either list', () {
      for (final flow in MoneyFlow.values) {
        for (final c in flow.categories) {
          expect(
            appPostedCategories.any((own) => partyKey(own) == partyKey(c)),
            isFalse,
            reason: c,
          );
        }
      }
    });

    test('paying a bill by hand is not on offer any more', () {
      // It was, and it double-counted: the bill was already a cost when it
      // was entered, and a payment typed loose against it is counted as a
      // cost all over again while the bill stays open. Settling the entry in
      // the ledger is the path, and taking this off the list is what stops
      // the other one.
      final out = MoneyFlow.outgoing.categories.map(partyKey);
      expect(out, isNot(contains(partyKey('Supplier payment'))));
    });
  });

  group('what the form promises, the books do', () {
    /// One period holding a single entry, so the profit is entirely that
    /// entry's doing.
    num profitOf(TxnType type, String category, {required bool asset}) {
      final row = Txn(
        id: 'flow${_seq++}',
        date: DateTime(2026, 9, 10),
        monthId: '2026-09',
        type: type,
        party: 'Someone',
        category: category,
        amount: 1000,
        paid: true,
        paidOnCreate: true,
        capital: asset,
        note: '',
        createdBy: 'uid',
        createdAt: DateTime(2026, 9, 10),
      );
      return Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 50000,
        monthTxns: [row],
        unpaidTxns: const [],
      ).profit;
    }

    test('every heading on both lists', () {
      for (final flow in MoneyFlow.values) {
        for (final (name, type) in flow.choices) {
          final asset = assetCategories.contains(name);
          final says = entryMovesProfit(
            type: type,
            category: name,
            isAsset: asset,
          );
          final did = profitOf(type, name, asset: asset) != 0;
          expect(
            did,
            says,
            reason:
                '"$name" says the profit ${says ? "moves" : "does not move"}, '
                'and the books ${did ? "moved" : "did not move"} it',
          );
        }
      }
    });

    test('and the sentence on screen says the same thing', () {
      // The words are a promise. If one is reworded into disagreeing with
      // what the books do, that is worse than no sentence at all.
      for (final flow in MoneyFlow.values) {
        for (final (name, type) in flow.choices) {
          final asset = assetCategories.contains(name);
          final line = entryEffect(type: type, category: name, isAsset: asset);
          final saysStill = line.contains('does not move');
          final moves = entryMovesProfit(
            type: type,
            category: name,
            isAsset: asset,
          );
          expect(saysStill, !moves, reason: '"$name": $line');
        }
      }
    });

    test('an advance raises the cash and leaves the profit alone', () {
      expect(profitOf(TxnType.receipt, advanceCategory, asset: false), 0);
    });

    test('handing that advance back is not a cost', () {
      expect(profitOf(TxnType.payment, advanceReturnCategory, asset: false), 0);
    });

    test('a buffalo is not a cost either', () {
      expect(profitOf(TxnType.purchase, 'Cattle purchase', asset: true), 0);
    });

    test('but feed is', () {
      expect(profitOf(TxnType.purchase, 'Fodder / feed', asset: false), -1000);
    });

    test('and milk sold is earnings', () {
      expect(profitOf(TxnType.sale, milkCategory, asset: false), 1000);
    });
  });
}

/// Handing an advance back.
///
/// An advance is the one thing in the cash that is not the farm's. Give back
/// more than was left and the farm has handed away its own money under
/// somebody else's heading — and the advances held come out negative, which
/// reads as the farm being owed by a man the farm owes, and takes the
/// balance check down with it.
///
/// Less is ordinary and must keep working: a contract winding down in
/// stages, or a customer taking part of it and leaving the rest against next
/// month.
Txn _advance({required bool coming, required num amount, String who = 'Ali'}) =>
    Txn(
      id: 'adv${_seq++}',
      date: DateTime(2026, 9, 10),
      monthId: '2026-09',
      type: coming ? TxnType.receipt : TxnType.payment,
      party: who,
      category: coming ? advanceCategory : advanceReturnCategory,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      note: '',
      createdBy: 'uid',
      createdAt: DateTime(2026, 9, 10),
    );

/// The very function the entry form checks a return against, so this is
/// the rule itself being tested and not a second copy of it.
num _heldFor(List<Txn> rows, String who) => advanceHeldForIn(rows, who);

void advanceTests() {
  group('what the farm is holding for somebody', () {
    test('is what they left, before any of it goes back', () {
      final rows = [_advance(coming: true, amount: 50000)];
      expect(_heldFor(rows, 'Ali'), 50000);
    });

    test('comes down by whatever has gone back', () {
      final rows = [
        _advance(coming: true, amount: 50000),
        _advance(coming: false, amount: 20000),
      ];
      expect(_heldFor(rows, 'Ali'), 30000);
    });

    test('is nothing once all of it has', () {
      final rows = [
        _advance(coming: true, amount: 50000),
        _advance(coming: false, amount: 50000),
      ];
      expect(_heldFor(rows, 'Ali'), 0);
    });

    test('is one person at a time, not the whole counter', () {
      final rows = [
        _advance(coming: true, amount: 50000),
        _advance(coming: true, amount: 8000, who: 'Rafeeq'),
      ];
      expect(_heldFor(rows, 'Ali'), 50000);
      expect(_heldFor(rows, 'Rafeeq'), 8000);
      // Ali cannot be handed Rafeeq's eight thousand.
      expect(_heldFor(rows, 'Ali') < 58000, isTrue);
    });

    test('and the name is folded, so one man is not two accounts', () {
      final rows = [
        _advance(coming: true, amount: 50000, who: 'Ali'),
        _advance(coming: false, amount: 10000, who: 'ali'),
      ];
      expect(_heldFor(rows, 'ALI'), 40000);
    });
  });

  group('how much of it may go back', () {
    final rows = [_advance(coming: true, amount: 50000)];
    final held = _heldFor(rows, 'Ali');

    test('part of it', () {
      expect(20000 <= held, isTrue);
    });

    test('all of it', () {
      expect(50000 <= held, isTrue);
    });

    test('but never a rupee more', () {
      // The case the farm asked to have stopped. Without the check this
      // saves, and the advances held go to minus ten thousand.
      expect(60000 <= held, isFalse);
    });

    test('and nothing at all when nothing is being held', () {
      expect(_heldFor(const [], 'Ali'), 0);
    });

    test('what going over would do to the books, if it were allowed', () {
      final over = [...rows, _advance(coming: false, amount: 60000)];
      expect(
        _heldFor(over, 'Ali'),
        -10000,
        reason: 'the farm owing itself money is not a state the books have',
      );
    });
  });

  group('and an advance is still not earnings', () {
    test('coming in', () {
      final books = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 100000,
        monthTxns: [_advance(coming: true, amount: 50000)],
        unpaidTxns: const [],
      );
      expect(books.profit, 0);
      expect(books.cash, 150000, reason: 'the cash is up, the profit is not');
    });

    test('or going back', () {
      final books = Books(
        monthId: '2026-09',
        openingCash: 0,
        capital: 100000,
        monthTxns: [
          _advance(coming: true, amount: 50000),
          _advance(coming: false, amount: 50000),
        ],
        unpaidTxns: const [],
      );
      expect(books.profit, 0);
      expect(books.cash, 100000);
    });
  });
}
