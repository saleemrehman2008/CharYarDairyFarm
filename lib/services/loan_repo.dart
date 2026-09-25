import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';
import 'month_repo.dart';
import 'txn_repo.dart';

/// Lending one of the four some of the farm's money, and getting it back.
///
/// Two people are involved and the app says so. A co-founder asks — the
/// amount and how long they want — and the master hands it over, because he
/// is the one who actually gives them the cash and because money leaving the
/// farm has never been anybody else's to do alone. Both halves are written
/// down with whose finger pressed them.
///
/// Nothing here touches the profit. A loan going out is the farm's own money
/// moving from the box into a founder's pocket; an instalment coming back is
/// it moving the other way. Neither is earning and neither is spending, and
/// the day either is counted as one, all four of them get handed a share of a
/// rupee that was never made — or lose a share of one that was.
class LoanRepo {
  LoanRepo._();

  /// A co-founder asks. Nothing moves yet.
  static Future<String> ask({
    required Actor actor,
    required Partner partner,
    required num amount,
    required int months,
    String note = '',
  }) async {
    if (amount <= 0) throw StateError('How much?');
    if (months <= 0) throw StateError('Over how many months?');

    final doc = await Db.loans.add({
      'partnerId': partner.id,
      'name': partner.name,
      'amount': amount,
      'months': months,
      'state': LoanState.asked.name,
      'askedAt': FieldValue.serverTimestamp(),
      'note': note,
      'createdBy': actor.uid,
      'createdByName': actor.name,
    });

    await Log.write(
      actor,
      LogKind.investment,
      'asked the farm for ${rs(amount)} over $months months',
      refType: 'loan',
      refId: doc.id,
    );
    return doc.id;
  }

  /// The master hands it over. This is where the cash actually leaves.
  static Future<void> give({
    required Actor actor,
    required FounderLoan loan,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
  }) async {
    if (loan.state != LoanState.asked) return;
    final now = DateTime.now();

    await TxnRepo.add(
      actor: actor,
      monthId: MonthRepo.bookingId,
      type: TxnType.payment,
      party: loan.name,
      category: founderLoanCategory,
      amount: loan.amount,
      paid: true,
      note: 'Loan to ${loan.name} over ${loan.months} months',
      payVia: payVia,
      handledBy: handledBy,
      date: now,
    );

    await Db.loans.doc(loan.id).update({
      'state': LoanState.given.name,
      'givenAt': Timestamp.fromDate(now),
      'givenBy': actor.uid,
      'givenByName': actor.name,
    });

    await Log.write(
      actor,
      LogKind.investment,
      'lent ${loan.name} ${rs(loan.amount)} over ${loan.months} months',
      refType: 'loan',
      refId: loan.id,
    );
  }

  /// The master says no. The asking stays on the record.
  static Future<void> refuse({
    required Actor actor,
    required FounderLoan loan,
  }) async {
    if (loan.state != LoanState.asked) return;
    await Db.loans.doc(loan.id).update({'state': LoanState.refused.name});
    await Log.write(
      actor,
      LogKind.investment,
      'did not lend ${loan.name} the ${rs(loan.amount)} asked for',
      refType: 'loan',
      refId: loan.id,
    );
  }

  /// Money coming back — an instalment taken at a close, or the founder
  /// paying it in himself.
  ///
  /// A receipt, and deliberately not income. The farm is getting its own
  /// money back; nothing has been earned.
  static Future<void> repay({
    required Actor actor,
    required FounderLoan loan,
    required num amount,
    PayVia payVia = PayVia.cash,
    String handledBy = '',
    String note = '',
  }) async {
    if (amount <= 0) return;
    final taking = amount > loan.left ? loan.left : amount;
    if (taking <= 0) return;

    await TxnRepo.add(
      actor: actor,
      monthId: MonthRepo.bookingId,
      type: TxnType.receipt,
      party: loan.name,
      category: loanRepaidCategory,
      amount: taking,
      paid: true,
      note: note.isEmpty ? 'Loan instalment – ${loan.name}' : note,
      payVia: payVia,
      handledBy: handledBy,
    );

    if (loan.repaid + taking >= loan.amount) {
      await Db.loans.doc(loan.id).update({'state': LoanState.cleared.name});
    }

    await Log.write(
      actor,
      LogKind.investment,
      '${rs(taking)} came back off ${loan.name}\'s loan',
      refType: 'loan',
      refId: loan.id,
    );
  }
}
