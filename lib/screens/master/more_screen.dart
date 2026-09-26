import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/export_service.dart';
import '../../services/links.dart';
import '../../state/farm_store.dart';
import '../../state/round_data.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/farm_icons.dart';
import '../../widgets/ui.dart';
import '../shared/bills_screen.dart';
import '../shared/deliveries_screen.dart';
import '../shared/my_account_screen.dart';
import '../shared/products_screen.dart';
import '../shared/report_screen.dart';
import '../shared/statement_screen.dart';
import 'activity_log_screen.dart';
import 'cattle_screen.dart';
import 'farm_setup_screen.dart';
import 'handovers_screen.dart';
import 'payment_details_screen.dart';
import 'team_access_screen.dart';
import 'udhaar_registrations_screen.dart';
import 'users_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();
    final l = L.of(context);
    final f = store.features;
    final isMaster = session.role == Role.master;

    return PageBody(
      children: [
        if (f.rider || f.khaata) ...[
          SectionTitle(l.t('Every day')),
          const SizedBox(height: 8),
          _Group(
            rows: [
              if (f.rider)
                _Row(
                  label: l.t('Daily round'),
                  icon: Icons.local_shipping_outlined,
                  tone: T.moneyIn,
                  badge: store.roundLeft,
                  onTap: () => _push(context, store, const DeliveriesScreen()),
                ),
              if (f.khaata)
                _Row(
                  label: l.t('Khaata bills'),
                  icon: Icons.receipt_outlined,
                  tone: T.moneyGet,
                  badge: store.unpaidBills.length,
                  onTap: () => _push(context, store, const BillsScreen()),
                ),
              if (f.khaata)
                _Row(
                  label: l.t('Khaata sign-ups'),
                  icon: Icons.handshake_outlined,
                  tone: T.moneyDue,
                  badge: store.pendingUdhaar.length,
                  onTap: () =>
                      _push(context, store, const UdhaarRegistrationsScreen()),
                ),
              if (f.rider)
                _Row(
                  label: l.t('Handovers'),
                  icon: Icons.account_balance_wallet_outlined,
                  tone: T.accent700,
                  badge: store.handoversWaiting.length,
                  onTap: () => _push(context, store, const HandoversScreen()),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        SectionTitle(l.t('The farm')),
        const SizedBox(height: 8),
        _Group(
          rows: [
            if (f.cattle)
              _Row(
                label: l.t('Cattle register'),
                drawn: const CattleIcon(size: 19, color: Color(0xFF6544B0)),
                tone: const Color(0xFF6544B0),
                badge: store.dueChecks.length,
                onTap: () => _push(context, store, const CattleScreen()),
              ),
            _Row(
              label: l.t('Report'),
              icon: Icons.bar_chart,
              tone: T.moneyIn,
              onTap: () => _push(context, store, const ReportScreen()),
            ),
            _Row(
              label: l.t('Statement'),
              icon: Icons.receipt_long_outlined,
              tone: T.accent700,
              onTap: () => _push(context, store, const StatementScreen()),
            ),
            _Row(
              label: l.t('Products & rates'),
              icon: Icons.sell_outlined,
              tone: T.accent500,
              onTap: () => _push(
                context,
                store,
                const ProductsScreen(asSubScreen: true),
              ),
            ),
            _Row(
              label: l.t('Google Sheets'),
              icon: Icons.table_chart_outlined,
              tone: T.moneyIn,
              onTap: () => _openSheet(context, store, l),
            ),
            if (isMaster) const _ExportRow(),
          ],
        ),
        const SizedBox(height: 20),

        if (isMaster) ...[
          SectionTitle(l.t('Master only')),
          const SizedBox(height: 8),
          _Group(
            rows: [
              _Row(
                label: l.t('What the farm runs'),
                icon: Icons.tune,
                tone: T.accent600,
                onTap: () => _push(context, store, const FarmSetupScreen()),
              ),
              _Row(
                label: l.t('Payment details'),
                icon: Icons.qr_code_2,
                tone: T.accent700,
                onTap: () =>
                    _push(context, store, const PaymentDetailsScreen()),
              ),
              _Row(
                label: l.t('Team access'),
                icon: Icons.badge_outlined,
                tone: T.n600,
                onTap: () => _push(context, store, const TeamAccessScreen()),
              ),
              _Row(
                label: l.t('Users & roles'),
                icon: Icons.manage_accounts_outlined,
                tone: T.n600,
                badge: store.pendingUsers.length,
                onTap: () => _push(context, store, const UsersScreen()),
              ),
              _Row(
                label: l.t('Activity log'),
                icon: Icons.history,
                tone: T.moneyDue,
                onTap: () => _push(context, store, const ActivityLogScreen()),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        SectionTitle(l.t('You')),
        const SizedBox(height: 8),
        _Group(
          rows: [
            _Row(
              label: l.t('My account'),
              icon: Icons.person_outline,
              tone: T.accent600,
              note: session.user?.email ?? '',
              onTap: () => _push(context, store, const MyAccountScreen()),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context, FarmStore store, L l) async {
    final url = store.settings.sheetUrl;
    if (url.isEmpty) {
      toast(context, l.t('No sheet linked yet.'));
      return;
    }
    final opened = await Links.open(url);
    if (!opened && context.mounted) {
      toast(context, l.t('Could not open the sheet.'));
    }
  }

  /// The round and the bills read [RoundData], which a partner's store also
  /// satisfies, so it is offered under both names.
  void _push(BuildContext context, FarmStore store, Widget screen) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiProvider(
            providers: [
              ChangeNotifierProvider<FarmStore>.value(value: store),
              ChangeNotifierProvider<RoundData>.value(value: store),
            ],
            child: screen,
          ),
        ),
      );
}

/// Rows that belong together, in one card, divided by hairlines rather than
/// each floating on its own.
class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => RegCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(left: 56),
              child: Divider(height: 1),
            ),
          row,
        ],
      ],
    ),
  );
}

/// Writes the books out as CSV and opens the share sheet.
///
/// Until the Cloud Functions mirror is switched on, this is how the farm gets
/// a copy of its books out of the phone and into Google Sheets.
class _ExportRow extends StatefulWidget {
  const _ExportRow();

  @override
  State<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends State<_ExportRow> {
  bool _busy = false;

  Future<void> _export() async {
    final actor = context.read<Session>().actor;
    final l = L.read(context);
    setState(() => _busy = true);
    try {
      final count = await ExportService.share(actor);
      if (!mounted) return;
      toast(
        context,
        count == 0
            ? l.t('Nothing to export yet.')
            : l.t2('%s files ready — pick where to save them', count),
      );
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not export. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _Row(
      label: _busy ? l.t('Preparing files…') : l.t('Export books'),
      icon: Icons.ios_share,
      tone: T.accent500,
      onTap: _busy ? () {} : _export,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.icon,
    this.drawn,
    required this.tone,
    required this.onTap,
    this.badge = 0,
    this.note,
  }) : assert(icon != null || drawn != null, 'a row needs something to show');

  final String label;
  final IconData? icon;
  final Widget? drawn;
  final Color tone;
  final VoidCallback onTap;
  final int badge;
  final String? note;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(T.radiusXs),
              ),
              child: drawn ?? Icon(icon, size: 18, color: tone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: T.cardTitle),
                  if (note != null && note!.isNotEmpty)
                    Text(
                      note!,
                      style: T.meta.copyWith(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (badge > 0) ...[
              Tag('$badge', tone: TagTone.warn),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, size: 18, color: T.n500),
          ],
        ),
      ),
    ),
  );
}
