import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/order_repo.dart';
import '../../state/cart.dart';
import '../../state/customer_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.onOrdered});

  final VoidCallback onOrdered;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _mode = 'delivery';
  String _slot = 'morning';
  String _repeat = 'once';
  PayMethod _pay = PayMethod.cod;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CustomerStore>();
    final cart = context.watch<Cart>();
    final user = context.watch<Session>().user;
    final lines = cart.lines(store.products);
    final total = cart.total(store.products);

    if (lines.isEmpty) {
      return const PageBody(
        children: [EmptyNote('Your cart is empty. Add something from the shop.')],
      );
    }

    final udhaarFits = store.udhaarFits(total);
    final udhaarBlocked = store.udhaarApproved && !udhaarFits;
    // An udhaar choice that no longer fits falls back to cash on delivery.
    if (_pay == PayMethod.udhaar && !udhaarFits) _pay = PayMethod.cod;

    return PageBody(
      children: [
        RegCard(
          child: Column(
            children: [
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(child: Text(l.line, style: T.body)),
                      Text(rs(l.total), style: T.bodyMid),
                    ],
                  ),
                ),
              const Divider(height: 18),
              Row(
                children: [
                  const Expanded(child: Text('Total', style: T.cardTitle)),
                  Text(rs(total), style: T.num22),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: T.pad),

        const Kicker('Fulfilment'),
        const SizedBox(height: 6),
        Segmented<String>(
          value: _mode,
          compact: true,
          options: const [
            ('delivery', 'Home delivery'),
            ('pickup', 'Farm pickup'),
          ],
          onChanged: (v) => setState(() => _mode = v),
        ),
        const SizedBox(height: T.gap),

        const Kicker('Time slot'),
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

        const Kicker('Repeat'),
        const SizedBox(height: 6),
        Segmented<String>(
          value: _repeat,
          compact: true,
          options: const [('once', 'One-off'), ('daily', 'Daily')],
          onChanged: (v) => setState(() => _repeat = v),
        ),
        if (_repeat == 'daily') ...[
          const SizedBox(height: 5),
          Text(
            'The farm will raise this order every day for your slot until you '
            'ask them to stop.',
            style: T.meta,
          ),
        ],
        const SizedBox(height: T.pad),

        const Kicker('Payment'),
        const SizedBox(height: 4),
        for (final method in PayMethod.values)
          _PayOption(
            method: method,
            selected: _pay == method,
            enabled: method != PayMethod.udhaar || udhaarFits,
            detail: _detail(method, store, udhaarBlocked),
            onTap: () => setState(() => _pay = method),
          ),

        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Place order · ${rs(total)}',
          busy: _busy,
          onPressed: user?.canOrder == true ? () => _place(lines, total) : null,
        ),
        if (user?.canOrder != true) ...[
          const SizedBox(height: 8),
          Text(
            'Your account is still waiting for approval, so orders cannot be '
            'placed yet.',
            style: T.meta,
          ),
        ],
      ],
    );
  }

  String? _detail(PayMethod m, CustomerStore store, bool udhaarBlocked) =>
      switch (m) {
        PayMethod.bank => store.settings.bankAccount.isEmpty
            ? null
            : store.settings.bankAccount,
        PayMethod.jazzcash => store.settings.jazzcashNumber.isEmpty
            ? null
            : store.settings.jazzcashNumber,
        PayMethod.udhaar => switch (store.udhaarStatus) {
          UdhaarStatus.approved => udhaarBlocked
              ? 'This order would pass your ${rs(store.udhaar?.limit ?? 0)} '
                    'limit.'
              : 'Added to your month-end bill.',
          UdhaarStatus.pending => 'Your registration is still being approved.',
          _ => 'Register for udhaar first, in the Udhaar tab.',
        },
        PayMethod.cod => null,
      };

  Future<void> _place(List<OrderItem> lines, num total) async {
    setState(() => _busy = true);
    try {
      await OrderRepo.place(
        actor: context.read<Session>().actor,
        items: lines,
        total: total,
        mode: _mode,
        slot: _slot,
        repeat: _repeat,
        pay: _pay,
      );
      if (!mounted) return;
      context.read<Cart>().clear();
      widget.onOrdered();
      toast(context, 'Order placed · the farm has been notified');
    } catch (e) {
      if (mounted) toast(context, 'Could not place the order. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.detail,
    required this.onTap,
  });

  final PayMethod method;
  final bool selected;
  final bool enabled;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    child: Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: T.divider, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? T.accent : T.n500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label, style: T.body),
                  if (detail != null)
                    Text(detail!, style: T.meta),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
