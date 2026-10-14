import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/animal_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/ui.dart';
import 'cattle_entry_pick.dart';

/// Correcting an animal's record. The master's, and nobody else's.
///
/// The farm's own case, in its own words: somebody registered a cow as a
/// buffalo. Until now there was nothing to be done about it — the kind of
/// animal was set the moment she was registered and never asked about again,
/// so the herd count was wrong, the milk figures were wrong, and her ear said
/// B when she was a C.
///
/// Everything changed here is written into her history and into the activity
/// log, the same as a correction to a money entry. The register is a record
/// four people rely on; a record that can be quietly rewritten is worth less
/// than one that cannot be rewritten at all.
class AnimalCorrectSheet extends StatefulWidget {
  const AnimalCorrectSheet({super.key, required this.animal});

  final Animal animal;

  @override
  State<AnimalCorrectSheet> createState() => _AnimalCorrectSheetState();
}

class _AnimalCorrectSheetState extends State<AnimalCorrectSheet> {
  late final _name = TextEditingController(text: widget.animal.name);
  late final _note = TextEditingController(text: widget.animal.note);
  late final _price = TextEditingController(
    text: widget.animal.price == 0 ? '' : '${widget.animal.price.round()}',
  );
  late final _litres = TextEditingController(
    text: widget.animal.dailyLitres == 0 ? '' : qty(widget.animal.dailyLitres),
  );

  late Species _species = widget.animal.species;
  late Sex _sex = widget.animal.sex;
  late DateTime? _bornOn = widget.animal.bornOn;
  late DateTime? _boughtOn = widget.animal.boughtOn;

  /// A different entry to tie her price to, once somebody picks one.
  Txn? _linkTo;

  /// Whether to give her a tag out of the corrected letter's run. Offered
  /// only when the letter actually changes, and on by default when it does:
  /// a cow carrying a buffalo's number is a cow nobody can look up.
  bool _retag = true;

  bool _busy = false;

  bool get _letterChanges => _species.tagLetter != _tagLetter;

