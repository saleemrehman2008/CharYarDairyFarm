import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/links.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import '../shared/products_screen.dart';
import 'activity_log_screen.dart';
import 'udhaar_registrations_screen.dart';
import 'users_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();

    return PageBody(
      children: [
        _Row(
          label: 'Products & rates',
          icon: Icons.sell_outlined,
          onTap: () =>
              _push(context, store, const ProductsScreen(asSubScreen: true)),
        ),
        _Row(
          label: 'Users & roles',
          icon: Icons.manage_accounts_outlined,
          badge: store.pendingUsers.length,
          onTap: () => _push(context, store, const UsersScreen()),
        ),
        _Row(
          label: 'Udhaar registrations',
          icon: Icons.handshake_outlined,
          badge: store.pendingUdhaar.length,
          onTap: () => _push(context, store, const UdhaarRegistrationsScreen()),
        ),
        _Row(
          label: 'Activity log',
          icon: Icons.history,
          onTap: () => _push(context, store, const ActivityLogScreen()),
        ),
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

  void _push(BuildContext context, FarmStore store, Widget screen) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChangeNotifierProvider.value(value: store, child: screen),
        ),
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
