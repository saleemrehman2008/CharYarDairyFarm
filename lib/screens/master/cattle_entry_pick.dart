import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/animal_repo.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/ui.dart';

/// Picking the mother of a calf that was registered on its own.
///
/// The farm registered the calves as their own animals — which they are —
/// and nothing tied them to the cow they came out of. Her page said nothing
/// about them and theirs said nothing about her, so a question a dairy asks
/// every day ("whose calf is that one") had no answer in the register.
///
/// Returns the mother, or a null inside a [Picked] for "nobody". A plain
/// null is a cancel, the same as everywhere else a choice is offered.
Future<({Animal? mother})?> pickMother(
  BuildContext context, {
  required List<Animal> animals,
  required Animal forAnimal,
  Animal? current,
}) {
  // Any female but herself. Not only the ones giving milk: a heifer bought
  // in calf is a mother before she is a milker.
  final mothers =
      animals.where((a) => a.id != forAnimal.id && a.sex == Sex.female).toList()
        ..sort(Animal.byTag);

  return showModalBottomSheet<({Animal? mother})>(
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
            Text('Whose calf is this?', style: T.screenTitle),
            const SizedBox(height: 4),
            Text(
              'Tying the two together puts her calf on her page and her name '
              'on its. Nothing about the money changes.',
              style: T.meta,
            ),
            const SizedBox(height: T.pad),
            RegCard(
              stripe: current == null ? T.moneyIn : T.n400,
              onTap: () => Navigator.pop(sheet, (mother: null)),
              child: Text(
                'Nobody — it is not out of any of these',
                style: T.body,
              ),
            ),
            const SizedBox(height: 8),
            for (final m in mothers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RegCard(
                  stripe: m.id == current?.id ? T.moneyIn : T.accent600,
                  onTap: () => Navigator.pop(sheet, (mother: m)),
                  child: Row(
                    children: [
                      Expanded(child: Text(m.label, style: T.bodyMid)),
                      Text(m.summary, style: T.meta),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

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
