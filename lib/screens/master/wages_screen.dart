import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../i18n/samjhao.dart';
import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/accounting.dart';
import '../../services/txn_repo.dart';
import '../../services/employee_repo.dart';
import '../../services/month_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../shared/statement_screen.dart';
import '../../widgets/investment_card.dart' show TotalRow;
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

  /// Takes a record off the wage list for good.
  ///
  /// Only one nothing has been paid against. [EmployeeRepo.remove] is the
  /// one that decides, and it refuses with the reason — a man who has been
  /// paid is marked as having left instead, so the figures in the months
  /// he was paid in keep a name.
  Future<void> _remove() async {
    final l = L.read(context);
    final e = widget.who;
    final ok = await confirm(
      context,
      title: l.t('Take this record off?'),
      body: l.t2(
        '%s comes off the wage list for good. Only a record nothing has '
        'been paid against can go — if a wage has been paid to him the '
        'app will say so and leave him alone.',
        e.name,
      ),
      confirmLabel: l.t('Remove'),
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await EmployeeRepo.remove(
        context.read<Session>().actor,
        e,
        ledger: context.read<FarmStore>().ledger,
      );
      if (mounted) toast(context, l.t2('%s removed', e.name));
    } catch (err) {
      if (mounted) toast(context, '$err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Gives up on what a man still owes against advances.
  ///
  /// Named in figures and confirmed, because it is a loss the farm is
  /// taking and the only person who sees it is whoever pressed this.
  Future<void> _giveUp(Employee e, num owed) async {
    final box = TextEditingController(text: '${owed.round()}');
    final said = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.surface,
        title: Text('Not coming back?', style: T.cardTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${e.name} still owes ${rs(owed)} against advances. Give up '
              'on it and the farm takes it as a loss on today, the advance '
              'is closed, and it stops being offered against his wages.',
              style: T.meta,
            ),
            const SizedBox(height: T.gap),
            Field(
              label: 'How much is not coming back',
              controller: box,
              keyboardType: TextInputType.number,
              prefix: 'Rs ',
            ),
            const SizedBox(height: 8),
            Text(
              'No money moves. It went the day the advance went — this '
              'only says it is not coming back.',
              style: T.meta,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: T.bodyMid),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, num.tryParse(box.text.trim()) ?? 0),
            child: Text(
              'Give up on it',
              style: T.bodyMid.copyWith(color: T.moneyDue),
            ),
          ),
        ],
      ),
    );
    box.dispose();
    if (said == null || !mounted) return;

    final take = said > owed ? owed : said;
    if (take <= 0) {
      toast(context, 'Put a figure in.');
      return;
    }

    setState(() => _busy = true);
    try {
      await TxnRepo.giveUpOnAdvance(
        context.read<Session>().actor,
        who: e.name,
        amount: take,
      );
      if (mounted) toast(context, 'Written off ${rs(take)}');
    } catch (err) {
      if (mounted) toast(context, 'Could not do it. $err');
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
            e.allowance <= 0
                ? l.t('A month')
                : e.allowanceFor.trim().isEmpty
                ? l.t3('%s wage · %s allowance', rs(e.basic), rs(e.allowance))
                // Named, because an allowance nobody can put a word to is
                // a figure nobody can be asked about six months later.
                : l.t4(
                    '%s wage · %s allowance (%s)',
                    rs(e.basic),
                    rs(e.allowance),
                    e.allowanceFor.trim(),
                  ),
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

          // What he still owes against advances already drawn.
          //
          // It was only ever shown inside the salary entry, which is one
          // screen too late: whoever is paying decides what to hand a man
          // before opening the form, and cannot decide it without knowing
          // what he is already carrying.
          Builder(
            builder: (context) {
              final owed = advanceOwed(
                context.watch<FarmStore>().ledger,
                who: e.name,
              );
              if (owed <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: T.moneyDue),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Samjhao(
                            term: 'Advance still owed',
                            child: Text(
                              l.t('Advance still owed'),
                              style: T.meta.copyWith(color: T.moneyDue),
                            ),
                          ),
                        ),
                        Text(
                          rs(owed),
                          style: T.bodyMid.copyWith(color: T.moneyDue),
                        ),
                      ],
                    ),
                    // When it is not coming back. The same act as giving
                    // up on money a customer owes, and the only way to
                    // close an advance that will never come off a wage.
                    const SizedBox(height: 7),
                    GhostButton(
                      label: l.t('Not coming back'),
                      icon: Icons.money_off,
                      compact: true,
                      danger: true,
                      onPressed: _busy ? null : () => _giveUp(e, owed),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GhostButton(
                label: l.t('Loan'),
                icon: Icons.account_balance_outlined,
                compact: true,
                onPressed: _busy ? null : () => showGiveLoan(context, e),
              ),
              GhostButton(
                label: l.t('If he leaves'),
                icon: Icons.exit_to_app,
                compact: true,
                onPressed: _busy ? null : () => showSettleUp(context, e),
              ),
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
              // A record typed in twice on the same morning. The one with
              // a wage behind it refuses and says why — those figures are
              // in months the co-founders have been paid out of.
              GhostButton(
                label: l.t('Remove'),
                icon: Icons.delete_outline,
                compact: true,
                danger: true,
                onPressed: _busy ? null : _remove,
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
  late final _allowanceFor = TextEditingController(
    text: widget.editing?.allowanceFor ?? '',
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
    _allowanceFor.dispose();
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
          allowanceFor: _allowanceFor.text,
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
          allowanceFor: _allowanceFor.text,
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
          padding: const EdgeInsetsDirectional.fromSTEB(
            T.pad,
            14,
            T.pad,
            T.pad,
          ),
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
              // What the allowance is for, in the farm's own words. A
              // figure with no name is one nobody can be asked about six
              // months later, and it rides onto the wage and the slip.
              if (allowance > 0) ...[
                const SizedBox(height: T.gap),
                Field(
                  label: l.t('What the allowance is for'),
                  controller: _allowanceFor,
                  hint: l.t('Doodh, chai, kamra…'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
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

/// Where a man stands if he walks off the farm today.
///
/// The farm's own question, and the one it had no way to answer. Nobody
/// joins on the first: a gawala taken on on the 20th of October is owed to
/// the 19th of November, and he is paid along the way as the days build up.
/// When he says he is going, two figures decide everything — what is left
/// to hand him, or how many more days he owes before the two sides meet —
/// and both were being worked out on the back of a receipt, differently
/// each time.
Future<void> showSettleUp(BuildContext context, Employee who) {
  final store = context.read<FarmStore>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    builder: (_) => ChangeNotifierProvider<FarmStore>.value(
      value: store,
      child: _SettleSheet(who: who),
    ),
  );
}

class _SettleSheet extends StatefulWidget {
  const _SettleSheet({required this.who});

  final Employee who;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  /// The day he would stop. Today unless somebody says otherwise — the
  /// farm does not always ask on the day a man goes, and "if he works to
  /// Friday, what then" is the same question with a different date in it.
  late DateTime _upTo = widget.who.leftOn ?? DateTime.now();

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _upTo,
      // Not before he started: there is nothing to settle for days he was
      // not here. Forward is open, because the whole use of this is asking
      // what a few more days would do.
      firstDate: widget.who.joinedOn,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _upTo = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final who = widget.who;
    final s = settleUp(context.watch<FarmStore>().ledger, who, upTo: _upTo);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          T.pad,
          T.pad,
          T.pad,
          T.pad,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('If he leaves'), style: T.screenTitle),
            const SizedBox(height: 3),
            Text(
              l.t3(
                '%s · on the farm since %s',
                who.name,
                fmtDateFull(who.joinedOn),
              ),
              style: T.meta,
            ),
            const SizedBox(height: T.pad),

            Kicker(l.t('Last working day')),
            const SizedBox(height: 6),
            GhostButton(
              label: fmtDateFull(s.upTo),
              icon: Icons.calendar_today_outlined,
              onPressed: _pickDay,
            ),
            const SizedBox(height: 5),
            Text(
              l.t(
                'Move it forward to see what a few more days would do, or '
                'back to the day he actually stopped.',
              ),
              style: T.meta,
            ),
            const SizedBox(height: T.pad),

            // The working, in the order a person would say it out loud.
            RegCard(
              child: Column(
                children: [
                  TotalRow(
                    label: l.t2('%s days worked', '${s.daysWorked}'),
                    value: s.earned,
                    tone: T.accent700,
                  ),
                  TotalRow(
                    label: l.t('Wages already paid'),
                    value: s.paid,
                    tone: T.moneyOut,
                  ),
                  if (s.advanceOwed > 0)
                    TotalRow(
                      label: l.t('Advance still owed'),
                      value: s.advanceOwed,
                      tone: T.moneyDue,
                    ),
                  if (s.loanOwed > 0)
                    TotalRow(
                      label: l.t('Loan still owed'),
                      value: s.loanOwed,
                      tone: T.moneyDue,
                    ),
                  const Divider(height: 16),
                  TotalRow(
                    label: s.farmOwes
                        ? l.t('The farm owes him')
                        : s.heOwes
                        ? l.t('He has had more than he has worked for')
                        : l.t('Square — neither owes the other'),
                    // One figure, one meaning: what the farm owes him,
                    // and below nothing when he has drawn ahead of his
                    // work. A minus sign says it faster than a sentence.
                    value: s.net,
                    tone: s.farmOwes
                        ? T.moneyDue
                        : s.heOwes
                        ? T.moneyOut
                        : T.moneyIn,
                    strong: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: T.gap),

            // And what to do about it, said as a sentence rather than left
            // for somebody to work out from the figures above.
            RegCard(
              wash: s.heOwes ? T.moneyOutWash : T.moneyGetWash,
              child: Text(
                s.farmOwes
                    ? l.t2(
                        'Hand him %s and his account is closed.',
                        rs(s.toPay),
                      )
                    : s.heOwes
                    ? l.t4(
                        'Nothing is owed to him. He would have to work %s '
                            'more days — to %s — for his account to come to '
                            'nothing, at %s a day.',
                        '${s.daysToSquare}',
                        fmtDateFull(s.squareOn),
                        rs(s.aDay.round()),
                      )
                    : l.t(
                        'His account is already square. Nothing is owed '
                        'either way.',
                      ),
                style: T.body,
              ),
            ),
            const SizedBox(height: T.gap),
            Text(
              l.t(
                'Worked out to today, both ends counted, each month against '
                'its own length — so a February worked right through pays '
                'the same as an October. Nothing is written down by looking '
                'at this.',
              ),
              style: T.meta,
            ),
            const SizedBox(height: T.pad),
          ],
        ),
      ),
    );
  }
}

/// Lending money to somebody on the wage list.
///
/// Two figures and a day: what he is being lent, and what comes off each
/// month. The instalment is written on his record and offered on every
/// wage after this, never imposed — the farm may want to take less in a
/// hard month, and what it leaves stays on his name.
///
/// The money leaves as an ordinary entry, the same row the entry form
/// would write for it. Nothing here is a private path into the books.
Future<void> showGiveLoan(BuildContext context, Employee who) {
  final store = context.read<FarmStore>();
  final session = context.read<Session>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider<FarmStore>.value(value: store),
        ChangeNotifierProvider<Session>.value(value: session),
      ],
      child: _LoanSheet(who: who),
    ),
  );
}

