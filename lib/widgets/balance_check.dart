import 'package:flutter/material.dart';

import '../i18n/words.dart';
import '../services/accounting.dart';
import '../theme/tokens.dart';
import '../util/money.dart';

/// Whether what the farm says it has matches what it actually has.
///
/// The farm is four friends' savings, and the surest way for them to fall out
/// over it is for one of them to doubt a figure and have no way to test it. So
/// the app tests it, in front of all of them: every rupee that came in, less
/// every rupee that went out or turned into an animal, against what the farm
/// is holding today. The two should be the same number.
///
/// When they are not, it says by how much rather than hiding it. A gap is
/// nearly always one entry typed twice or one never typed at all, and knowing
/// the size of it is most of the work of finding it.
class BalanceCheck extends StatelessWidget {
  const BalanceCheck({super.key, required this.money});

  final MoneySummary money;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ok = money.reconciles;
    final gap = (money.expected - money.farmMoney).abs();
    final tone = ok ? T.moneyIn : T.alert;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(T.radiusXs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 17,
            color: tone,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? l.t('Every rupee is accounted for.')
                  : l.t2(
                      '%s is not accounted for. An entry is probably missing, '
                      'or one has been typed twice.',
                      rs(gap),
                    ),
              style: T.meta.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}
