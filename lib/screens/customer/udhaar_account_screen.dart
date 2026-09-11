import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/udhaar_repo.dart';
import '../../state/customer_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Monthly credit: the balance once approved, the registration form before.
class UdhaarAccountScreen extends StatelessWidget {
  const UdhaarAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CustomerStore>();
    final u = store.udhaar;

    return PageBody(
      children: [
        RegCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Kicker('Your khaata')),
                  Tag(
                    store.udhaarStatus.label,
                    tone: _tone(store.udhaarStatus),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (store.udhaarApproved && u != null) ...[
                Text(rs(u.balance), style: T.num30),
                const SizedBox(height: 6),
                Text(
                  'What you owe right now · limit ${rs(u.limit)}',
                  style: T.meta,
                ),
                const SizedBox(height: 10),
                RatioBar(fraction: u.limit <= 0 ? 0 : u.balance / u.limit),
                const SizedBox(height: 12),
                Text(
                  'This month so far: ${qty(store.litresThisMonth)} L · '
                  '${rs(store.amountThisMonth)} at ${rs(u.rate)} / L. '
                  'Your bill comes at month end.',
                  style: T.meta,
                ),
              ] else if (store.udhaarStatus == UdhaarStatus.pending) ...[
                Text(
                  'Your request is with the co-founders. Any one of them can '
                  'approve it, and you will get a notification.',
                  style: T.body,
                ),
              ] else if (store.udhaarStatus == UdhaarStatus.rejected) ...[
                Text(
                  'Monthly credit was not approved this time. Please talk to '
                  'the farm — you can still order and pay on delivery.',
                  style: T.body,
                ),
              ] else
                Text(
                  'Take milk through the month and settle one bill at month '
                  'end.',
                  style: T.body,
                ),
            ],
          ),
        ),
        if (store.udhaarStatus == UdhaarStatus.none) ...[
          const SizedBox(height: T.pad),
          const _RegisterForm(),
        ],

        if (store.udhaarApproved) ...[
          const SizedBox(height: 22),
          const SectionTitle('Your bills'),
          if (store.bills.isEmpty)
            const EmptyNote('No bill yet — the first one comes at month end.')
          else
            for (final b in store.bills) _BillRow(bill: b),

          const SizedBox(height: 22),
          const SectionTitle('Milk taken this month'),
          _MonthGrid(deliveries: store.deliveries),
          const SizedBox(height: 14),
          if (store.deliveries.isEmpty)
            const EmptyNote('Nothing delivered yet this month.')
          else
            for (final d in store.deliveries) _DeliveryRow(delivery: d),
        ],
      ],
    );
  }

  static TagTone _tone(UdhaarStatus s) => switch (s) {
    UdhaarStatus.approved => TagTone.good,
    UdhaarStatus.pending => TagTone.warn,
    UdhaarStatus.rejected => TagTone.bad,
    UdhaarStatus.none => TagTone.neutral,
  };
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _mobile = TextEditingController();
  final _litres = TextEditingController();
  String _slot = 'morning';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = context.read<Session>().user?.name ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _mobile.dispose();
    _litres.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final address = _address.text.trim();
    final mobile = _mobile.text.trim();
    final litres = num.tryParse(_litres.text.trim()) ?? 0;

    if (name.isEmpty || address.isEmpty || mobile.isEmpty || litres <= 0) {
      toast(context, 'Please fill in every field.');
      return;
    }

    setState(() => _busy = true);
    try {
      await UdhaarRepo.request(
        context.read<Session>().actor,
        name: name,
        address: address,
        mobile: mobile,
        slot: _slot,
        litresPerDay: litres,
        milkRate: context.read<CustomerStore>().milkRate,
      );
      if (mounted) toast(context, 'Request sent to the co-founders');
    } catch (e) {
      if (mounted) toast(context, 'Could not send the request. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<CustomerStore>().milkRate;
    final litres = num.tryParse(_litres.text.trim()) ?? 0;
    final estimate = litres * rate * 30;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Open a khaata'),
          const SizedBox(height: 10),
          Field(label: 'Full name', controller: _name),
          const SizedBox(height: T.gap),
          Field(
            label: 'Complete address',
            controller: _address,
            hint: 'House, street, area, city',
            maxLines: 2,
          ),
          const SizedBox(height: T.gap),
          Field(
            label: 'Mobile number',
            controller: _mobile,
            keyboardType: TextInputType.phone,
            hint: '03xx xxx xxxx',
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: T.gap),
          const Kicker('Delivery timing'),
          const SizedBox(height: 6),
          Segmented<String>(
            value: _slot,
            compact: true,
            options: const [
              ('morning', 'Morning 6–9'),
              ('evening', 'Evening 5–8'),
            ],
            onChanged: (v) => setState(() => _slot = v),
          ),
          const SizedBox(height: T.gap),
          Field(
            label: 'Milk per day (litres)',
            controller: _litres,
            keyboardType: TextInputType.number,
            hint: '0',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            litres <= 0
                ? 'Your monthly bill is about litres × milk rate × 30.'
                : '${qty(litres)} L × ${rs(rate)} × 30 ≈ ${rs(estimate)} '
                      'a month',
            style: T.meta,
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Request a khaata',
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// One month's bill as the customer sees it.
class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: T.divider, width: 1)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(monthName(bill.monthId), style: T.bodyMid),
              Text(
                '${qty(bill.litres)} L'
                '${bill.previousBalance > 0 ? ' · ${rs(bill.previousBalance)} carried over' : ''}'
                '${bill.paid > 0 ? ' · ${rs(bill.paid)} paid' : ''}',
                style: T.meta,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(rs(bill.total), style: T.bodyMid),
            Tag(
              bill.statusLabel,
              tone: bill.isSettled
                  ? TagTone.good
                  : bill.isPartPaid
                  ? TagTone.warn
                  : TagTone.bad,
            ),
          ],
        ),
      ],
    ),
  );
}