class _LoanSheet extends StatefulWidget {
  const _LoanSheet({required this.who});

  final Employee who;

  @override
  State<_LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends State<_LoanSheet> {
  final _amount = TextEditingController();
  late final _monthly = TextEditingController(
    text: widget.who.loanMonthly > 0
        ? widget.who.loanMonthly.round().toString()
        : '',
  );
  final _handledBy = TextEditingController();
  DateTime _day = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _monthly.dispose();
    _handledBy.dispose();
    super.dispose();
  }

  num get _said => num.tryParse(_amount.text.trim()) ?? 0;
  num get _each => num.tryParse(_monthly.text.trim()) ?? 0;

  Future<void> _give(FarmStore store) async {
    final l = L.read(context);
    if (_said <= 0) {
      toast(context, l.t('Add the total amount.'));
      return;
    }
    if (_handledBy.text.trim().isEmpty) {
      toast(
        context,
        l.t(
          'This one is needed. Money that moved with no name '
          'against it cannot be asked about a month later.',
        ),
      );
      return;
    }

    final actor = context.read<Session>().actor;
    setState(() => _busy = true);
    try {
      await MonthRepo.ensureOpen(store.month.id);
      await TxnRepo.add(
        actor: actor,
        monthId: store.month.id,
        type: TxnType.payment,
        party: widget.who.name,
        category: staffLoanCategory,
        amount: _said,
        paid: true,
        note: _each > 0 ? '${rs(_each)} a month agreed' : '',
        handledBy: _handledBy.text.trim(),
        date: _day,
      );
      // What was agreed, kept on his record so every wage after this can
      // offer it without anybody having to remember.
      await EmployeeRepo.edit(actor, widget.who, loanMonthly: _each);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.t2('%s lent', rs(_said)));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final owing = staffLoanOwed(store.ledger, who: widget.who.name);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            T.pad,
            T.pad,
            T.pad,
            T.pad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.t('Lend him money'), style: T.screenTitle),
              const SizedBox(height: 3),
              Text(
                l.t(
                  'Not a cost. The farm still owns it — it is in his pocket '
                  'rather than in the box — and it comes back off his wages '
                  'at whatever you take each month.',
                ),
                style: T.meta,
              ),
              const SizedBox(height: T.pad),

