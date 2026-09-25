import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/animal_repo.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/photo.dart';
import '../../widgets/ui.dart';

/// Registering an animal, whether it was bought or born here.
///
/// The photo is required. A tag can be lost or swapped and a black buffalo
/// looks like every other black buffalo; the picture is what makes the
/// register worth anything a year from now.
class AnimalFormScreen extends StatefulWidget {
  const AnimalFormScreen({
    super.key,
    this.mother,
    this.bornOn,
    this.cameWith = false,
  });

  /// Set when this is a calf being registered from its mother's page.
  final Animal? mother;
  final DateTime? bornOn;

  /// The calf arrived with her rather than being born here — bought as a
  /// pair, which is how a milch buffalo is usually sold. Nothing about the
  /// money changes; what changes is that her record does not claim a birth
  /// that never happened.
  final bool cameWith;

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _litres = TextEditingController();
  final _note = TextEditingController();
  final _handledBy = TextEditingController();

  late Species _species = widget.mother?.species ?? Species.buffalo;
  Sex _sex = Sex.female;
  late DateTime? _bornOn = widget.bornOn;
  DateTime? _boughtOn;
  PayVia _payVia = PayVia.cash;
  bool _book = true;
  File? _photo;
  bool _busy = false;

  /// A milch buffalo is not sold on her own. She comes with her calf, one
  /// price is paid for the pair, and the calf has to go on the register — she
  /// is the farm's, and one day she will be milking or sold. Registering her
  /// afterwards is a second job somebody forgets, so it is asked here.
  bool _withCalf = false;
  Sex _calfSex = Sex.female;
  final _calfName = TextEditingController();
  final _calfMonths = TextEditingController();
  File? _calfPhoto;

  bool get _isCalf => widget.mother != null;

  /// Only worth asking about an animal that gives milk, and only when she is
  /// being bought rather than born here.
  bool get _canHaveCalf => !_isCalf && _species.milks && _sex == Sex.female;

  @override
  void dispose() {
    _name.dispose();
    _calfName.dispose();
    _calfMonths.dispose();
    _price.dispose();
    _litres.dispose();
    _note.dispose();
    _handledBy.dispose();
    super.dispose();
  }

