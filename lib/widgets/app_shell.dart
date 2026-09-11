import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/db.dart';
import '../services/links.dart';
import '../services/update_check.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// One tab in the bottom bar.
class TabDef {
  const TabDef({
    required this.label,
    required this.icon,
    required this.title,
    required this.body,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final String title;
  final Widget body;
  final int badge;
}

/// The chrome every screen sits in: logo or back arrow, title and role line,
/// the Sheets tag for farm staff, and Sign out.
class FarmScaffold extends StatelessWidget {
  const FarmScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBack = false,
    this.bottomBar,
    this.floating,
  });

  final String title;
  final Widget body;
  final bool showBack;
  final Widget? bottomBar;
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user;

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(title: title, showBack: showBack, user: user),
            const Divider(),
            const UpdateBanner(),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floating,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.showBack,
    required this.user,
  });

  final String title;
  final bool showBack;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.pad, 10, T.pad, 10),
      child: Row(
        children: [
          if (showBack)
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back, size: 20),
                padding: EdgeInsets.zero,
                tooltip: 'Back',
              ),
            )
          else
            Image.asset('assets/logo.png', width: 36, height: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: T.screenTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user != null) _SubLine(user: user!),
              ],
            ),
          ),
          if (user != null && user!.role.isStaff) const _SheetsTag(),
          const SizedBox(width: 6),
          TextButton(
            onPressed: session.signOut,
            style: TextButton.styleFrom(
              foregroundColor: T.n700,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, T.tap),
              textStyle: T.meta,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

/// "Co-founder · 28% share" under the screen title.
class _SubLine extends StatelessWidget {
  const _SubLine({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    if (user.role != Role.investor && user.role != Role.master) {
      return Text(user.role.label, style: T.meta.copyWith(fontSize: 11));
    }
    return StreamBuilder<List<Partner>>(
      stream: Db.watchPartners(),
      builder: (context, snap) {
        final partners = snap.data ?? const <Partner>[];
        final mine = partners.where((p) => p.userId == user.uid).toList();
        final ratio = mine.isEmpty ? null : ratiosOf(partners)[mine.first.id];
        final share = ratio == null
            ? ''
            : ' · ${(ratio * 100).toStringAsFixed(0)}% share';
        return Text(
          '${user.role.label}$share',
          style: T.meta.copyWith(fontSize: 11),
        );
      },
    );
  }
}

/// Green when the last Sheets sync succeeded, warning tone when it is retrying.
class _SheetsTag extends StatelessWidget {
  const _SheetsTag();

  @override
  Widget build(BuildContext context) => StreamBuilder<FarmSettings>(
    stream: Db.watchSettings(),
    builder: (context, snap) {
      final ok = snap.data?.syncOk ?? true;
      return Tag(
        ok ? 'Sheets synced' : 'Sync pending',
        tone: ok ? TagTone.good : TagTone.warn,
      );
    },
  );
}

/// Quiet strip that appears only when a newer APK has been published.
///
/// The farm installs by hand, so left to itself a fix would sit on the Releases
/// page unnoticed. Dismissing it lasts for this run of the app.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  static bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return FutureBuilder<AppUpdate?>(
      future: UpdateCheck.latest(),
      builder: (context, snap) {
        final update = snap.data;
        if (update == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.fromLTRB(T.pad, 8, 8, 8),
          decoration: const BoxDecoration(
            color: T.accent100,
            border: Border(bottom: BorderSide(color: T.divider, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Update ${update.version} is ready to install.',
                  style: T.bodyMid.copyWith(color: T.accent800),
                ),
              ),
              GhostButton(
                label: 'Get it',
                compact: true,
                onPressed: () async {
                  final opened = await Links.open(update.apkUrl);
                  if (!opened && context.mounted) {
                    toast(context, 'Could not open the download page.');
                  }
                },
              ),
              IconButton(
                onPressed: () => setState(() => _dismissed = true),
                icon: const Icon(Icons.close, size: 16, color: T.n600),
                tooltip: 'Not now',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom tab bar: 11 px labels, thin icons, badge count in an accent square.
class FarmTabBar extends StatelessWidget {
  const FarmTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<TabDef> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: T.bg,
      border: Border(top: BorderSide(color: T.divider, width: 1)),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          for (final (i, tab) in tabs.indexed)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: SizedBox(
                  height: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            tab.icon,
                            size: 20,
                            color: i == index ? T.accent : T.n600,
                          ),
                          if (tab.badge > 0)
                            Positioned(
                              right: -8,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                color: T.accent,
                                child: Text(
                                  '${tab.badge}',
                                  style: T.meta.copyWith(
                                    color: T.accent100,
                                    fontSize: 10,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: T.tabLabel.copyWith(
                          color: i == index ? T.accent : T.n600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Scrollable page body with the standard gutters.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padBottom = 24});

  final List<Widget> children;
  final double padBottom;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(T.pad, T.pad, T.pad, padBottom),
    children: children,
  );
}
