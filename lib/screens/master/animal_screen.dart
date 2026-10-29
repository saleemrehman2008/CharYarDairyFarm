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
import '../../widgets/photo.dart';
import '../../widgets/ui.dart';
import 'animal_correct_sheet.dart';
import 'animal_event_form.dart';
import 'animal_form.dart';

/// Opens another animal's page from a link on this one — her mother, or one
/// of her calves. The store is carried through, the same as everywhere else
/// a page is pushed from inside the register.
///
/// A mother links to her calf and the calf links back to his mother, so
/// following those links is a circle and pushing every step of it is how a
/// register turns into a pile. The farm walked one: a cow, her calf, his
/// mother again, and then five presses of Back to reach the home screen,
/// through pages it had already read.
///
/// So a page already open underneath is returned to rather than opened a
/// second time. [trail] is the animals whose pages are below this one,
/// bottom first; finding the one being asked for in it says exactly how
/// many pages to come back through, and not finding it means this is
/// somewhere new and is pushed.
/// How many pages to come back through to reach an animal already open.
///
/// Zero when it is not open below this one, which means the link leads
/// somewhere new and a page is pushed. Otherwise it counts this page and
/// every page standing between it and that one — the whole point being that
/// the farm is put back on a page it has already read rather than handed a
/// second copy of it, with the first still underneath.
int stepsBackTo(String id, List<String> trail) {
  final at = trail.indexOf(id);
  return at < 0 ? 0 : trail.length - at;
}

void _openAnimal(
  BuildContext context,
  String id, {
  required String from,
  required List<String> trail,
}) {
  // The page it is already on. Tapping it should do nothing rather than
  // lay a second copy of this page over this page.
  if (id == from) return;

  final back = stepsBackTo(id, trail);
  if (back > 0) {
    // This page, and every page between it and that one.
    for (var i = 0; i < back; i++) {
      Navigator.pop(context);
    }
    return;
  }

  final store = context.read<FarmStore>();
  final animal = store.animalById(id);
  if (animal == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider<FarmStore>.value(
        value: store,
        child: AnimalScreen(animal: animal, trail: [...trail, from]),
      ),
    ),
  );
}

/// One animal: its picture, its tag, and everything that has happened to it.
class AnimalScreen extends StatelessWidget {
  const AnimalScreen({super.key, required this.animal, this.trail = const []});

  final Animal animal;

  /// The animals whose pages are open below this one, bottom first.
  ///
  /// Empty from the register's own list, which is the floor of the stack.
  /// It grows by one every time a link is followed somewhere new, and a
  /// link back into it comes back rather than going on. See [_openAnimal].
  final List<String> trail;

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
              _Header(animal: a, trail: trail),
              const SizedBox(height: T.pad),
              _Figures(animal: a, spent: spent, store: store, trail: trail),
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
  const _Header({required this.animal, this.trail = const []});

  final List<String> trail;

  final Animal animal;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _busy = false;

  /// The master's correction sheet, carrying the store down with it — the
  /// sheet is built from the navigator's context, above the provider this
  /// page was pushed with.
  Future<void> _correct() async {
    final store = context.read<FarmStore>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: T.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
      ),
      builder: (_) => ChangeNotifierProvider<FarmStore>.value(
        value: store,
        child: AnimalCorrectSheet(animal: widget.animal),
      ),
    );
  }

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
    // Her mother as she is called today, not as she was called the day he
    // was written down. See FarmStore.motherNameOf.
    final mother = context.watch<FarmStore>().motherNameOf(a);
    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BigPhoto(animal: a),
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
                    // Her mother, and a way through to her. The register
                    // knew the link and only ever printed it.
                    if (mother != null)
                      InkWell(
                        onTap: () => _openAnimal(
                          context,
                          a.motherId!,
                          from: a.id,
                          trail: widget.trail,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Out of $mother',
                                style: T.meta.copyWith(color: T.accent700),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: T.accent700,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GhostButton(
                          label: 'Change photo',
                          icon: Icons.photo_camera_outlined,
                          compact: true,
                          onPressed: _busy ? null : _changePhoto,
                        ),
                        // Correcting what she is, which until now could only
                        // be got right on the day she was registered.
                        if (context.watch<Session>().role == Role.master)
                          GhostButton(
                            label: 'Correct the record',
                            icon: Icons.edit_outlined,
                            compact: true,
                            onPressed: _busy ? null : _correct,
                          ),
                      ],
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

/// The animal's picture at full size.
///
/// The small one is on the record already, so it appears at once; the bigger
/// one is fetched from its own document and swapped in behind it. Nobody
/// watches a grey box while a buffalo loads.
class _BigPhoto extends StatefulWidget {
  const _BigPhoto({required this.animal});

  final Animal animal;

  @override
  State<_BigPhoto> createState() => _BigPhotoState();
}

class _BigPhotoState extends State<_BigPhoto> {
  String? _full;
  String? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(_BigPhoto old) {
    super.didUpdateWidget(old);
    // A new photo was taken: the thumbnail changed, so fetch the big one again.
    if (old.animal.thumb != widget.animal.thumb) _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    final id = widget.animal.id;
    if (!force && _loadedFor == id) return;
    _loadedFor = id;
    final data = await Db.animalPhoto(id);
    if (mounted && data.isNotEmpty) setState(() => _full = data);
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      // Opened out to fill the screen. A hundred-pixel square of a black
      // buffalo tells nobody which buffalo it is, and telling them apart is
      // what the picture is on the record for.
      onTap: () => showFarmPhoto(
        context,
        data: _full ?? widget.animal.thumb,
        url: widget.animal.photoUrl,
        title: widget.animal.label,
      ),
      child: FarmPhotoView(
        data: _full ?? widget.animal.thumb,
        url: widget.animal.photoUrl,
        size: 110,
      ),
    ),
  );
}