/// One day's milk on the customer's own record.
class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: T.divider, width: 1)),
    ),
    child: Row(
      children: [
        SizedBox(width: 64, child: Text(fmtDate(delivery.date), style: T.meta)),
        Expanded(
          child: Text(
            '${qty(delivery.litres)} L × ${rs(delivery.rate)}',
            style: T.body,
          ),
        ),
        Text(rs(delivery.amount), style: T.bodyMid),
      ],
    ),
  );
}

/// Every day of the month so far, so the customer can see at a glance which
/// days milk came and which it did not.
///
/// A khaata is a running total someone else keeps; being able to check it day
/// by day is what makes it trustworthy.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.deliveries});

  final List<Delivery> deliveries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final byDay = {for (final d in deliveries) d.date.day: d};
    final days = List.generate(now.day, (i) => i + 1);
    final missed = days.where((d) => !byDay.containsKey(d)).length;

    return RegCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${days.length - missed} days delivered · $missed missed',
            style: T.bodyMid,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final day in days) _DayBox(day: day, delivery: byDay[day]),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The number under each date is the litres taken that day. A dash '
            'means nothing was delivered.',
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

class _DayBox extends StatelessWidget {
  const _DayBox({required this.day, required this.delivery});

  final int day;
  final Delivery? delivery;

  @override
  Widget build(BuildContext context) {
    final got = delivery != null;
    return Container(
      width: 38,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: got ? T.accent100 : Colors.transparent,
        border: Border.all(color: got ? T.accent300 : T.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: T.meta.copyWith(
              fontSize: 10,
              color: got ? T.accent700 : T.n500,
            ),
          ),
          Text(
            got ? qty(delivery!.litres) : '–',
            style: T.bodyMid.copyWith(
              fontSize: 13,
              color: got ? T.accent800 : T.n400,
            ),
          ),
        ],
      ),
    );
  }
}
