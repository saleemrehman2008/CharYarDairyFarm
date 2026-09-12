import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/export_service.dart';
import '../../services/links.dart';
import '../../state/farm_store.dart';
import '../../state/round_data.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import '../../models/models.dart';
import '../shared/bills_screen.dart';
import '../shared/deliveries_screen.dart';
import '../shared/products_screen.dart';
import 'activity_log_screen.dart';
import 'cattle_screen.dart';
import 'handovers_screen.dart';
import 'udhaar_registrations_screen.dart';
import 'team_access_screen.dart';
import 'users_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();

    final isMaster = session.role == Role.master;

    return PageBody(
      children: [
        _Row(
          label: 'Daily round',
          icon: Icons.local_shipping_outlined,
          onTap: () => _push(context, store, const DeliveriesScreen()),
        ),
        _Row(
          label: 'Khaata bills',
          icon: Icons.receipt_outlined,
          badge: store.unpaidBills.length,
          onTap: () => _push(context, store, const BillsScreen()),
        ),
        _Row(
          label: 'Khaata registrations',
          icon: Icons.handshake_outlined,
          badge: store.pendingUdhaar.length,
          onTap: () => _push(context, store, const UdhaarRegistrationsScreen()),
        ),
        _Row(
          label: 'Handovers',
          icon: Icons.account_balance_wallet_outlined,
          badge: store.handoversWaiting.length,
          onTap: () => _push(context, store, const HandoversScreen()),
        ),
        _Row(
          label: 'Cattle register',
          icon: Icons.pets_outlined,
          badge: store.dueChecks.length,
          onTap: () => _push(context, store, const CattleScreen()),
        ),
        _Row(
          label: 'Products & rates',
          icon: Icons.sell_outlined,
          onTap: () =>
              _push(context, store, const ProductsScreen(asSubScreen: true)),
        ),
        if (isMaster) ...[
          _Row(
            label: 'Team access',
            icon: Icons.badge_outlined,
            onTap: () => _push(context, store, const TeamAccessScreen()),
          ),
          _Row(
            label: 'Users & roles',
            icon: Icons.manage_accounts_outlined,
            badge: store.pendingUsers.length,
            onTap: () => _push(context, store, const UsersScreen()),
          ),
          _Row(
            label: 'Activity log',
            icon: Icons.history,
            onTap: () => _push(context, store, const ActivityLogScreen()),
          ),
          const _ExportRow(),
        ],
        _Row(
          label: 'Google Sheets',
          icon: Icons.table_chart_outlined,
          onTap: () async {
            final url = store.settings.sheetUrl;
            if (url.isEmpty) {
              toast(
                context,
                'No sheet linked yet — add sheetId to settings/farm.',
              );
              return;
            }
            final opened = await Links.open(url);
            if (!opened && context.mounted) {
              toast(context, 'Could not open the sheet.');
            }
          },
        ),
        const SizedBox(height: 20),
        Text('Signed in as ${session.user?.email ?? ''}', style: T.meta),
      ],
    );
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
    setState(() => _busy = true);
    try {
      final count = await ExportService.share(actor);
      if (!mounted) return;
      toast(
        context,
        count == 0
            ? 'Nothing to export yet.'
            : '$count files ready — pick where to save them',
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not export. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Row(
    label: _busy ? 'Preparing files…' : 'Export books to Sheets',
    icon: Icons.ios_share,
    onTap: _busy ? () {} : _export,
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.divider, width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: T.accent700),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: T.cardTitle)),
          if (badge > 0) ...[
            Tag('$badge', tone: TagTone.warn),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right, size: 18, color: T.n500),
        ],
      ),
    ),
  );
}
