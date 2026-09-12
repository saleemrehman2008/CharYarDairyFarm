import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/month_repo.dart';
import '../../services/txn_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// One form for every kind of money that moves.
class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key, this.initialType = TxnType.sale});

  final TxnType initialType;

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  late TxnType _type = widget.initialType;
  late String _category = _type.categories.first;
  String _unit = 'L';
  bool _paid = true;
  PayVia _payVia = PayVia.cash;
  bool _busy = false;

  final _party = TextEditingController();
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _total = TextEditingController();
  final _note = TextEditingController();
  final _handledBy = TextEditingController();

  /// Guards the qty/rate/total loop so each edit only drives the others once.
  bool _syncing = false;

  @override
  void dispose() {
    _party.dispose();
    _qty.dispose();
    _rate.dispose();
    _total.dispose();
    _note.dispose();
    _handledBy.dispose();
    super.dispose();
  }

  num get _amount => num.tryParse(_total.text.trim()) ?? 0;

  /// Quantity times rate fills the total.
  void _fromQtyRate() {
    if (_syncing) return;
    final q = num.tryParse(_qty.text.trim());
    final r = num.tryParse(_rate.text.trim());
    if (q == null || r == null) return;
    _syncing = true;
    _total.text = (q * r) % 1 == 0
        ? (q * r).toInt().toString()
        : (q * r).toStringAsFixed(2);
    _syncing = false;
    setState(() {});
  }

  /// Editing the total back-solves the rate — that is how bulk pricing is
  /// entered ("240 litres for Rs 45,000").
  void _fromTotal() {
    if (_syncing) return;
    final q = num.tryParse(_qty.text.trim());
    final t = num.tryParse(_total.text.trim());
    setState(() {});
    if (q == null || q == 0 || t == null) return;
    _syncing = true;
    final rate = t / q;
    _rate.text = rate % 1 == 0
        ? rate.toInt().toString()
        : rate.toStringAsFixed(2);
    _syncing = false;
  }

  void _setType(TxnType type) {
    setState(() {
      _type = type;
      _category = type.categories.first;
      if (type.isSettlement) _paid = true;
    });
  }

  Future<void> _save() async {
    final party = _party.text.trim();
    if (party.isEmpty) {
      toast(context, 'Who is this entry for? Add a party name.');
      return;
    }
    if (_amount <= 0) {
      toast(context, 'Add the total amount.');
      return;
    }
    // Money that moved needs a name against it, or nobody can be asked about
    // it a month later.
    if (_paid && _handledBy.text.trim().isEmpty) {
      toast(context, 'Who handled the money? Fill that in first.');
      return;
    }

    final store = context.read<FarmStore>();
    final actor = context.read<Session>().actor;
    setState(() => _busy = true);
    try {
      await MonthRepo.ensureOpen(store.month.id);
      await TxnRepo.add(
        actor: actor,
        monthId: store.month.id,
        type: _type,
        party: party,
        category: _category,
        amount: _amount,
        paid: _paid,
        qty: num.tryParse(_qty.text.trim()),
        unit: _unit,
        rate: num.tryParse(_rate.text.trim()),
        note: _note.text.trim(),
        payVia: _payVia,
        handledBy: _handledBy.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, '${_type.label} saved · ${rs(_amount)}');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final measured = !_type.isSettlement;

    return FarmScaffold(
      title: 'New entry',
      showBack: true,
      body: PageBody(
        children: [
          const Kicker('Type'),
          const SizedBox(height: 6),
          Segmented<TxnType>(
            value: _type,
            compact: true,
            options: [for (final t in TxnType.values) (t, t.label)],
            onChanged: _setType,
          ),
          const SizedBox(height: T.pad),

          Field(
            label: _type == TxnType.sale ? 'Customer / party' : 'Party',
            controller: _party,
            hint: _type == TxnType.sale
                ? 'Who bought it'
                : 'Who you paid or bought from',
          ),
          const SizedBox(height: T.gap),

          Picker<String>(
            label: 'Category',
            value: _category,
            items: [for (final c in _type.categories) (c, c)],
            onChanged: (v) => setState(() => _category = v),
          ),
          if (assetCategories.contains(_category) && !_type.isSettlement) ...[
            const SizedBox(height: 6),
            Text(
              'This counts as a farm asset, not a monthly cost. The cash still '
              'leaves the balance, but the profit is not reduced — the farm '
              'owns what it bought.',
              style: T.meta.copyWith(color: T.accent700),
            ),
          ],

          if (measured) ...[
            const SizedBox(height: T.gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: Field(
                    label: 'Qty',
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    hint: '0',
                    onChanged: (_) => _fromQtyRate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Picker<String>(
                    label: 'Unit',
                    value: _unit,
                    items: [for (final u in txnUnits) (u, u)],
                    onChanged: (v) => setState(() => _unit = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Field(
                    label: 'Rate / unit',
                    controller: _rate,
                    keyboardType: TextInputType.number,
                    hint: '0',
                    onChanged: (_) => _fromQtyRate(),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: T.gap),
          Field(
            label: 'Total amount (Rs)',
            controller: _total,
            keyboardType: TextInputType.number,
            hint: '0',
            onChanged: (_) => _fromTotal(),
          ),
          if (measured) ...[
            const SizedBox(height: 5),
            Text(
              'Qty × rate fills the total. Change the total for a bulk deal '
              'and the rate works itself out.',
              style: T.meta,
            ),
          ],

          if (!_type.isSettlement) ...[
            const SizedBox(height: T.pad),
            const Kicker('Settled?'),
            const SizedBox(height: 6),
            Segmented<bool>(
              value: _paid,
              compact: true,
              options: [(true, 'Paid now'), (false, _type.unpaidLabel)],
              onChanged: (v) => setState(() => _paid = v),
            ),
          ],

          // Only worth asking once the money has actually moved.
          if (_type.isSettlement || _paid) ...[
            const SizedBox(height: T.pad),
            const Kicker('How'),
            const SizedBox(height: 6),
            Segmented<PayVia>(
              value: _payVia,
              compact: true,
              options: [for (final v in PayVia.values) (v, v.label)],
              onChanged: (v) => setState(() => _payVia = v),
            ),
            const SizedBox(height: T.gap),
            Field(
              label: _type.isIncoming ? 'Received by' : 'Paid by',
              controller: _handledBy,
              hint: _type.isIncoming
                  ? 'Who took the money'
                  : 'Who handed it over',
            ),
            const SizedBox(height: 5),
            Text(
              'The person who actually handled the cash — not whoever is '
              'typing this in.',
              style: T.meta,
            ),
          ],

          const SizedBox(height: T.gap),
          Field(
            label: 'Note',
            controller: _note,
            hint: 'Anything worth remembering',
            maxLines: 2,
          ),

          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Save & sync to Sheets',
            busy: _busy,
            onPressed: _save,
          ),
          const SizedBox(height: 10),
          Text(
            'Booked into ${monthName(context.watch<FarmStore>().month.id)}.',
            style: T.meta,
          ),
        ],
      ),
    );
  }
}
