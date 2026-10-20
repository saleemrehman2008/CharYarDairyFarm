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
  group('what a man is owed for a month', () {
    test('a full month is the wage and whatever goes on top of it', () {
      final e = _e(basic: 25000, allowance: 3000);
      expect(e.monthly, 28000);
      expect(e.payFor(), 28000);
    });

    test('days off come off the whole month, not off the wage alone', () {
      // The tea money and the room are for a month of work as much as the
      // wage is. Taking the days off the basic only would quietly pay a man
      // who was away ten days more per working day than one who was not.
      final e = _e(basic: 25000, allowance: 5000);
      expect(e.payFor(daysOff: 3), 27000);
      expect(e.cutFor(daysOff: 3), 3000);
    });

    test('a thirty day month, whatever the calendar says', () {
      // Which is how the farm has always counted it and how the man expects
      // it to be counted. Dividing February by 28 saves rupees and costs
      // more than it saves.
      final e = _e(basic: 30000);
      expect(e.payFor(daysOff: 1), 29000);
      expect(e.payFor(daysOff: 15), 15000);
    });

    test('a whole month away is nothing, and no further', () {
      final e = _e(basic: 30000);
      expect(e.payFor(daysOff: 30), 0);
      expect(e.payFor(daysOff: 45), 0, reason: 'never a negative wage');
    });

    test('no days off takes nothing off', () {
      final e = _e(basic: 28000);
      expect(e.payFor(daysOff: 0), 28000);
      expect(e.payFor(daysOff: -2), 28000);
    });

    test('an awkward figure comes out whole', () {
      // Nobody is paid 24,333.333 rupees.
      final e = _e(basic: 25000, allowance: 2000);
      final pay = e.payFor(daysOff: 7);
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
      final daysOn = e.daysOnIn(oct.$1, oct.$2);
      expect(e.payFor(daysOn: daysOn), 13000);
      expect(e.cutFor(daysOn: daysOn), 17000);
    });

    test('days off come off on top of the days he was here', () {
      // He was here for thirteen of them and took two of those off, so he
      // is owed eleven.
      final e = _e(
        basic: 30000,
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
      );
      final daysOn = e.daysOnIn(oct.$1, oct.$2);
      expect(e.payFor(daysOn: daysOn, daysOff: 2), 11000);
    });

    test('a man who started before the month gets the whole of it', () {
      final e = _e(joinedOn: DateTime(2026, 1, 1), basic: 30000);
      expect(e.daysOnIn(oct.$1, oct.$2), 30);
      expect(e.payFor(daysOn: e.daysOnIn(oct.$1, oct.$2)), 30000);
    });

    test('a long month is still thirty days of pay', () {
      // October has 31. Nobody is paid 31/30 of a month.
      final e = _e(joinedOn: DateTime(2020, 1, 1), basic: 30000);
      expect(e.daysOnIn(oct.$1, oct.$2), 30);
      expect(e.payFor(daysOn: 31), 30000);
    });

    test('a month after he left is nothing at all', () {
      final e = _e(
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
      );
      final nov = (DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      expect(e.daysOnIn(nov.$1, nov.$2), 0);
      expect(e.payFor(daysOn: 0), 0);
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
      expect(e.payFor(daysOn: 28), 28000);
    });

    test('away the whole of a part month leaves nothing owed', () {
      final e = _e(
        joinedOn: DateTime(2026, 10, 7),
        leftOn: DateTime(2026, 10, 19),
        basic: 30000,
      );
      expect(e.payFor(daysOn: 13, daysOff: 13), 0);
      expect(e.payFor(daysOn: 13, daysOff: 40), 0);
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
}
