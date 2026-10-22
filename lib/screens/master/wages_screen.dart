import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/employee_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../shared/statement_screen.dart';
import '../../widgets/ui.dart';

/// Who the farm pays a wage to, and what it pays them.
///
/// Until now a salary was an expense entry with a name typed into it, which
/// meant the month somebody wrote "Jalbani" and the month somebody wrote
/// "jalbani sb" were two different men as far as the books were concerned,
/// and neither had a wage on record to check the payment against. A wage is
/// the one cost the farm pays every month with no invoice behind it: the only
/// thing standing under it is a record somebody wrote down and the other
/// three can read.
class WagesScreen extends StatelessWidget {
  const WagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return FarmScaffold(
      title: l.t('Wages'),
      showBack: true,
      body: StreamBuilder<List<Employee>>(
        stream: EmployeeRepo.watch(),
        builder: (context, snap) {
          final all = snap.data ?? const <Employee>[];
          final working = all.where((e) => e.isWorking).toList();
          final gone = all.where((e) => !e.isWorking).toList();

          return PageBody(
            children: [
              HeroCard(
                label: l.t('Every month in wages'),
                value: rs(monthlyWageBill(all)),
                gradient: T.washOf(T.moneyOut),
                note: l.t2(
                  working.length == 1 ? '%s man' : '%s men',
                  '${working.length}',
                ),
              ),
              const SizedBox(height: T.pad),

              PrimaryButton(
                label: l.t('Put somebody on the wage list'),
                icon: Icons.person_add_alt,
                onPressed: () => showEmployeeForm(context),
              ),
              const SizedBox(height: 6),
              Text(
                l.t(
                  'What they are owed a month, and the two numbers the farm '
                  'needs to find them again. The salary entry then picks a '
                  'name off this list and works the figure out from the '
                  'record rather than from memory.',
                ),
                style: T.meta,
              ),

              if (all.isEmpty) ...[
                const SizedBox(height: T.pad),
                EmptyNote(
                  l.t(
                    'Nobody on the wage list yet. Anybody the farm pays every '
                    'month belongs here — the man who milks, the one who '
                    'cleans, the one who walks the round.',
                  ),
                ),
              ],

              if (working.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionTitle(l.t('Working here')),
                const SizedBox(height: 8),
                for (final e in working)
                  Padding(
                    padding: const EdgeInsets.only(bottom: T.gap),
                    child: _Card(who: e),
                  ),
              ],

              // Kept rather than removed. Their wages are in months that are
              // closed, and a figure whose name has vanished costs an evening
              // to work out two years later.
              if (gone.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionTitle(l.t('No longer here')),
                const SizedBox(height: 8),
                for (final e in gone)
                  Padding(
                    padding: const EdgeInsets.only(bottom: T.gap),
                    child: _Card(who: e),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatefulWidget {
  const _Card({required this.who});

  final Employee who;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _busy = false;

  /// Everything the farm has paid him, on one page.
  ///
  /// The store goes with it. This card is built inside a provider the
  /// navigator does not sit beneath, so a page pushed without it asked an
  /// empty farm for his wages and threw — and a release build draws a thrown
  /// widget as a blank page, which is what the farm saw. The same page
  /// reached from Accounts worked, because that one is pushed from inside
  /// the provider.
  void _slip(Employee e) {
    final store = context.read<FarmStore>();
    final session = context.read<Session>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<FarmStore>.value(value: store),
            ChangeNotifierProvider<Session>.value(value: session),
          ],
          child: StatementScreen(party: e.name, title: 'Salary slip'),
        ),
      ),
    );
  }

  Future<void> _left() async {
    final l = L.read(context);
    final e = widget.who;
    final ok = await confirm(
      context,
      title: l.t2('%s has left?', e.name),
      body: l.t(
        'He comes off the wage list from today. His record stays where it is '
        '— the months he was paid for are already closed, and a figure whose '
        'name has gone is worth nothing to anybody.',
      ),
      confirmLabel: l.t('He has left'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await EmployeeRepo.left(context.read<Session>().actor, e);
    } catch (err) {
      if (mounted) toast(context, '$err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back() async {
    setState(() => _busy = true);
    try {
      await EmployeeRepo.backOn(context.read<Session>().actor, widget.who);
    } catch (err) {
      if (mounted) toast(context, '$err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final e = widget.who;

    return RegCard(
      stripe: e.isWorking ? T.accent600 : T.n400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.name,
                  style: T.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                rs(e.monthly),
                style: T.num22.copyWith(
                  color: e.isWorking ? T.moneyOut : T.n600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            e.allowance > 0
                ? l.t3('%s wage · %s allowance', rs(e.basic), rs(e.allowance))
                : l.t('A month'),
            style: T.meta,
          ),
          const SizedBox(height: 8),

          // The two numbers the farm needs to find him again, shown the way
          // the card and the phone print them.
          if (e.cnic.isNotEmpty || e.mobile.isNotEmpty) ...[
            Row(
              children: [
                if (e.cnic.isNotEmpty) ...[
                  Icon(Icons.badge_outlined, size: 14, color: T.n600),
                  const SizedBox(width: 4),
                  Text(cnicShown(e.cnic), style: T.meta),
                ],
                if (e.cnic.isNotEmpty && e.mobile.isNotEmpty)
                  const SizedBox(width: 12),
                if (e.mobile.isNotEmpty) ...[
                  Icon(Icons.phone_outlined, size: 14, color: T.n600),
                  const SizedBox(width: 4),
                  Text(mobileShown(e.mobile), style: T.meta),
                ],
              ],
            ),
            const SizedBox(height: 5),
          ],

          Text(
            e.isWorking
                ? l.t2('Since %s', fmtDateFull(e.joinedOn))
                : l.t3(
                    '%s to %s',
                    fmtDateFull(e.joinedOn),
                    fmtDateFull(e.leftOn!),
                  ),
            style: T.meta,
          ),
          if (e.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(e.note, style: T.meta),
          ],

          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GhostButton(
                label: l.t('Salary slip'),
                icon: Icons.receipt_long_outlined,
                compact: true,
                onPressed: _busy ? null : () => _slip(e),
              ),
              GhostButton(
                label: l.t('Change'),
                icon: Icons.edit_outlined,
                compact: true,
                onPressed: _busy ? null : () => showEmployeeForm(context, e),
              ),
              if (e.isWorking)
                GhostButton(
                  label: l.t('He has left'),
                  icon: Icons.logout,
                  compact: true,
                  danger: true,
                  onPressed: _busy ? null : _left,
                )
              else
                GhostButton(
                  label: l.t('He is back'),
                  icon: Icons.login,
                  compact: true,
                  onPressed: _busy ? null : _back,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Writing somebody down, or correcting what was written.
Future<void> showEmployeeForm(BuildContext context, [Employee? editing]) {
  final session = context.read<Session>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    builder: (_) => ChangeNotifierProvider<Session>.value(
      value: session,
      child: _Form(editing: editing),
    ),
  );
}

class _Form extends StatefulWidget {
  const _Form({this.editing});

  final Employee? editing;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _cnic = TextEditingController(
    text: widget.editing == null ? '' : cnicShown(widget.editing!.cnic),
  );
  late final _mobile = TextEditingController(
    text: widget.editing == null ? '' : mobileShown(widget.editing!.mobile),
  );
  late final _basic = TextEditingController(
    text: (widget.editing?.basic ?? 0) > 0
        ? widget.editing!.basic.toStringAsFixed(0)
        : '',
  );
  late final _allowance = TextEditingController(
    text: (widget.editing?.allowance ?? 0) > 0
        ? widget.editing!.allowance.toStringAsFixed(0)
        : '',
  );
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  late DateTime _joined = widget.editing?.joinedOn ?? DateTime.now();

  /// His last day, where he has one.
  ///
  /// It gets typed from memory a week after he goes and it gets typed
  /// wrong, and it is the one date his last wage is worked out from. So it
  /// sits here beside the day he started and is corrected the same way.
  late DateTime? _left = widget.editing?.leftOn;

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _cnic.dispose();
    _mobile.dispose();
    _basic.dispose();
    _allowance.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickJoined() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joined,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _joined = picked);
  }

  /// Never before the day he started, because a man cannot leave before he
  /// arrives and a wage worked out from those two dates would come to
  /// nothing at all.
  Future<void> _pickLeft() async {
    final from = _left ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: from.isBefore(_joined) ? _joined : from,
      firstDate: _joined,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _left = picked);
  }

  Future<void> _save() async {
    final l = L.read(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, l.t('Who is this?'));
      return;
    }

    // Said before anything is written, and said about the field it is
    // about. A number refused after the sheet closes is a number typed
    // again from memory.
    final badCnic = cnicWrong(_cnic.text);
    if (badCnic != null) {
      toast(context, l.t(badCnic));
      return;
    }
    final badMobile = mobileWrong(_mobile.text);
    if (badMobile != null) {
      toast(context, l.t(badMobile));
      return;
    }

    final basic = num.tryParse(_basic.text.trim()) ?? 0;
    if (basic <= 0) {
      toast(context, l.t('What is he paid a month?'));
      return;
    }
    final allowance = num.tryParse(_allowance.text.trim()) ?? 0;

    setState(() => _busy = true);
    try {
      final actor = context.read<Session>().actor;
      final editing = widget.editing;
      if (editing == null) {
        await EmployeeRepo.add(
          actor,
          name: name,
          basic: basic,
          allowance: allowance,
          cnic: _cnic.text,
          mobile: _mobile.text,
          joinedOn: _joined,
          leftOn: _left,
          note: _note.text,
        );
      } else {
        await EmployeeRepo.edit(
          actor,
          editing,
          name: name,
          basic: basic,
          allowance: allowance,
          cnic: _cnic.text,
          mobile: _mobile.text,
          joinedOn: _joined,
          leftOn: _left,
          stillHere: _left == null,
          note: _note.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t('Saved'));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final editing = widget.editing;
    final basic = num.tryParse(_basic.text.trim()) ?? 0;
    final allowance = num.tryParse(_allowance.text.trim()) ?? 0;

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
              Text(
                editing == null ? l.t('On the wage list') : editing.name,
                style: T.screenTitle,
              ),
              const SizedBox(height: T.pad),

              Field(label: l.t('Name'), controller: _name),
              const SizedBox(height: T.gap),

              // Both of these are shaped as they are typed, so a wrong one
              // is plain on the screen rather than discovered on saving.
              Field(
                label: l.t('CNIC'),
                controller: _cnic,
                keyboardType: TextInputType.number,
                hint: '42101-1234567-1',
                textCapitalization: TextCapitalization.none,
                shape: const [CnicFormat()],
              ),
              const SizedBox(height: T.gap),
              Field(
                label: l.t('Mobile'),
                controller: _mobile,
                keyboardType: TextInputType.phone,
                hint: '0300-1234567',
                textCapitalization: TextCapitalization.none,
                shape: const [MobileFormat()],
              ),
              const SizedBox(height: T.gap),

              Row(
                children: [
                  Expanded(
                    child: Field(
                      label: l.t('Wage a month (Rs)'),
                      controller: _basic,
                      keyboardType: TextInputType.number,
                      hint: '0',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: T.gap),
                  Expanded(
                    child: Field(
                      label: l.t('Allowance (Rs)'),
                      controller: _allowance,
                      keyboardType: TextInputType.number,
                      hint: '0',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (basic > 0) ...[
                const SizedBox(height: 6),
                Text(
                  l.t2('%s a full month', rs(basic + allowance)),
                  style: T.meta.copyWith(color: T.moneyOut),
                ),
              ],

              const SizedBox(height: T.pad),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Kicker(l.t('Joined')),
                        const SizedBox(height: 5),
                        GhostButton(
                          label: fmtDateFull(_joined),
                          icon: Icons.event_outlined,
                          compact: true,
                          onPressed: _pickJoined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: T.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Kicker(l.t('Last day')),
                        const SizedBox(height: 5),
                        GhostButton(
                          label: _left == null
                              ? l.t('Still here')
                              : fmtDateFull(_left!),
                          icon: _left == null
                              ? Icons.event_available_outlined
                              : Icons.event_busy_outlined,
                          compact: true,
                          onPressed: _pickLeft,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_left != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.t(
                          'His last month is worked out from these two days. '
                          'Both of them count as worked.',
                        ),
                        style: T.meta,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      label: l.t('He has not left'),
                      compact: true,
                      onPressed: () => setState(() => _left = null),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: T.pad),
              Field(
                label: l.t('Note'),
                controller: _note,
                hint: l.t('Anything worth remembering'),
                maxLines: 2,
              ),

              const SizedBox(height: 18),
              PrimaryButton(
                label: l.t('Save'),
                icon: Icons.check,
                busy: _busy,
                onPressed: _busy ? null : _save,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps a CNIC looking like a CNIC while it is being typed.
class CnicFormat extends TextInputFormatter {
  const CnicFormat();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue was,
    TextEditingValue now,
  ) {
    final d = cnicDigits(now.text);
    if (d.length > 13) return was;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 5 || i == 12) b.write('-');
      b.write(d[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// And a mobile number looking like one.
class MobileFormat extends TextInputFormatter {
  const MobileFormat();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue was,
    TextEditingValue now,
  ) {
    final d = mobileDigits(now.text);
    if (d.length > 11) return was;
    final text = d.length > 4 ? '${d.substring(0, 4)}-${d.substring(4)}' : d;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