  Future<void> _pickCalf(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _calfPhoto = File(picked.path));
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1400,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;
    setState(() => _photo = File(picked.path));
  }

  Future<void> _pickDate({required bool born}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (born ? _bornOn : _boughtOn) ?? now,
      firstDate: DateTime(now.year - 25),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (born) {
        _bornOn = picked;
      } else {
        _boughtOn = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_photo == null) {
      toast(context, 'A photo is required — take one of the animal.');
      return;
    }
    final price = num.tryParse(_price.text.trim()) ?? 0;
    if (_price.text.trim().isNotEmpty && price <= 0) {
      toast(context, 'That price does not look right.');
      return;
    }
    if (price > 0 && _book && _handledBy.text.trim().isEmpty) {
      toast(context, 'Who paid for it? Fill that in first.');
      return;
    }
    // The calf gets the same treatment as her mother, because she is on the
    // register the same way: her own tag, her own picture, her own age. A
    // register with one animal missing a photo is a register somebody stops
    // trusting.
    final calfMonths = num.tryParse(_calfMonths.text.trim());
    if (_withCalf && _canHaveCalf) {
      if (_calfPhoto == null) {
        toast(context, 'A photo of the calf is needed too.');
        return;
      }
      if (calfMonths == null || calfMonths < 0) {
        toast(context, 'How many months old is the calf?');
        return;
      }
    }

    final actor = context.read<Session>().actor;
    setState(() => _busy = true);
    try {
      final animal = _isCalf
          ? await (widget.cameWith
                ? AnimalRepo.recordCameWith
                : AnimalRepo.recordBirth)(
              actor,
              widget.mother!,
              species: _species,
              sex: _sex,
              photo: _photo!,
              date: _bornOn ?? DateTime.now(),
              name: _name.text.trim(),
              what: _note.text.trim(),
            )
          : await AnimalRepo.add(
              actor,
              species: _species,
              sex: _sex,
              photo: _photo!,
              name: _name.text.trim(),
              bornOn: _bornOn,
              boughtOn: price > 0 ? (_boughtOn ?? DateTime.now()) : null,
              price: price,
              note: _note.text.trim(),
              dailyLitres: num.tryParse(_litres.text.trim()) ?? 0,
              bookPurchase: _book,
              payVia: _payVia,
              handledBy: _handledBy.text.trim(),
            );

      // Her calf, straight after her and out of the same price. Nothing is
      // booked for it: what was paid was paid for the pair and all of it is
      // already on the mother, so a second entry would be the same money on
      // the books twice.
      Animal? calf;
      if (_withCalf && _canHaveCalf && _calfPhoto != null) {
        final months = (calfMonths ?? 0).round();
        calf = await AnimalRepo.recordCameWith(
          actor,
          animal,
          species: _species,
          sex: _calfSex,
          photo: _calfPhoto!,
          date: DateTime.now().subtract(Duration(days: months * 30)),
          name: _calfName.text.trim(),
          what: months == 0
              ? 'Came with ${animal.tag}'
              : 'Came with ${animal.tag}, about $months months old',
        );
      }

      if (!mounted) return;
      Navigator.pop(context, animal);
      toast(
        context,
        calf == null
            ? 'Registered ${animal.tag} — put that number on the tag'
            : 'Registered ${animal.tag} and ${calf.tag} — put those numbers '
                  'on the tags',
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not register it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = num.tryParse(_price.text.trim()) ?? 0;

    return FarmScaffold(
      title: _isCalf ? 'Register the calf' : 'Add an animal',
      showBack: true,
      body: PageBody(
        children: [
          if (_isCalf)
            Text(
              widget.cameWith
                  ? 'Came with ${widget.mother!.label} when she was bought. '
                        'The price was paid for the pair and it is already on '
                        'her, so this one costs nothing of its own — and her '
                        'record will not say she calved here.'
                  : 'Out of ${widget.mother!.label}. The birth goes on her '
                        'record and the calf gets a tag of its own.',
              style: T.meta,
            )
          else
            Text(
              'Every animal gets a tag number to write on its ear tag. The '
              'photo is required.',
              style: T.meta,
            ),
          const SizedBox(height: 14),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Kicker('Photo'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FarmPhotoView(file: _photo, size: 96),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GhostButton(
                            label: 'Take a photo',
                            icon: Icons.photo_camera_outlined,
                            compact: true,
                            onPressed: _busy
                                ? null
                                : () => _pick(ImageSource.camera),
                          ),
                          const SizedBox(height: 8),
                          GhostButton(
                            label: 'From the gallery',
                            icon: Icons.image_outlined,
                            compact: true,
                            onPressed: _busy
                                ? null
                                : () => _pick(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: T.pad),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Picker<Species>(
                  label: 'What is it',
                  value: _species,
                  items: [for (final s in Species.values) (s, s.label)],
                  onChanged: (v) => setState(() => _species = v),
                ),
                const SizedBox(height: T.gap),
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
                  hint: 'Kaali, Chandni…',
                ),
                const SizedBox(height: T.gap),
                _DateRow(
                  label: 'Born on',
                  value: _bornOn,
                  hint: 'Roughly is fine',
                  onTap: _busy ? null : () => _pickDate(born: true),
                  onClear: _bornOn == null
                      ? null
                      : () => setState(() => _bornOn = null),
                ),
                if (_species.milks && _sex == Sex.female) ...[
                  const SizedBox(height: T.gap),
                  Field(
                    label: 'Milk a day (litres)',
                    controller: _litres,
                    keyboardType: TextInputType.number,
                    hint: '0 if she is not milking',
                  ),
                ],
                const SizedBox(height: T.gap),
                Field(
                  label: 'Note',
                  controller: _note,
                  maxLines: 2,
                  hint: 'Markings, where she came from, anything worth knowing',
                ),
              ],
            ),
          ),

          // A milch buffalo is not sold on her own. One price buys the pair
          // and the calf has to go on the register — she is the farm's, and
          // one day she will be milking or sold. Asking here is the only
          // moment anybody is certainly thinking about it; asked later it is
          // a second job that gets forgotten, and then the register is short
          // an animal the farm owns.
          if (_canHaveCalf) ...[
            const SizedBox(height: T.pad),
            RegCard(
              stripe: _withCalf ? T.accent : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchRow(
                    title: 'She came with a calf',
                    note:
                        'One price for the pair. The calf gets a tag of its '
                        'own and costs nothing on top — what was paid is '
                        'already on the mother.',
                    value: _withCalf,
                    onChanged: (v) => setState(() => _withCalf = v),
                  ),
                  if (_withCalf) ...[
                    const Divider(height: 22),
                    const Kicker('The calf'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FarmPhotoView(file: _calfPhoto, size: 96),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GhostButton(
                                label: 'Take a photo',
                                icon: Icons.photo_camera_outlined,
                                compact: true,
                                onPressed: _busy
                                    ? null
                                    : () => _pickCalf(ImageSource.camera),
                              ),
                              const SizedBox(height: 8),
                              GhostButton(
                                label: 'From the gallery',
                                icon: Icons.image_outlined,
                                compact: true,
                                onPressed: _busy
                                    ? null
                                    : () => _pickCalf(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: T.gap),
                    const Kicker('Male or female'),
                    const SizedBox(height: 6),
                    Segmented<Sex>(
                      value: _calfSex,
                      compact: true,
                      options: [for (final s in Sex.values) (s, s.label)],
                      onChanged: (v) => setState(() => _calfSex = v),
                    ),
                    const SizedBox(height: T.gap),
                    Field(
                      label: 'How many months old',
                      controller: _calfMonths,
                      keyboardType: TextInputType.number,
                      hint: 'Roughly is fine',
                    ),
                    const SizedBox(height: T.gap),
                    Field(
                      label: 'Name (if it has one)',
                      controller: _calfName,
                      hint: 'Optional',
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (!_isCalf) ...[
            const SizedBox(height: T.pad),
            RegCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('Bought'),
                  const SizedBox(height: 8),
                  Field(
                    label: 'Price paid (Rs)',
                    controller: _price,
                    keyboardType: TextInputType.number,
                    hint: 'Leave empty if it was born here',
                    onChanged: (_) => setState(() {}),
                  ),
                  if (price > 0) ...[
                    const SizedBox(height: T.gap),
                    _DateRow(
                      label: 'Bought on',
                      value: _boughtOn,
                      hint: 'Today',
                      onTap: _busy ? null : () => _pickDate(born: false),
                      onClear: _boughtOn == null
                          ? null
                          : () => setState(() => _boughtOn = null),
                    ),
                    const SizedBox(height: T.gap),
                    CheckboxListTile(
                      value: _book,
                      onChanged: (v) => setState(() => _book = v ?? true),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      activeColor: T.accent700,
                      title: Text('Book it in the accounts', style: T.body),
                      subtitle: Text(
                        'Goes in as a cattle purchase — something the farm '
                        'owns, not money spent. Turn this off if you have '
                        'already entered it under Accounts.',
                        style: T.meta,
                      ),
                    ),
                    if (_book) ...[
                      const SizedBox(height: 6),
                      const Kicker('How it was paid'),
                      const SizedBox(height: 6),
                      Segmented<PayVia>(
                        value: _payVia,
                        compact: true,
                        options: [for (final v in PayVia.values) (v, v.label)],
                        onChanged: (v) => setState(() => _payVia = v),
                      ),
                      const SizedBox(height: T.gap),
                      // The same picker as everywhere else money changes
                      // hands. A name typed out by hand is a name that will
                      // be spelled two ways by the second month, and then no
                      // total under it ever adds up again.
                      WhoField(
                        label: 'Paid by',
                        controller: _handledBy,
                        hint: 'Who handed over the money',
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          PrimaryButton(
            label: _isCalf ? 'Register the calf' : 'Register the animal',
            busy: _busy,
            onPressed: _save,
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'Cancel',
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// A date on a form: tap to pick, cross to clear.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.hint = '',
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final String hint;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Kicker(label),
      const SizedBox(height: 5),
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(border: T.hair),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 17, color: T.n600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value == null ? hint : fmtDateFull(value!),
                  style: value == null
                      ? T.body.copyWith(color: T.n500)
                      : T.body,
                ),
              ),
              if (onClear != null)
                InkWell(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 16, color: T.n500),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