  String get _tagLetter => widget.animal.tag.split('-').first;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _price.dispose();
    _litres.dispose();
    super.dispose();
  }

  /// The ledger entry her price sits on: the one picked here, or failing
  /// that the one she already carries.
  Txn? _entry(FarmStore store) {
    final picked = _linkTo;
    if (picked != null) return picked;
    final id = widget.animal.purchaseTxnId;
    if (id == null) return null;
    for (final t in store.ledger) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _tie(FarmStore store) async {
    final current = _entry(store);
    // Her own entry stays on the list even when she has used all of it up,
    // or re-picking it would be impossible.
    final offered = {
      for (final t in cattleEntries(store.ledger, store.animals)) t.id: t,
      ?current?.id: ?current,
    }.values.toList()..sort((a, b) => b.date.compareTo(a.date));

    final picked = await pickCattleEntry(
      context,
      entries: offered,
      animals: store.animals,
      current: current,
      except: widget.animal,
    );
    if (picked != null && mounted) setState(() => _linkTo = picked);
  }

  Future<void> _pickDate({required bool born}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (born ? _bornOn : _boughtOn) ?? now,
      firstDate: DateTime(now.year - 25),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        if (born) {
          _bornOn = picked;
        } else {
          _boughtOn = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final store = context.read<FarmStore>();
    final price = num.tryParse(_price.text.trim()) ?? 0;
    final entry = _entry(store);

    // Her price is a share of an entry in the books, and the shares on one
    // entry cannot come to more than the entry. Her own share is left out of
    // the sum, or raising it would be measured against itself.
    if (entry != null && price > 0) {
      final room = cattleLeftOn(entry, store.animals, except: widget.animal);
      if (price > room) {
        toast(
          context,
          'Only ${rs(room)} is left on that entry. Correct the entry under '
          'Accounts if the whole price was wrong.',
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      await AnimalRepo.correct(
        context.read<Session>().actor,
        widget.animal,
        name: _name.text,
        species: _species,
        sex: _sex,
        bornOn: _bornOn,
        boughtOn: _boughtOn,
        price: price,
        dailyLitres: num.tryParse(_litres.text.trim()) ?? 0,
        note: _note.text,
        retag: _retag,
        linkTo: _linkTo?.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Record corrected');
    } catch (e) {
      if (mounted) toast(context, 'Could not correct it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final entry = _entry(store);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, T.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.n400,
                    borderRadius: BorderRadius.circular(T.pill),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Correct ${widget.animal.tag}', style: T.screenTitle),
              const SizedBox(height: 4),
              Text(
                'Everything you change here is written into her history and '
                'into the activity log, with your name on it.',
                style: T.meta,
              ),
              const SizedBox(height: T.pad),

              const Kicker('What kind of animal'),
              const SizedBox(height: 6),
              Segmented<Species>(
                value: _species,
                compact: true,
                options: [for (final s in Species.values) (s, s.label)],
                onChanged: (v) => setState(() => _species = v),
              ),

              // The ear tag. Its letter is the kind of animal, so correcting
              // one without the other leaves a number that lies.
              if (_letterChanges) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _retag,
                  onChanged: (v) => setState(() => _retag = v ?? true),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  activeColor: T.accent700,
                  title: Text('Give her a new tag', style: T.body),
                  subtitle: Text(
                    '${widget.animal.tag} starts with $_tagLetter, which '
                    'is not a ${_species.label.toLowerCase()}. A new number '
                    'out of the ${_species.tagLetter} run is written on save '
                    '— put it on her ear. The old number is kept in her '
                    'history and is never given to another animal.',
                    style: T.meta,
                  ),
                ),
              ],

              const SizedBox(height: T.pad),
              const Kicker('Male or female'),
              const SizedBox(height: 6),
              Segmented<Sex>(
                value: _sex,
                compact: true,
                options: [for (final s in Sex.values) (s, s.label)],
                onChanged: (v) => setState(() => _sex = v),
              ),

              const SizedBox(height: T.gap),
              Field(
                label: 'Name (if it has one)',
                controller: _name,
                hint: 'Optional',
              ),

              const SizedBox(height: T.gap),
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: _bornOn == null
                          ? 'Born on'
                          : fmtDateFull(_bornOn!),
                      icon: Icons.cake_outlined,
                      compact: true,
                      onPressed: _busy ? null : () => _pickDate(born: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      label: _boughtOn == null
                          ? 'Bought on'
                          : fmtDateFull(_boughtOn!),
                      icon: Icons.event_outlined,
                      compact: true,
                      onPressed: _busy ? null : () => _pickDate(born: false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: T.gap),
              Field(
                label: 'Price (Rs)',
                controller: _price,
                keyboardType: TextInputType.number,
                hint: '0',
              ),
              const SizedBox(height: 5),
              // What this figure does, because it is not only a description:
              // the day she leaves the farm she comes off the books at it.
              Text(
                entry == null
                    ? 'What she cost. She comes off the books at this figure '
                          'the day she is sold or dies, so it has to be hers '
                          'and not the whole herd\'s.'
                    : 'Her share of the entry of '
                          '${fmtDateFull(entry.date)} · ${rs(entry.amount)}. '
                          '${rs(cattleLeftOn(entry, store.animals, except: widget.animal))} '
                          'of it is free for her. If the whole price was '
                          'typed wrong, correct the entry under Accounts.',
                style: T.meta,
              ),

              // Which entry in the books her price belongs to. This is how
              // the animals registered before any of this gets fixed: delete
              // the duplicate entries under Accounts, then put each animal
              // back on the one that is left.
              const SizedBox(height: 8),
              GhostButton(
                label: entry == null
                    ? 'Tie her to an entry'
                    : 'Tied to ${fmtDateFull(entry.date)} · '
                          '${rs(entry.amount)}',
                icon: Icons.receipt_long_outlined,
                compact: true,
                onPressed: _busy ? null : () => _tie(store),
              ),

              const SizedBox(height: T.gap),
              Field(
                label: 'Milk a day (litres)',
                controller: _litres,
                keyboardType: TextInputType.number,
                hint: '0',
              ),

              const SizedBox(height: T.gap),
              Field(label: 'Note', controller: _note, maxLines: 2),

              const SizedBox(height: T.pad),
              PrimaryButton(
                label: 'Save the correction',
                icon: Icons.check,
                busy: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
