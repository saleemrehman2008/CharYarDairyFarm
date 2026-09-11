import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Master only. Newest first, loading more as the list is pulled down.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  static const _page = 60;
  int _limit = _page;

  @override
  Widget build(BuildContext context) => FarmScaffold(
    title: 'Activity log',
    showBack: true,
    body: StreamBuilder<List<LogEntry>>(
      stream: Db.watchLogs(limit: _limit),
      builder: (context, snap) {
        final entries = snap.data ?? const <LogEntry>[];
        if (snap.connectionState == ConnectionState.waiting &&
            entries.isEmpty) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (entries.isEmpty) {
          return const PageBody(children: [EmptyNote('Nothing logged yet.')]);
        }

        final hasMore = entries.length >= _limit;
        return NotificationListener<ScrollEndNotification>(
          onNotification: (n) {
            if (hasMore && n.metrics.extentAfter < 200) {
              setState(() => _limit += _page);
            }
            return false;
          },
          child: PageBody(
            children: [
              for (final e in entries) _LogRow(entry: e),
              if (hasMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: T.divider, width: 1)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 92, child: Text(fmtStamp(entry.at), style: T.meta)),
        Expanded(child: Text('${entry.who} ${entry.what}', style: T.body)),
        const SizedBox(width: 8),
        Tag(entry.kind.label),
      ],
    ),
  );
}
