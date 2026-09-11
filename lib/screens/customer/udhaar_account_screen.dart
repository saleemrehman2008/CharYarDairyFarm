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
                  const Expanded(child: Kicker('Udhaar account')),
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
                  'limit ${rs(u.limit)} · billed when the farm closes the '
                  'month',
                  style: T.meta,
                ),
                const SizedBox(height: 10),
                RatioBar(fraction: u.limit <= 0 ? 0 : u.balance / u.limit),
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
          const Kicker('Register for udhaar'),
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
            label: 'Request udhaar account',
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
