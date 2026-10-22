import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';
import 'package:char_yar_dairy_farm/services/accounting.dart';

/// The men the farm pays a wage to.
///
/// The farm has been paying them by typing a name into the salary entry every
/// month, which means the month somebody typed "Jalbani" and the month
/// somebody typed "jalbani sb" are two different men as far as the books are
/// concerned, and neither has a wage on record to check the payment against.
///
/// Two numbers in this country are written a particular way and get typed
/// every which way. A CNIC arrives with dashes, with spaces or with neither;
/// a mobile number arrives with a country code, with a leading 92, or short
/// by a digit. Both are kept as bare digits so that one man is one record,
/// and both are shown back the way the card and the phone print them.

Employee _e({
  String name = 'Jalbani',
  String cnic = '',
  String mobile = '',
  num basic = 25000,
  num allowance = 0,
  DateTime? joinedOn,
  DateTime? leftOn,
}) => Employee(
  id: 'e${name.hashCode}${basic.toInt()}',
  name: name,
  cnic: cnic,
  mobile: mobile,
  basic: basic,
  allowance: allowance,
  joinedOn: joinedOn ?? DateTime(2026, 1, 1),
  leftOn: leftOn,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('a wage is a wage, whatever the month is called', () {
    /// The farm said it plainly: "salary calendar month 24k hy, to ye lazmi
    /// hona chahiye." A whole month pays the whole wage — February, October,
    /// November, the same twenty-four thousand.
    ///
    /// The app used to count every month as thirty days. It is the
    /// convention everybody knows and it is wrong in both directions: a full
    /// February came out at 22,400 of a 24,000 wage, short by sixteen
    /// hundred rupees of somebody's money every single year, and a 31-day
    /// month had to be capped on the way past to stop it paying more than a
    /// month's wage for a month's work.
    ///
    /// So a whole month pays the whole wage, and a part of one is worked out
    /// against that month's own length. Over a year each month pays the same
    /// and every part of one is fair to the day.

    final hand = _e(name: 'Jalbani', basic: 24000, joinedOn: DateTime(2020));

    num forMonth(Employee e, int year, int month) => e.payForWindow(
      from: DateTime(year, month, 1),
      to: DateTime(year, month + 1, 0),
    );

    test('February pays a whole wage', () {
      expect(forMonth(hand, 2026, 2), 24000);
    });

    test('and so does a leap February', () {
      expect(Employee.lengthOf(DateTime(2028, 2, 1)), 29);
      expect(forMonth(hand, 2028, 2), 24000);
    });

    test('and a thirty day month, and a thirty-one day month', () {
      expect(forMonth(hand, 2026, 11), 24000);
      expect(forMonth(hand, 2026, 10), 24000);
    });

    test('every month of a year pays the same', () {
      for (var m = 1; m <= 12; m++) {
        expect(forMonth(hand, 2026, m), 24000, reason: 'month $m');
      }
    });

    test('a wage and an allowance are one month between them', () {
      final both = _e(basic: 25000, allowance: 3000, joinedOn: DateTime(2020));
      expect(both.monthly, 28000);
      expect(forMonth(both, 2026, 2), 28000);
    });

    test('half of February is half a wage, not fourteen thirtieths', () {
      // Fourteen of twenty-eight days. Counted against thirty it would have
      // been 12,000 — eight hundred rupees light, for no reason a man could
      // be told.
      final e = _e(basic: 24000, joinedOn: DateTime(2026, 2, 15));
      expect(
        e.payForWindow(from: DateTime(2026, 2, 1), to: DateTime(2026, 2, 28)),
        12000,
      );
    });

    test('and twelve days of October are twelve thirty-firsts', () {
      final e = _e(basic: 24000, joinedOn: DateTime(2026, 10, 20));
      expect(
        e.payForWindow(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31)),
        9290,
      );
    });

    test('days off come off the whole month, allowance and all', () {
      // A day's absence is a day of the month. Taking it off the basic
      // alone would quietly pay a man who was away more per working day
      // than one who was not.
      final e = _e(basic: 25000, allowance: 5000, joinedOn: DateTime(2020));
      expect(
        e.payForWindow(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
          daysOff: 3,
        ),
        27000,
      );
    });

    test('a whole month away leaves nothing, and no further', () {
      final e = _e(basic: 30000, joinedOn: DateTime(2020));
      final nov = (DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      expect(e.payForWindow(from: nov.$1, to: nov.$2, daysOff: 30), 0);
      expect(e.payForWindow(from: nov.$1, to: nov.$2, daysOff: 45), 0);
    });

    test('no days off takes nothing off', () {
      final e = _e(basic: 28000, joinedOn: DateTime(2020));
      expect(
        e.payForWindow(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
          daysOff: 0,
        ),
        28000,
      );
    });

    test('an awkward figure comes out whole', () {
      // Nobody is paid 24,333.333 rupees.
      final e = _e(basic: 25000, allowance: 2000, joinedOn: DateTime(2020));
      final pay = e.payForWindow(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        daysOff: 7,
      );
      expect(pay, pay.round());
      expect(pay, 20700);
    });
  });

  group('the two numbers Pakistan writes a particular way', () {
    test('a CNIC is kept as digits, however it was typed', () {
      for (final typed in [
        '42101-1234567-1',
        '4210112345671',
        '42101 1234567 1',
        '42101–1234567–1',
      ]) {
        expect(cnicDigits(typed), '4210112345671');
      }
    });

    test('and shown the way it is printed on the card', () {
      expect(cnicShown('4210112345671'), '42101-1234567-1');
      expect(cnicShown('42101-1234567-1'), '42101-1234567-1');
    });

    test('thirteen digits, and never starting with a zero', () {
      // The first digit is the province the card was issued in, one through
      // seven. A zero is a slip of the thumb.
      expect(cnicWrong('42101-1234567-1'), isNull);
      expect(cnicWrong('421011234567'), contains('13 digits'));
      expect(cnicWrong('42101123456712'), contains('13 digits'));
      expect(cnicWrong('0210112345671'), contains('zero'));
    });

    test('blank is allowed, because a man without his card is still a man', () {
      // Refusing to write him down until he brings it is how he ends up not
      // written down at all.
      expect(cnicWrong(''), isNull);
      expect(cnicWrong('   '), isNull);
      expect(mobileWrong(''), isNull);
    });

    test('a mobile number is eleven digits beginning 03', () {
      expect(mobileWrong('0300-1234567'), isNull);
      expect(mobileWrong('03001234567'), isNull);
      expect(mobileWrong('0300123456'), contains('11 digits'));
      expect(mobileWrong('042-1234567'), contains('starts 03'));
      expect(mobileWrong('923001234567'), contains('starts 03'));
    });

    test('and is shown the way it is dialled', () {
      expect(mobileShown('03001234567'), '0300-1234567');
      expect(mobileShown('0300-1234567'), '0300-1234567');
    });

    test('something half typed is handed back as it stands', () {
      // Rather than mangled into a shape it does not have.
      expect(cnicShown('421'), '421');
      expect(mobileShown('0300'), '0300');
    });
  });

  group('the wage list itself', () {
    test('the longest serving first, and the ones who left at the bottom', () {
      final list = onTheBooks([
        _e(name: 'Newer', joinedOn: DateTime(2026, 6, 1)),
        _e(
          name: 'Gone',
          joinedOn: DateTime(2020, 1, 1),
          leftOn: DateTime(2026, 5, 1),
        ),
        _e(name: 'Oldest', joinedOn: DateTime(2024, 1, 1)),
      ]);
      expect([for (final e in list) e.name], ['Oldest', 'Newer', 'Gone']);
    });

    test('a man who has left is kept, not deleted', () {
      // His wages are in months that are closed. A figure whose name has
      // vanished costs an evening to work out two years later.
      final gone = _e(name: 'Gone', leftOn: DateTime(2026, 5, 1));
      expect(gone.isWorking, isFalse);
      expect(onTheBooks([gone]), hasLength(1));
    });

    test('the monthly wage bill counts only those still working', () {
      final bill = monthlyWageBill([
        _e(name: 'A', basic: 25000, allowance: 3000),
        _e(name: 'B', basic: 20000),
        _e(name: 'Gone', basic: 30000, leftOn: DateTime(2026, 5, 1)),
      ]);
      expect(bill, 48000);
    });

    test('an empty farm owes nobody anything', () {
      expect(monthlyWageBill(const []), 0);
      expect(onTheBooks(const []), isEmpty);
    });
  });

  group('a month he was only here part of', () {
    /// The farm's own case, in its own words: "maine ek banda rakha 7 Oct ko,
    /// aur 19 Oct us ka last working day kar diya — ab salary nikaloon to kya
    /// ye 7 se 19 tak khud bana dega?"
    ///
    /// It does now. Both dates are already on his record, so the farm should
    /// not be counting them on its fingers.

    final oct = (DateTime(2026, 10, 1), DateTime(2026, 10, 31));

    test('taken on the 7th and let go on the 19th is thirteen days', () {
      // Both ends worked: he was here on the 7th and here on the 19th.
      final e = _e(
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
      );
      expect(e.daysOnIn(oct.$1, oct.$2), 13);
    });

    test('and his wage is thirteen thirtieths of the month', () {
      final e = _e(
        basic: 27000,
        allowance: 3000,
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
      );
      expect(e.payForWindow(from: oct.$1, to: oct.$2), 12581);
      expect(e.monthly - e.payForWindow(from: oct.$1, to: oct.$2), 17419);
    });

    test('days off come off on top of the days he was here', () {
      // He was here for thirteen of them and took two of those off, so he
      // is owed eleven.
      final e = _e(
        basic: 30000,
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
      );
      expect(e.payForWindow(from: oct.$1, to: oct.$2, daysOff: 2), 10645);
    });

    test('a man who started before the month gets the whole of it', () {
      final e = _e(joinedOn: DateTime(2026, 1, 1), basic: 30000);
      expect(e.daysOnIn(oct.$1, oct.$2), 31);
      expect(e.payForWindow(from: oct.$1, to: oct.$2), 30000);
    });

    test('a long month is still one month of pay', () {
      // October has 31 days and November 30, and both pay a month's wage.
      final e = _e(joinedOn: DateTime(2020, 1, 1), basic: 30000);
      expect(e.daysOnIn(oct.$1, oct.$2), 31);
      expect(e.payForWindow(from: oct.$1, to: oct.$2), 30000);
    });

    test('a month after he left is nothing at all', () {
      final e = _e(
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
      );
      final nov = (DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      expect(e.daysOnIn(nov.$1, nov.$2), 0);
      expect(e.payForWindow(from: nov.$1, to: nov.$2), 0);
    });

    test('and a month before he started is nothing either', () {
      final e = _e(joinedOn: DateTime(2026, 10, 7));
      final sep = (DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      expect(e.daysOnIn(sep.$1, sep.$2), 0);
    });

    test('joined on the last day of the month is one day', () {
      final e = _e(joinedOn: DateTime(2026, 10, 31));
      expect(e.daysOnIn(oct.$1, oct.$2), 1);
    });

    test('left on the first is one day too', () {
      final e = _e(
        joinedOn: DateTime(2026, 1, 1),
        leftOn: DateTime(2026, 10, 1),
      );
      expect(e.daysOnIn(oct.$1, oct.$2), 1);
    });

    test('the time of day on either date changes nothing', () {
      // A date picker hands back midnight; a server timestamp does not.
      final e = _e(
        joinedOn: DateTime(2026, 10, 7, 18, 45),
        leftOn: DateTime(2026, 10, 19, 6, 5),
      );
      expect(e.daysOnIn(oct.$1, oct.$2), 13);
    });

    test('February pays the same as October', () {
      // Thirty days whatever the calendar says, which is how the farm has
      // always counted it and how the man expects it to be counted.
      final e = _e(joinedOn: DateTime(2020, 1, 1), basic: 30000);
      final feb = (DateTime(2026, 2, 1), DateTime(2026, 2, 28));
      expect(e.daysOnIn(feb.$1, feb.$2), 28);
      expect(e.payForWindow(from: feb.$1, to: feb.$2), 30000);
    });

    test('away the whole of a part month leaves nothing owed', () {
      final e = _e(
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
        basic: 30000,
      );
      expect(e.payForWindow(from: oct.$1, to: oct.$2, daysOff: 13), 0);
      expect(e.payForWindow(from: oct.$1, to: oct.$2, daysOff: 40), 0);
    });
  });

  group('an advance against a wage', () {
    /// "Wo month abhi poora nahi hua aur kehta hai mujhe 5k advance de do,
    /// salary se kaat lena." The farm has always said yes and then had to
    /// remember, so whether it came off depended on who was doing the paying
    /// at the end of the month. The entries know, so they do the remembering.

    Txn row({
      required String id,
      required String category,
      required num amount,
      required String party,
      int day = 12,
      int month = 10,
      DateTime? deletedAt,
    }) => Txn(
      id: id,
      date: DateTime(2026, month, day),
      monthId: '2026-${month.toString().padLeft(2, '0')}',
      type: TxnType.expense,
      party: party,
      category: category,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: 'Rafeeq',
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, month, day),
      deletedAt: deletedAt,
    );

    final octStart = DateTime(2026, 10, 1);
    final octEnd = DateTime(2026, 10, 31);

    test('what he has drawn against the month', () {
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Jalbani',
        ),
      ];
      expect(
        advanceTaken(led, who: 'Jalbani', from: octStart, to: octEnd),
        5000,
      );
    });

    test('two advances in a month add up', () {
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Jalbani',
        ),
        row(
          id: 'a2',
          category: salaryAdvanceCategory,
          amount: 2000,
          party: 'Jalbani',
          day: 20,
        ),
      ];
      expect(
        advanceTaken(led, who: 'Jalbani', from: octStart, to: octEnd),
        7000,
      );
    });

    test('another man\'s advance is not his', () {
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Someone Else',
        ),
      ];
      expect(advanceTaken(led, who: 'Jalbani', from: octStart, to: octEnd), 0);
    });

    test('his name spelled differently is still him', () {
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: ' jalbani ',
        ),
      ];
      expect(
        advanceTaken(led, who: 'Jalbani', from: octStart, to: octEnd),
        5000,
      );
    });

    test('one drawn in another month stays in that month', () {
      // An advance belongs to the wage it was taken against. One drawn in
      // September is not quietly taken out of October's pay.
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Jalbani',
          month: 9,
          day: 28,
        ),
      ];
      expect(advanceTaken(led, who: 'Jalbani', from: octStart, to: octEnd), 0);
      expect(
        advanceTaken(
          led,
          who: 'Jalbani',
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 30),
        ),
        5000,
      );
    });

    test('one drawn on the last day of the month still counts', () {
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Jalbani',
          day: 31,
        ),
      ];
      expect(
        advanceTaken(led, who: 'Jalbani', from: octStart, to: octEnd),
        5000,
      );
    });

    test('an ordinary expense in his name is not an advance', () {
      final led = [
        row(id: 'e1', category: 'Feed', amount: 5000, party: 'Jalbani'),
      ];
      expect(advanceTaken(led, who: 'Jalbani', from: octStart, to: octEnd), 0);
    });

    test('a deleted advance is not owed back', () {
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Jalbani',
          deletedAt: DateTime(2026, 10, 13),
        ),
      ];
      expect(advanceTaken(led, who: 'Jalbani', from: octStart, to: octEnd), 0);
    });

    test('once the wage is paid the advance has come off it', () {
      // And must not come off again — correcting the entry a week later
      // should not watch five thousand disappear twice.
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Jalbani',
        ),
        row(
          id: 's1',
          category: salariesCategory,
          amount: 25000,
          party: 'Jalbani',
          day: 31,
        ),
      ];
      expect(
        wagePaidIn(led, who: 'Jalbani', from: octStart, to: octEnd),
        isTrue,
      );
      expect(
        wagePaidIn(
          led,
          who: 'Jalbani',
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
        ),
        isFalse,
        reason: 'November is its own month',
      );
    });

    test('before the wage is paid, nothing says it has been', () {
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Jalbani',
        ),
      ];
      expect(
        wagePaidIn(led, who: 'Jalbani', from: octStart, to: octEnd),
        isFalse,
      );
    });

    test('the month comes out right either way round', () {
      // The advance is a cost on the day it is paid, like the rest of the
      // wage. Five thousand on the 12th and twenty-five on the 31st is the
      // same thirty thousand of salary either way.
      final led = [
        row(
          id: 'a1',
          category: salaryAdvanceCategory,
          amount: 5000,
          party: 'Jalbani',
        ),
        row(
          id: 's1',
          category: salariesCategory,
          amount: 25000,
          party: 'Jalbani',
          day: 31,
        ),
      ];
      expect(led.fold<num>(0, (a, t) => a + t.amount), 30000);
    });
  });

  group('correcting the day he left', () {
    /// The day a man leaves gets typed from memory a week after he goes, and
    /// it gets typed wrong. It is also the one date his last wage is worked
    /// out from, so it has to be correctable like any other figure here —
    /// and until now the form only held the day he started.

    final oct = (DateTime(2026, 10, 1), DateTime(2026, 10, 31));

    test('the wrong last day pays the wrong wage', () {
      // 20 October instead of 19 is one day, and one day of a 23,000 wage
      // is 767 rupees of somebody's money.
      final wrong = _e(
        basic: 23000,
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 20),
      );
      final right = _e(
        basic: 23000,
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
      );

      expect(wrong.daysOnIn(oct.$1, oct.$2), 14);
      expect(right.daysOnIn(oct.$1, oct.$2), 13);
      expect(
        wrong.payForWindow(from: oct.$1, to: oct.$2) -
            right.payForWindow(from: oct.$1, to: oct.$2),
        742,
      );
    });

    test('corrected, the wage follows it at once', () {
      final was = _e(
        basic: 23000,
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 20),
      );
      final now = was.copyWith(leftOn: DateTime(2026, 10, 15));
      expect(now.daysOnIn(oct.$1, oct.$2), 9);
      expect(now.payForWindow(from: oct.$1, to: oct.$2), 6677);
    });

    test('taking the last day off puts him back on the list', () {
      final gone = _e(
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 20),
      );
      expect(gone.isWorking, isFalse);

      final back = gone.copyWith(clearLeft: true);
      expect(back.isWorking, isTrue);
      expect(
        back.daysOnIn(oct.$1, oct.$2),
        25,
        reason: 'the 7th to the end of the month',
      );
    });

    test('and he counts in the wage bill again', () {
      final gone = _e(basic: 23000, leftOn: DateTime(2026, 10, 20));
      expect(monthlyWageBill([gone]), 0);
      expect(monthlyWageBill([gone.copyWith(clearLeft: true)]), 23000);
    });

    test('a last day on the day he started is one day worked', () {
      // He came, he was paid for the day, he did not come back.
      final e = _e(
        basic: 30000,
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 7),
      );
      expect(e.daysOnIn(oct.$1, oct.$2), 1);
      expect(e.payForWindow(from: oct.$1, to: oct.$2), 968);
    });

    test('a last day before he started leaves nothing owed', () {
      // The repo refuses it outright; if one ever reaches the books from
      // an older record, it must not pay out a negative.
      final e = _e(
        basic: 30000,
        joinedOn: DateTime(2026, 10, 20),
        leftOn: DateTime(2026, 10, 7),
      );
      expect(e.daysOnIn(oct.$1, oct.$2), 0);
      expect(e.payForWindow(from: oct.$1, to: oct.$2), 0);
    });
  });

  group('finding a man to pay', () {
    /// Two things went wrong at once when the farm picked Salaries. Tapping
    /// the name box showed nothing, because that list is built from whoever
    /// the farm has traded with and a man taken on last week has traded with
    /// nobody. And the card below said nobody was on the wage list, when
    /// what it meant was that nobody on it was still working — Gul Din had
    /// left on the 20th and was owed for the fourteen days before it.

    final oct = (DateTime(2026, 10, 1), DateTime(2026, 10, 31));

    test('a man who has left is still owed his last month', () {
      final gone = _e(
        name: 'Gul Din',
        basic: 23000,
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 20),
      );
      expect(gone.isWorking, isFalse);
      expect(gone.daysOnIn(oct.$1, oct.$2), 14);
      expect(gone.payForWindow(from: oct.$1, to: oct.$2), 10387);
    });

    test('so he is on the list the month is paid from', () {
      // What the card decides from. Working, or left with days in this
      // month still unpaid for.
      final gone = _e(
        name: 'Gul Din',
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 20),
      );
      final pickable = [
        for (final e in [gone])
          if (e.isWorking || e.daysOnIn(oct.$1, oct.$2) > 0) e.name,
      ];
      expect(pickable, ['Gul Din']);
    });

    test('and off it once that month is behind him', () {
      final gone = _e(
        name: 'Gul Din',
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 20),
      );
      final nov = (DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      final pickable = [
        for (final e in [gone])
          if (e.isWorking || e.daysOnIn(nov.$1, nov.$2) > 0) e.name,
      ];
      expect(pickable, isEmpty);
    });

    test('an empty farm and a farm of leavers are not the same thing', () {
      // Saying "nobody is on the wage list" when somebody is sends the farm
      // off to write down a man it has already written down.
      final nobody = <Employee>[];
      final leaver = [
        _e(
          name: 'Gul Din',
          joinedOn: DateTime(2026, 10, 7),
          leftOn: DateTime(2026, 10, 20),
        ),
      ];
      expect(nobody.isEmpty, isTrue);
      expect(leaver.isEmpty, isFalse);
      expect(leaver.where((e) => e.isWorking), isEmpty);
      expect(leaver.where((e) => e.daysOnIn(oct.$1, oct.$2) > 0), hasLength(1));
    });

    test('somebody still working is on it for any month since he started', () {
      final here = _e(name: 'Jalbani', joinedOn: DateTime(2026, 1, 1));
      expect(here.daysOnIn(oct.$1, oct.$2), 31);
      final nov = (DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      expect(here.daysOnIn(nov.$1, nov.$2), 30);
    });
  });

  group('a wage goes to somebody on the wage list', () {
    /// What happened without this. Sixteen thousand of advance went to
    /// "Gawalo Rafiq Jatt" typed into the name box, and the man was put on
    /// the wage list afterwards under the same name. Two records of one man,
    /// and a wage at month end that cannot find the advance to take it off —
    /// which is the whole reason advances are written down.
    ///
    /// It is also why the wage list exists. A salary is the one cost the
    /// farm pays every month with no invoice behind it; the record is what
    /// stands under it instead, and a payment with no record under it is the
    /// thing the list was built to stop.

    final jatt = _e(
      name: 'Gawalo Rafiq Jatt',
      basic: 30000,
      joinedOn: DateTime(2026, 10, 1),
    );

    Txn advance(String party, {num amount = 16000, int day = 14}) => Txn(
      id: 'adv$day-${amount.toInt()}',
      date: DateTime(2026, 10, day),
      monthId: '2026-10',
      type: TxnType.expense,
      party: party,
      category: salaryAdvanceCategory,
      amount: amount,
      paid: true,
      paidOnCreate: true,
      handledBy: 'Rafeeq',
      note: '',
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, day),
    );

    bool onTheList(List<Employee> crew, String who) =>
        crew.any((e) => partyKey(e.name) == partyKey(who));

    test('a name on the list passes', () {
      expect(onTheList([jatt], 'Gawalo Rafiq Jatt'), isTrue);
    });

    test('a name nobody has written down does not', () {
      expect(onTheList([jatt], 'Some Other Man'), isFalse);
      expect(onTheList(const [], 'Gawalo Rafiq Jatt'), isFalse);
    });

    test('and an empty name least of all', () {
      expect(onTheList([jatt], ''), isFalse);
      expect(onTheList([jatt], '   '), isFalse);
    });

    test('spelled a little differently is still him', () {
      // Which is also why his advance, paid before he was written down,
      // is not lost: the two match on the same normalised name.
      expect(onTheList([jatt], ' gawalo  rafiq jatt '), isTrue);
    });

    test('an advance paid before he was registered still comes off', () {
      // His real case. The advance went out on the 14th under a typed
      // name; he went on the wage list on the 20th. Nothing is stranded.
      final led = [advance('Gawalo Rafiq Jatt')];
      expect(
        advanceTaken(
          led,
          who: jatt.name,
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 31),
        ),
        16000,
      );
    });

    test('and his wage that month is short by it', () {
      final led = [advance('Gawalo Rafiq Jatt')];
      final drawn = advanceTaken(
        led,
        who: jatt.name,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );
      expect(
        jatt.payForWindow(
              from: DateTime(2026, 10, 1),
              to: DateTime(2026, 10, 31),
            ) -
            drawn,
        14000,
      );
    });

    test('an advance under a name off by more than spacing is stranded', () {
      // The case the guard exists to prevent: two records of one man. The
      // farm can still see it, under the typed name, but no wage finds it.
      final led = [advance('Gawalo Rafeeq')];
      expect(
        advanceTaken(
          led,
          who: jatt.name,
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 31),
        ),
        0,
      );
    });
  });

  group('one payment covering more than a month', () {
    /// The farm's own case, in its own words: "is ki salary 20 se start ho ke
    /// 30 Nov tak generate ki jae, taake advance bhi adjust ho jaye."
    ///
    /// A man taken on on the 20th of October, paid at the end of November
    /// for the whole of it — October's last days and all of November — so
    /// that the sixteen thousand he drew in October comes off the same
    /// payment. Asked a month at a time, that advance sat in a month nobody
    /// was paying for and never came off at all.

    final jatt = _e(
      name: 'Gawalo Rafiq Jatt',
      basic: 24000,
      joinedOn: DateTime(2026, 10, 20),
    );

    final from = DateTime(2026, 10, 20);
    final to = DateTime(2026, 11, 30);

    test('October\'s last days and the whole of November', () {
      // 20 to 31 October is twelve days; November is a whole month.
      expect(jatt.daysOnIn(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), 12);
      expect(jatt.daysOnIn(DateTime(2026, 11, 1), DateTime(2026, 11, 30)), 30);
      expect(jatt.daysOnBetween(from, to), 42);
    });

    test('and his pay for it is 33,600', () {
      // 24,000 x 12/30 for October, plus a whole month of November.
      expect(jatt.payForWindow(from: from, to: to), 33290);
    });

    test('less the advance, he is handed 17,600', () {
      // Which is the figure the farm came for.
      expect(jatt.payForWindow(from: from, to: to) - 16000, 17290);
    });

    test('and the advance is found, because the range reaches back to it', () {
      final drawn = Txn(
        id: 'advoct',
        date: DateTime(2026, 10, 22),
        monthId: '2026-10',
        type: TxnType.expense,
        party: 'Gawalo Rafiq Jatt',
        category: salaryAdvanceCategory,
        amount: 16000,
        paid: true,
        paidOnCreate: true,
        handledBy: 'Rafeeq',
        note: '',
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 22),
      );

      expect(advanceTaken([drawn], who: jatt.name, from: from, to: to), 16000);

      // November alone would have missed it entirely, which is the whole
      // reason the range exists.
      expect(
        advanceTaken(
          [drawn],
          who: jatt.name,
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
        ),
        0,
      );
    });

    test('a month is thirty days of pay even when it has thirty-one', () {
      // Counted as one run of days, October would pay thirty-one thirtieths
      // of a month. The farm's month is thirty days whatever the calendar
      // says, so each month is asked on its own and capped.
      final old = _e(name: 'Old Hand', basic: 30000, joinedOn: DateTime(2020));
      expect(
        old.payForWindow(
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 31),
        ),
        30000,
      );
    });

    test('two whole months is two months of pay', () {
      final old = _e(name: 'Old Hand', basic: 30000, joinedOn: DateTime(2020));
      expect(
        old.payForWindow(
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 11, 30),
        ),
        60000,
      );
    });

    test('days off come off the whole payment, once', () {
      expect(jatt.payForWindow(from: from, to: to, daysOff: 3), 30890);
    });

    test('and never below nothing, however many days off', () {
      expect(jatt.payForWindow(from: from, to: to, daysOff: 90), 0);
    });

    test('a man who left inside the range is paid to his last day', () {
      final gone = _e(
        name: 'Gone',
        basic: 24000,
        joinedOn: DateTime(2026, 10, 20),
        leftOn: DateTime(2026, 11, 10),
      );
      // Twelve days of October and ten of November.
      expect(gone.daysOnBetween(from, to), 22);
      expect(gone.payForWindow(from: from, to: to), 17290);
    });

    test('a range entirely before he started pays nothing', () {
      expect(
        jatt.payForWindow(
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 9, 30),
        ),
        0,
      );
    });

    test('and one whole month is still one whole wage', () {
      // The ordinary case has not moved. A run of days that happens to be
      // exactly a month pays exactly a month, whichever month it is.
      final old = _e(name: 'Old Hand', basic: 30000, joinedOn: DateTime(2020));
      for (final m in [2, 4, 7, 11]) {
        expect(
          old.payForWindow(
            from: DateTime(2026, m, 1),
            to: DateTime(2026, m + 1, 0),
          ),
          30000,
          reason: 'month $m',
        );
      }
    });
  });

  group('what is actually handed to him on payday', () {
    /// One sum, written down once. The card shows this figure and the entry
    /// form saves it; while they each worked it out for themselves they
    /// agreed, which is true of every figure this app has ever ended up
    /// giving two answers to, right up until it was not.

    final jatt = _e(
      name: 'Gawalo Rafiq Jatt',
      basic: 24000,
      joinedOn: DateTime(2026, 10, 20),
    );

    final oct = DateTime(2026, 10, 1);
    final octEnd = DateTime(2026, 10, 31);
    final nov = DateTime(2026, 11, 1);
    final novEnd = DateTime(2026, 11, 30);

    test('the wage, less what he drew against it', () {
      expect(wageToHand(who: jatt, from: nov, to: novEnd, drawn: 16000), 8000);
    });

    test('across a run of days it is the same arithmetic', () {
      // His own case: October's last twelve days and all of November.
      expect(
        wageToHand(
          who: jatt,
          from: DateTime(2026, 10, 20),
          to: novEnd,
          drawn: 16000,
        ),
        17290,
      );
    });

    test('nothing drawn means the whole wage', () {
      expect(wageToHand(who: jatt, from: nov, to: novEnd), 24000);
    });

    test('once the wage is on the books the advance is not taken twice', () {
      // It came off the first time. Taking it off again would hand him the
      // same deduction a second time.
      expect(
        wageToHand(
          who: jatt,
          from: nov,
          to: novEnd,
          drawn: 16000,
          wagePaidAlready: true,
        ),
        24000,
      );
    });

    test('drawing more than the month comes to leaves nothing, not a debt', () {
      expect(wageToHand(who: jatt, from: nov, to: novEnd, drawn: 30000), 0);
    });

    test('days off come off before the advance does', () {
      // Three days of November off a 24,000 wage is 2,400.
      expect(wageToHand(who: jatt, from: nov, to: novEnd, daysOff: 3), 21600);
      expect(
        wageToHand(who: jatt, from: nov, to: novEnd, daysOff: 3, drawn: 16000),
        5600,
      );
    });

    test('a month he was not here for owes him nothing', () {
      expect(wageToHand(who: jatt, from: oct, to: octEnd, drawn: 0), 9290);
      expect(
        wageToHand(
          who: jatt,
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 8, 31),
        ),
        0,
      );
    });
  });
}