/// One of her calves, with its own picture on it — which is the point of the
/// register: the answer to "whose calf is that" should look like the calf.
class _CalfChip extends StatelessWidget {
  const _CalfChip({required this.calf, required this.onTap});

  final Animal calf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.pill),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 11, 4),
        decoration: BoxDecoration(
          color: T.accent100,
          borderRadius: BorderRadius.circular(T.pill),
          border: Border.all(color: T.accent300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: FarmPhotoView(
                data: calf.thumb,
                url: calf.photoUrl,
                size: 26,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              calf.label,
              style: T.bodyMid.copyWith(fontSize: 12.5, color: T.accent700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Figures extends StatelessWidget {
  const _Figures({
    required this.animal,
    required this.spent,
    required this.store,
    this.trail = const [],
  });

  final Animal animal;
  final num spent;
  final FarmStore store;
  final List<String> trail;

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
          // Her calves, each one a way through to its own page rather than a
          // list of numbers to go and look up.
          if (calves.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(calves.length == 1 ? 'Calf' : 'Calves', style: T.meta),
            const SizedBox(height: 5),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final c in calves)
                  _CalfChip(
                    calf: c,
                    onTap: () => _openAnimal(
                      context,
                      c.id,
                      from: animal.id,
                      trail: trail,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text('Registered out of her', style: T.meta),
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
      Text(value, style: T.bodyMid.copyWith(color: bad ? T.alert : T.n800)),
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
                  onChanged: (_) => setDialogState(() {}),
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
                WhoField(
                  label: 'Received by',
                  controller: who,
                  hint: 'Who took the money',
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 4),
                if ((num.tryParse(price.text.trim()) ?? 0) <= 0 ||
                    who.text.trim().isEmpty)
                  Text(
                    'The price and who took the money are both needed.',
                    style: T.meta.copyWith(color: T.alert),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          StatefulBuilder(
            builder: (context, _) => TextButton(
              // A sale with no price and no name is money the books will
              // never see, so it cannot be confirmed until both are in.
              onPressed:
                  !sold ||
                      ((num.tryParse(price.text.trim()) ?? 0) > 0 &&
                          who.text.trim().isNotEmpty)
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text(sold ? 'Sold' : 'Confirm'),
            ),
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
            // A milch buffalo is usually sold with her calf beside her. The
            // calf has to go on the register — she is the farm's, and one day
            // she will be milking or sold — but she was not born here, and
            // putting her in as a birth writes something into her mother's
            // history that did not happen.
            const SizedBox(height: 8),
            GhostButton(
              label: 'A calf came with her',
              icon: Icons.pets_outlined,
              onPressed: _busy
                  ? null
                  : () => _push(
                      AnimalFormScreen(
                        mother: a,
                        bornOn: a.boughtOn ?? DateTime.now(),
                        cameWith: true,
                      ),
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
    // The calf as he is called today. See FarmStore.calfNameOf.
    final calf = context.watch<FarmStore>().calfNameOf(e);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: T.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.photoUrl.isNotEmpty) ...[
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                // A vet's slip or a wound photographed at the time. At 46
                // pixels it is a smudge; the whole reason it was taken is
                // that somebody would want to look at it later.
                onTap: () => showFarmPhoto(
                  context,
                  data: e.thumb,
                  url: e.photoUrl,
                  title: '${e.what} · ${fmtDate(e.date)}',
                ),
                child: FarmPhotoView(data: e.thumb, url: e.photoUrl, size: 46),
              ),
            ),
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
                    if (calf != null) 'Calf $calf',
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
