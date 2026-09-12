import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/order_repo.dart';
import '../../services/user_repo.dart';
import '../../state/cart.dart';
import '../../state/customer_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../util/phone.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/day_picker.dart';
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

  /// Which days the order is for. Today unless the customer says otherwise.
  late Set<String> _days = {dayKeyOf(DateTime.now())};

  PayMethod _pay = PayMethod.cod;
  bool _busy = false;

  /// True while the customer is typing an address other than their saved one.
  bool _newAddress = false;

  final _address = TextEditingController();
  final _mobile = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    _mobile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CustomerStore>();
    final cart = context.watch<Cart>();
    final user = context.watch<Session>().user;
    final lines = cart.lines(store.products);
    final perDay = cart.total(store.products);
    final total = perDay * (_days.isEmpty ? 1 : _days.length);

    if (lines.isEmpty) {
      return const PageBody(
        children: [
          EmptyNote('Your cart is empty. Add something from the shop.'),
        ],
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

        // Where to take it. Asked once; after that the saved address is
        // offered back, because most orders go to the same door.
        if (_mode == 'delivery') ...[
          const SizedBox(height: T.gap),
          if (user != null && user.hasDeliveryDetails && !_newAddress) ...[
            RegCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('Deliver to'),
                  const SizedBox(height: 6),
                  Text(user.address, style: T.body),
                  Text(Phone.pretty(user.mobile), style: T.meta),
                  const SizedBox(height: 10),
                  GhostButton(
                    label: 'Somewhere else this time',
                    compact: true,
                    onPressed: () => setState(() {
                      _newAddress = true;
                      _address.text = user.address;
                      _mobile.text = user.mobile;
                    }),
                  ),
                ],
              ),
            ),
          ] else ...[
            Field(
              label: 'Delivery address',
              controller: _address,
              hint: 'House, street, area, city',
              maxLines: 2,
            ),
            const SizedBox(height: T.gap),
            Field(
              label: 'Mobile number',
              controller: _mobile,
              keyboardType: TextInputType.phone,
              hint: Phone.hint,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 5),
            Text(
              user != null && user.hasDeliveryDetails
                  ? 'This becomes your saved address.'
                  : 'Saved for next time, so you only type it once.',
              style: T.meta,
            ),
          ],
        ],
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

        const Kicker('Which days'),
        const SizedBox(height: 6),
        RegCard(
          padding: const EdgeInsets.all(10),
          child: DayPicker(
            selected: _days,
            onChanged: (v) => setState(() => _days = v),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _days.isEmpty
              ? 'Pick at least one day.'
              : _days.length == 1
              ? 'One delivery, on $_dayList. Tap more days to order for a '
                    'week or a month at a time.'
              : '${_days.length} deliveries · ${rs(perDay)} each · '
                    '$_dayList. Each day is paid for as it comes.',
          style: T.meta,
        ),
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
          onPressed: user?.canOrder == true && _days.isNotEmpty
              ? () => _place(lines, perDay)
              : null,
        ),
        if (user?.canOrder != true) ...[
          const SizedBox(height: 8),
          Text(
            'Your account is still waiting for approval, so orders cannot be '
            'placed yet.',
            style: T.meta,
          ),
        ],
        const SizedBox(height: 10),
        GhostButton(
          label: 'Cancel and empty the cart',
          onPressed: _busy ? null : _cancel,
        ),
      ],
    );
  }

  Future<void> _cancel() async {
    final ok = await confirm(
      context,
      title: 'Empty the cart?',
      body: 'Everything in it is taken out. Nothing is ordered.',
      confirmLabel: 'Empty it',
    );
    if (!ok || !mounted) return;
    context.read<Cart>().clear();
    toast(context, 'Cart emptied');
  }

  String? _detail(PayMethod m, CustomerStore store, bool udhaarBlocked) =>
      switch (m) {
        PayMethod.bank =>
          store.settings.bankAccount.isEmpty
              ? null
              : store.settings.bankAccount,
        PayMethod.jazzcash =>
          store.settings.jazzcashNumber.isEmpty
              ? null
              : store.settings.jazzcashNumber,
        PayMethod.udhaar => switch (store.udhaarStatus) {
          UdhaarStatus.approved =>
            udhaarBlocked
                ? 'This order would pass your ${rs(store.udhaar?.limit ?? 0)} '
                      'limit.'
                : 'Added to your month-end bill.',
          UdhaarStatus.pending => 'Your registration is still being approved.',
          _ => 'Register for a khaata first, in the Khaata tab.',
        },
        PayMethod.cod => null,
      };

  /// "13 Sep – 19 Sep", for the line under the calendar.
  String get _dayList {
    final dates = (_days.toList()..sort()).map(dayFromKey).nonNulls.toList();
    if (dates.isEmpty) return '';
    if (dates.length == 1) return fmtDateFull(dates.first);
    final run = List.generate(
      dates.length,
      (i) => i == 0 || dates[i].difference(dates[i - 1]).inDays == 1,
    ).every((x) => x);
    return run
        ? '${fmtDate(dates.first)} – ${fmtDate(dates.last)}'
        : dates.map(fmtDate).join(', ');
  }

  Future<void> _place(List<OrderItem> lines, num perDayTotal) async {
    final session = context.read<Session>();
    final user = session.user;

    // Whatever is on screen: the saved address, or the one being typed.
    final saved = user != null && user.hasDeliveryDetails && !_newAddress;
    final address = saved ? user.address : _address.text.trim();
    final mobile = saved ? user.mobile : _mobile.text.trim();

    if (_mode == 'delivery') {
      if (address.isEmpty) {
        toast(context, 'Where should the milk go? Add a delivery address.');
        return;
      }
      if (!Phone.isValid(mobile)) {
        toast(context, Phone.error);
        return;
      }
    }

    setState(() => _busy = true);
    try {
      if (_mode == 'delivery' && !saved && user != null) {
        await UserRepo.saveDeliveryDetails(
          user.uid,
          address: address,
          mobile: mobile,
        );
      }

      await OrderRepo.place(
        actor: session.actor,
        items: lines,
        perDayTotal: perDayTotal,
        days: (_days.toList()..sort()).map(dayFromKey).nonNulls.toList(),
        mode: _mode,
        slot: _slot,
        pay: _pay,
        address: _mode == 'delivery' ? address : '',
        mobile: _mode == 'delivery' ? Phone.normalise(mobile) : '',
      );
      if (!mounted) return;
      setState(() {
        _newAddress = false;
        _days = {dayKeyOf(DateTime.now())};
      });
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
                  if (detail != null) Text(detail!, style: T.meta),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