              if (owing > 0) ...[
                RegCard(
                  wash: T.moneyDueWash,
                  child: Text(
                    l.t2('He still owes %s on an earlier loan.', rs(owing)),
                    style: T.body.copyWith(color: T.moneyDue),
                  ),
                ),
                const SizedBox(height: T.gap),
              ],

              Field(
                label: l.t('How much'),
                controller: _amount,
                keyboardType: TextInputType.number,
                prefix: 'Rs ',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: T.gap),
              Field(
                label: l.t('Coming off each month'),
                controller: _monthly,
                keyboardType: TextInputType.number,
                prefix: 'Rs ',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 5),
              Text(
                _said > 0 && _each > 0
                    ? l.t2(
                        'About %s months at that rate. It is offered on every '
                            'wage and you may always take less.',
                        '${(_said / _each).ceil()}',
                      )
                    : l.t(
                        'What you agreed with him. It is offered on every '
                        'wage after this, never imposed.',
                      ),
                style: T.meta,
              ),
              const SizedBox(height: T.gap),
              WhoField(
                label: l.t('Paid by'),
                controller: _handledBy,
                hint: l.t('Whose hands it went out through'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: T.gap),
              Kicker(l.t('Which day')),
              const SizedBox(height: 6),
              GhostButton(
                label: fmtDateFull(_day),
                icon: Icons.calendar_today_outlined,
                onPressed: _busy
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _day,
                          firstDate: DateTime(_day.year - 2),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && mounted) {
                          setState(() => _day = picked);
                        }
                      },
              ),
              const SizedBox(height: T.pad),
              PrimaryButton(
                label: l.t('Hand it over'),
                icon: Icons.check,
                busy: _busy,
                onPressed: _busy || _said <= 0 ? null : () => _give(store),
              ),
              const SizedBox(height: T.pad),
            ],
          ),
        ),
      ),
    );
  }
}
