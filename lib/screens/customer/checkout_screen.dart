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
import '../../widgets/photo.dart';
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

  /// The item whose calendar is open, if any. One at a time keeps the page
  /// from becoming a wall of months.
  String? _openCalendar;

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
    final total = cart.total(store.products);
    final days = cart.allDays.toList()..sort();
    // An item with no days would fall through to "every day" on the round, so
    // the order cannot be placed until every line has been given its days.
    final allLinesHaveDays = lines.every((l) => l.dayKeys.isNotEmpty);

    if (lines.isEmpty) {
      return const PageBody(
        children: [
          EmptyNote('Your cart is empty. Add something from the shop.'),
        ],
      );
    }

    // Khaata is offered to anyone with an approved account; a customer who
    // loses theirs falls back to cash on delivery.
    final onKhaata = store.udhaarApproved;
    if (_pay == PayMethod.udhaar && !onKhaata) _pay = PayMethod.cod;

    return PageBody(
      children: [
        Text(
          'Each item has its own days. Milk every morning, ghee on the one '
          'day you want it — tap "Days" on a line to choose.',
          style: T.meta,
        ),
        const SizedBox(height: 10),

        for (final l in lines)
          _CartLine(
            key: ValueKey(l.productId),
            line: l,
            open: _openCalendar == l.productId,
            onToggle: () => setState(
              () => _openCalendar = _openCalendar == l.productId
                  ? null
                  : l.productId,
            ),
            onDays: (v) => cart.setDays(l.productId, v),
          ),

        const SizedBox(height: 6),
        RegCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('Total', style: T.cardTitle)),
                  Text(rs(total), style: T.num22),
                ],
              ),
              if (days.length > 1) ...[
                const Divider(height: 18),
                for (final d in days)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${fmtDate(dayFromKey(d) ?? DateTime.now())} · '
                            '${_itemsOn(lines, d)}',
                            style: T.meta,
                          ),
                        ),
                        Text(
                          rs(cart.amountOn(d, store.products)),
                          style: T.meta,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'You pay each day for what comes that day.',
                  style: T.meta,
                ),
              ],
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

        const Kicker('Payment'),
        const SizedBox(height: 4),
        for (final method in PayMethod.values)
          _PayOption(
            method: method,
            selected: _pay == method,
            enabled: method != PayMethod.udhaar || onKhaata,
            detail: _detail(method, store),
            onTap: () => setState(() => _pay = method),
          ),

        // Anything but cash needs somewhere to send it, so the farm's own
        // account is put in front of the customer rather than left for them
        // to ask about.
        if (_pay == PayMethod.bank || _pay == PayMethod.jazzcash) ...[
          const SizedBox(height: T.gap),
          _PayTo(settings: store.settings, method: _pay),
        ],

        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Place order · ${rs(total)}',
          busy: _busy,
          onPressed: user?.canOrder == true && allLinesHaveDays
              ? () => _place(lines)
              : null,
        ),
        if (user?.canOrder != true) ...[
          const SizedBox(height: 8),
          Text(
            'Your account is still waiting for approval, so orders cannot be '
            'placed yet.',
            style: T.meta,
          ),
        ] else if (!allLinesHaveDays) ...[
          const SizedBox(height: 8),
          Text(
            'Every item needs at least one day. Tap "Days" on the line marked '
            'in red.',
            style: T.meta.copyWith(color: T.alert),
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

  String? _detail(PayMethod m, CustomerStore store) => switch (m) {
    PayMethod.bank =>
      store.settings.bankAccount.isEmpty ? null : store.settings.bankAccount,
    PayMethod.jazzcash =>
      store.settings.jazzcashNumber.isEmpty
          ? null
          : store.settings.jazzcashNumber,
    PayMethod.udhaar => switch (store.udhaarStatus) {
      UdhaarStatus.approved => 'Added to your month-end bill.',
      UdhaarStatus.pending => 'Your registration is still being approved.',
      _ => 'Register for a khaata first, in the Khaata tab.',
    },
    PayMethod.cod => null,
  };

  /// "1 L Fresh milk, 1 kg Ghee" — what is going out on one day.
  static String _itemsOn(List<OrderItem> lines, String dayKey) =>
      lines.where((l) => l.dueOn(dayKey)).map((l) => l.line).join(', ');

  Future<void> _place(List<OrderItem> lines) async {
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
        mode: _mode,
        slot: _slot,
        pay: _pay,
        address: _mode == 'delivery' ? address : '',
        mobile: _mode == 'delivery' ? Phone.normalise(mobile) : '',
      );
      if (!mounted) return;
      setState(() {
        _newAddress = false;
        _openCalendar = null;
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
        decoration: BoxDecoration(
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

/// One line of the basket: what it is, what it costs, and the days it comes.
class _CartLine extends StatelessWidget {
  const _CartLine({
    super.key,
    required this.line,
    required this.open,
    required this.onToggle,
    required this.onDays,
  });

  final OrderItem line;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Set<String>> onDays;

  @override
  Widget build(BuildContext context) {
    final dates = line.dayKeys.map(dayFromKey).nonNulls.toList();
    final when = dates.isEmpty
        ? 'No day picked'
        : dates.length == 1
        ? fmtDate(dates.first)
        : _run(dates)
        ? '${fmtDate(dates.first)} – ${fmtDate(dates.last)} '
              '(${dates.length} days)'
        : dates.map(fmtDate).join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(line.line, style: T.cardTitle)),
                Text(rs(line.total), style: T.bodyMid),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.dayKeys.length > 1
                        ? '${rs(line.each)} each × ${line.dayKeys.length} days'
                        : rs(line.each),
                    style: T.meta,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 15, color: T.n600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    when,
                    style: T.meta.copyWith(
                      color: dates.isEmpty ? T.alert : T.n700,
                    ),
                  ),
                ),
                GhostButton(
                  label: open ? 'Done' : 'Days',
                  compact: true,
                  onPressed: onToggle,
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              DayPicker(selected: line.dayKeys.toSet(), onChanged: onDays),
            ],
          ],
        ),
      ),
    );
  }

  static bool _run(List<DateTime> dates) => List.generate(
    dates.length,
    (i) => i == 0 || dates[i].difference(dates[i - 1]).inDays == 1,
  ).every((x) => x);
}

/// The farm's own account, for a customer paying by transfer.
///
/// A number typed wrong sends the money to a stranger, so the QR comes first
/// where there is one — it is scanned, not read.
class _PayTo extends StatelessWidget {
  const _PayTo({required this.settings, required this.method});

  final FarmSettings settings;
  final PayMethod method;

  @override
  Widget build(BuildContext context) {
    final bank = method == PayMethod.bank;
    final detail = bank ? settings.bankAccount : settings.jazzcashNumber;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(bank ? 'Send it to' : 'JazzCash / EasyPaisa'),
          const SizedBox(height: 8),
          if (detail.isEmpty)
            Text(
              'The farm has not put its account details in yet. Please ring '
              'them before sending anything.',
              style: T.meta.copyWith(color: T.alert),
            )
          else ...[
            SelectableText(detail, style: T.num22),
            const SizedBox(height: 4),
            Text(settings.name, style: T.meta),
          ],
          if (settings.bankQr.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(child: FarmPhotoView(data: settings.bankQr, size: 190)),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Scan this instead of typing the number.',
                style: T.meta,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Send it, then place the order. The farm marks it received when '
            'the money lands.',
            style: T.meta,
          ),
        ],
      ),
    );
  }
}
