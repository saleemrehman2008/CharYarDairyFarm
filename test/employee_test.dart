import 'package:flutter_test/flutter_test.dart';

import 'package:char_yar_dairy_farm/models/models.dart';

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
}
