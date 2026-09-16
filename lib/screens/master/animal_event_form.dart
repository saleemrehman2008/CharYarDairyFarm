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

/// Adding a line to an animal's record: a vaccination, an illness, a
/// treatment, an insemination, a milk reading.
///
/// Anything that cost money is written into the farm's books at the same time,
/// so a year of vet bills cannot quietly sit outside the accounts.
class AnimalEventFormScreen extends StatefulWidget {
  const AnimalEventFormScreen({super.key, required this.animal});

  final Animal animal;

  @override
  State<AnimalEventFormScreen> createState() => _AnimalEventFormScreenState();
}

class _AnimalEventFormScreenState extends State<AnimalEventFormScreen> {
  final _what = TextEditingController();
  final _cost = TextEditingController();
  final _litres = TextEditingController();
  final _weight = TextEditingController();
  final _handledBy = TextEditingController();

  EventKind _kind = EventKind.vaccination;
  DateTime _date = DateTime.now();
  DateTime? _nextDue;
  PayVia _payVia = PayVia.cash;
  bool _book = true;
  File? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _litres.text = widget.animal.dailyLitres > 0
        ? qty(widget.animal.dailyLitres)
        : '';
  }

  @override
  void dispose() {
    _what.dispose();
    _cost.dispose();
    _litres.dispose();
    _weight.dispose();
    _handledBy.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1400,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;
    setState(() => _photo = File(picked.path));
  }

  Future<void> _pickDate({required bool next}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: next ? (_nextDue ?? now) : _date,
      firstDate: next ? now : DateTime(now.year - 25),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (next) {
        _nextDue = picked;
      } else {
        _date = picked;
      }
    });
  }

  Future<void> _save() async {
    final cost = num.tryParse(_cost.text.trim()) ?? 0;
    final litres = num.tryParse(_litres.text.trim()) ?? 0;

    if (_kind == EventKind.milkReading && litres <= 0) {
      toast(context, 'How many litres a day?');
      return;
    }
    if (_kind == EventKind.weight &&
        (num.tryParse(_weight.text.trim()) ?? 0) <= 0) {
      toast(context, 'What did she weigh?');
      return;
    }
    if (_kind != EventKind.milkReading && _what.text.trim().isEmpty) {
      toast(context, 'Write down what happened.');
      return;
    }
    if (cost > 0 && _book && _handledBy.text.trim().isEmpty) {
      toast(context, 'Who paid for it? Fill that in first.');
      return;
    }

    setState(() => _busy = true);
    try {
      await AnimalRepo.logEvent(
        context.read<Session>().actor,
        widget.animal,
        kind: _kind,
        date: _date,
        what: _what.text.trim(),
        cost: cost,
        litres: _kind == EventKind.milkReading ? litres : 0,
        weightKg: num.tryParse(_weight.text.trim()) ?? 0,
        nextDueOn: _nextDue,
        photo: _photo,
        bookCost: _book,
        payVia: _payVia,
        handledBy: _handledBy.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Added to ${widget.animal.tag}');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cost = num.tryParse(_cost.text.trim()) ?? 0;

    return FarmScaffold(
      title: 'Add to ${widget.animal.tag}',
      showBack: true,
      body: PageBody(
        children: [
          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Picker<EventKind>(
                  label: 'What happened',
                  value: _kind,
                  items: [for (final k in EventKind.chooseable) (k, k.label)],
                  onChanged: (v) => setState(() {
                    _kind = v;
                    if (!v.repeats) _nextDue = null;
                  }),
                ),
                const SizedBox(height: T.gap),
                _DateField(
                  label: 'When',
                  value: _date,
                  onTap: _busy ? null : () => _pickDate(next: false),
                ),
                const SizedBox(height: T.gap),

                if (_kind == EventKind.milkReading)
                  Field(
                    label: 'Litres a day',
                    controller: _litres,
                    keyboardType: TextInputType.number,
                    hint: 'What she is giving now',
                  )
                else if (_kind == EventKind.weight)
                  Field(
                    label: 'Weight (kg)',
                    controller: _weight,
                    keyboardType: TextInputType.number,
                  ),

                if (_kind == EventKind.milkReading || _kind == EventKind.weight)
                  const SizedBox(height: T.gap),

                Field(
                  label: _kind == EventKind.milkReading
                      ? 'Note (optional)'
                      : 'What happened',
                  controller: _what,
                  maxLines: 2,
                  hint: switch (_kind) {
                    EventKind.vaccination => 'FMD, second dose',
                    EventKind.illness => 'Off her feed, temperature',
                    EventKind.treatment => 'Vet came, gave antibiotics',
                    EventKind.insemination =>
                      'Semen from the Nili-Ravi bull, second attempt',
                    EventKind.pregnancyCheck => 'Confirmed pregnant',
                    _ => '',
                  },
                ),
              ],
            ),
          ),

          if (_kind.repeats) ...[
            const SizedBox(height: T.pad),
            RegCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('Next one due'),
                  const SizedBox(height: 4),
                  Text(
                    'Set this and the animal turns up under "Coming due" on '
                    'the register, so a dose is never missed.',
                    style: T.meta,
                  ),
                  const SizedBox(height: 8),
                  _DateField(
                    label: 'Due on',
                    value: _nextDue,
                    hint: 'Not set',
                    onTap: _busy ? null : () => _pickDate(next: true),
                    onClear: _nextDue == null
                        ? null
                        : () => setState(() => _nextDue = null),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: T.pad),
          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Kicker('Cost'),
                const SizedBox(height: 8),
                Field(
                  label: 'What it cost (Rs)',
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  hint: 'Leave empty if it cost nothing',
                  onChanged: (_) => setState(() {}),
                ),
                if (cost > 0) ...[
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    value: _book,
                    onChanged: (v) => setState(() => _book = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    activeColor: T.accent700,
                    title: Text('Book it in the accounts', style: T.body),
                    subtitle: Text(
                      'Goes in under Vet & medicine against '
                      '${widget.animal.tag}. Turn it off only if you have '
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

          const SizedBox(height: T.pad),
          RegCard(
            child: Row(
              children: [
                if (_photo != null) ...[
                  FarmPhotoView(file: _photo, size: 56),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    _photo == null
                        ? 'A picture helps — a swollen udder, the vet\'s slip, '
                              'the newborn.'
                        : 'Picture attached.',
                    style: T.meta,
                  ),
                ),
                const SizedBox(width: 8),
                GhostButton(
                  label: _photo == null ? 'Photo' : 'Retake',
                  icon: Icons.photo_camera_outlined,
                  compact: true,
                  onPressed: _busy ? null : _pickPhoto,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          PrimaryButton(label: 'Save', busy: _busy, onPressed: _save),
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

class _DateField extends StatelessWidget {
  const _DateField({
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
