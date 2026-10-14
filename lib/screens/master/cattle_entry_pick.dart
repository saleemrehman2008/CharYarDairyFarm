import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/animal_repo.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/ui.dart';

/// Picking the ledger entry an animal's price was paid on.
///
/// Shared by the register and by the master's correction sheet, because the
/// farm needs it in both directions: tying a new animal to money that is
/// already in the books, and tying up the ones that were registered before
/// there was any way to say so.
///
/// Each entry carries what is left of it — the money not yet spoken for by
/// animals already registered against it — because that is the figure the
/// person is actually choosing by.
Future<Txn?> pickCattleEntry(
  BuildContext context, {
  required List<Txn> entries,
  required List<Animal> animals,
  Txn? current,
  Animal? except,
}) => showModalBottomSheet<Txn>(
  context: context,
  isScrollControlled: true,
  backgroundColor: T.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
  ),
  builder: (sheet) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(T.pad, 16, T.pad, T.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Which entry was this paid on?', style: T.screenTitle),
          const SizedBox(height: 4),
          Text(
            'Cattle and equipment bought, with what is left of each one after '
            'the animals already registered against it.',
            style: T.meta,
          ),
          const SizedBox(height: T.pad),
          if (entries.isEmpty)
            EmptyNote(
              'No cattle purchase in the books has anything left on it. '
              'Enter the money under Accounts first.',
            )
          else
            for (final t in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RegCard(
                  stripe: t.id == current?.id ? T.moneyIn : T.accent600,
                  onTap: () => Navigator.pop(sheet, t),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.party.isEmpty ? t.category : t.party,
                              style: T.bodyMid,
                            ),
                          ),
                          Text(rs(t.amount), style: T.bodyMid),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fmtDateFull(t.date)} · ${t.category}',
                        style: T.meta,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${rs(cattleLeftOn(t, animals, except: except))} '
                        'left of it',
                        style: T.meta.copyWith(
                          color: T.moneyIn,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
  ),
);
