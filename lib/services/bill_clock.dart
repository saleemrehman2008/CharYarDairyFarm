import 'dart:async';

/// Waits for eleven at night and then asks for the month's bills.
///
/// On the last day of the month the round is usually finished by nine or ten,
/// and each customer is billed the moment their milk is marked delivered. This
/// is for whoever was missed: at 11pm the app sweeps up the rest, so the month
/// closes itself even if nobody on the round remembered.
///
/// A Cloud Function is the proper home for a clock like this, and one is
/// written and waiting — but scheduled functions need a billing plan. Until
/// then the job runs on whichever farm phone happens to be open, which is why
/// it is safe to run many times and from several phones at once.
class BillClock {
  BillClock(this._onDue);

  final Future<void> Function() _onDue;

  /// 11pm, farm time.
  static const hour = 23;

  Timer? _timer;
  bool _stopped = false;

  void start() {
    _stopped = false;
    _schedule();
  }

  void _schedule() {
    if (_stopped) return;
    _timer?.cancel();
    _timer = Timer(untilNextRun(DateTime.now()), () async {
      try {
        await _onDue();
      } catch (_) {
        // Tomorrow night, or the next time the app opens.
      }
      _schedule();
    });
  }

  /// How long until the next 11pm. A phone left open overnight gets one run a
  /// night; a phone opened at midday waits until the evening.
  static Duration untilNextRun(DateTime from) {
    var target = DateTime(from.year, from.month, from.day, hour);
    if (!target.isAfter(from)) {
      target = DateTime(from.year, from.month, from.day + 1, hour);
    }
    return target.difference(from);
  }

  void dispose() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}
