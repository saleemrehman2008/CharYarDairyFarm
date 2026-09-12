import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/animal_repo.dart';
import '../../services/db.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import 'animal_event_form.dart';
import 'animal_form.dart';
import 'cattle_screen.dart' show AnimalPhoto;

/// One animal: its picture, its tag, and everything that has happened to it.
class AnimalScreen extends StatelessWidget {
  const AnimalScreen({super.key, required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    // Read the live copy so the page updates as entries are added.
    final store = context.watch<FarmStore>();
    final a = store.animalById(animal.id) ?? animal;

    return FarmScaffold(
      title: a.label,
      showBack: true,
      body: StreamBuilder<List<AnimalEvent>>(
        stream: Db.watchAnimalEvents(a.id),
        builder: (context, snap) {
          final events = snap.data ?? const <AnimalEvent>[];
          final spent = events.fold<num>(0, (t, e) => t + e.cost);

          return PageBody(
            children: [
              _Header(animal: a),
              const SizedBox(height: T.pad),
              _Figures(animal: a, spent: spent, store: store),
              const SizedBox(height: T.pad),
              _Actions(animal: a, store: store),

              const SizedBox(height: 22),
              const SectionTitle('History'),
              if (snap.connectionState == ConnectionState.waiting &&
                  events.isEmpty)
                const EmptyNote('Reading the record…')
              else if (events.isEmpty)
                const EmptyNote(
                  'Nothing recorded yet. Vaccinations, illnesses, births and '
                  'milk readings all go here.',
                )
              else
                for (final e in events) _EventRow(event: e),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({required this.animal});

  final Animal animal;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _busy = false;

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1400,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await AnimalRepo.setPhoto(
        context.read<Session>().actor,
        widget.animal,
        File(picked.path),
      );
      if (mounted) toast(context, 'Photo updated');
    } catch (e) {
      if (mounted) toast(context, 'Could not upload the photo. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimalPhoto(url: a.photoUrl, size: 110),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(a.tag, style: T.num28)),
                        Tag(
                          a.status.label,
                          tone: a.status.isHere
                              ? TagTone.good
                              : TagTone.neutral,
                        ),
                      ],
                    ),
                    if (a.name.isNotEmpty) Text(a.name, style: T.cardTitle),
                    const SizedBox(height: 4),
                    Text(a.summary, style: T.meta),
                    if (a.motherTag != null)
                      Text('Out of ${a.motherTag}', style: T.meta),
                    const SizedBox(height: 8),
                    GhostButton(
                      label: 'Change photo',
                      icon: Icons.photo_camera_outlined,
                      compact: true,
                      onPressed: _busy ? null : _changePhoto,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (a.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(a.note, style: T.body),
          ],
          const SizedBox(height: 10),
          Text(
            'Write ${a.tag} on the ear tag. That is how this page is found '
            'again when you are standing in the shed.',
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({
    required this.animal,
    required this.spent,
    required this.store,
  });

  final Animal animal;
  final num spent;
  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final calves = store.animals.where((x) => x.motherId == animal.id).toList();

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (animal.isMilking) ...[
            _Line(
              'Milk a day',
              '${qty(animal.dailyLitres)} L',
              note: 'At the last reading',
            ),
            const SizedBox(height: 10),
          ],
          if (animal.price > 0) ...[
            _Line(
              'Bought for',
              rs(animal.price),
              note: animal.boughtOn == null
                  ? 'Counted as something the farm owns'
                  : 'On ${fmtDateFull(animal.boughtOn!)}',
            ),
            const SizedBox(height: 10),
          ],
          _Line(
            'Spent on her since',
            rs(spent - animal.price < 0 ? 0 : spent - animal.price),
            note: 'Vet, medicine, insemination — everything booked here',
          ),
          if (calves.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Line(
              calves.length == 1 ? 'Calf' : 'Calves',
              calves.map((c) => c.tag).join(', '),
              note: 'Registered out of her',
            ),
          ],
          if (animal.nextDueOn != null && animal.status.isHere) ...[
            const SizedBox(height: 10),
            _Line(
              animal.nextDueWhat ?? 'Next check',
              fmtDateFull(animal.nextDueOn!),
              note: animal.overdue() ? 'Overdue' : 'Due',
              bad: animal.overdue(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.note = '', this.bad = false});

  final String label;
  final String value;
  final String note;
  final bool bad;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: T.bodyMid),
            if (note.isNotEmpty) Text(note, style: T.meta),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Text(
        value,
        style: T.bodyMid.copyWith(
          color: bad ? const Color(0xFF8C2F20) : T.n800,
        ),
      ),
    ],
  );
}

class _Actions extends StatefulWidget {
  const _Actions({required this.animal, required this.store});

  final Animal animal;
  final FarmStore store;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _busy = false;

  void _push(Widget screen) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider<FarmStore>.value(
        value: widget.store,
        child: screen,
      ),
    ),
  );

  Future<void> _leave(AnimalStatus status) async {
    final a = widget.animal;
    final sold = status == AnimalStatus.sold;
    final price = TextEditingController();
    final who = TextEditingController();
    var via = PayVia.cash;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.bg,
        shape: const RoundedRectangleBorder(),
        title: Text(
          '${a.label} — ${status.label.toLowerCase()}',
          style: T.screenTitle,
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sold
                    ? 'She comes off the herd. The sale goes into the books '
                          'as income.'
                    : 'She comes off the herd. Her record and everything '
                          'spent on her stays.',
                style: T.body,
              ),
              if (sold) ...[
                const SizedBox(height: T.gap),
                Field(
                  label: 'Sold for (Rs)',
                  controller: price,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: T.gap),
                const Kicker('How the money came'),
                const SizedBox(height: 6),
                Segmented<PayVia>(
                  value: via,
                  compact: true,
                  options: [for (final v in PayVia.values) (v, v.label)],
                  onChanged: (v) => setDialogState(() => via = v),
                ),
                const SizedBox(height: T.gap),
                Field(label: 'Received by', controller: who),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(sold ? 'Sold' : 'Confirm'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      price.dispose();
      who.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      await AnimalRepo.setStatus(
        context.read<Session>().actor,
        a,
        status: status,
        price: num.tryParse(price.text.trim()) ?? 0,
        payVia: via,
        handledBy: who.text.trim(),
      );
      if (mounted) toast(context, '${a.tag} — ${status.label.toLowerCase()}');
    } catch (e) {
      if (mounted) toast(context, 'Could not save that. $e');
    } finally {
      price.dispose();
      who.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    final canBirth = a.sex == Sex.female && a.status.isHere;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrimaryButton(
            label: 'Add to the record',
            onPressed: _busy
                ? null
                : () => _push(AnimalEventFormScreen(animal: a)),
          ),
          const SizedBox(height: 8),
          Text(
            'Vaccination, illness, treatment, insemination, a milk reading — '
            'anything worth knowing later.',
            style: T.meta,
          ),
          if (canBirth) ...[
            const SizedBox(height: T.gap),
            GhostButton(
              label: 'She gave birth',
              icon: Icons.child_care_outlined,
              onPressed: _busy
                  ? null
                  : () => _push(
                      AnimalFormScreen(mother: a, bornOn: DateTime.now()),
                    ),
            ),
          ],
          if (a.status.isHere) ...[
            const SizedBox(height: T.gap),
            const Divider(height: 1),
            const SizedBox(height: T.gap),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GhostButton(
                  label: 'Sold',
                  compact: true,
                  onPressed: _busy ? null : () => _leave(AnimalStatus.sold),
                ),
                GhostButton(
                  label: 'Died',
                  compact: true,
                  danger: true,
                  onPressed: _busy ? null : () => _leave(AnimalStatus.dead),
                ),
                if (a.species == Species.qurbani)
                  GhostButton(
                    label: 'Qurbani done',
                    compact: true,
                    onPressed: _busy
                        ? null
                        : () => _leave(AnimalStatus.slaughtered),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: T.gap),
            GhostButton(
              label: 'Put back on the farm',
              compact: true,
              onPressed: _busy
                  ? null
                  : () async {
                      await AnimalRepo.reinstate(
                        context.read<Session>().actor,
                        a,
                      );
                      if (context.mounted) toast(context, '${a.tag} is back');
                    },
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of history.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final AnimalEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.photoUrl.isNotEmpty) ...[
            AnimalPhoto(url: e.photoUrl, size: 46),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.kind.label, style: T.bodyMid)),
                    Text(fmtDate(e.date), style: T.meta),
                  ],
                ),
                if (e.what.isNotEmpty) Text(e.what, style: T.body),
                const SizedBox(height: 2),
                Text(
                  [
                    if (e.litres > 0) '${qty(e.litres)} L a day',
                    if (e.weightKg > 0) '${qty(e.weightKg)} kg',
                    if (e.calfTag != null) 'Calf ${e.calfTag}',
                    if (e.hasCost)
                      '${rs(e.cost)}${e.isBooked ? ' · in the books' : ' · not booked'}',
                    if (e.nextDueOn != null) 'Next ${fmtDate(e.nextDueOn!)}',
                    if (e.byName.isNotEmpty) e.byName,
                  ].join(' · '),
                  style: T.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
