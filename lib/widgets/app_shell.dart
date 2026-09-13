import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/db.dart';
import '../services/links.dart';
import '../services/update_check.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../screens/shared/my_account_screen.dart';
import 'ui.dart';

/// One tab in the bottom bar.
class TabDef {
  const TabDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.title,
    required this.body,
    this.badge = 0,
  });

  /// What this tab is, regardless of where it sits.
  ///
  /// The master can switch whole parts of the farm off, so the bar is not a
  /// fixed list any more and position numbers cannot be trusted. Code that
  /// sends someone to another tab names it.
  final String id;

  final String label;
  final IconData icon;
  final String title;
  final Widget body;
  final int badge;
}

/// Where [id] sits in [tabs] right now, or 0 if it is switched off.
int tabIndexOf(List<TabDef> tabs, String id) {
  final i = tabs.indexWhere((t) => t.id == id);
  return i < 0 ? 0 : i;
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
      body: Column(
        children: [
          // The bar keeps its own white ground running up under the status
          // bar, so the page reads as one sheet rather than a strip on grey.
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F0B2438),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(title: title, showBack: showBack, user: user),
                  const UpdateBanner(),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
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
            const FarmLogo(width: 36, mark: true),
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
          if (user != null && user!.role.isPartner) const _SheetsTag(),
          const SizedBox(width: 4),
          // Everybody reaches their own language and the way out from here,
          // including a customer, whose app has no More tab to put it in.
          if (user != null)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyAccountScreen()),
              ),
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: T.accent100,
                  borderRadius: BorderRadius.circular(T.radiusXs),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: T.accent700,
                ),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              tooltip: 'My account',
            )
          else
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

/// The state of the Google Sheet mirror, told honestly.
///
/// This used to read "Sheets synced" whenever nothing had gone wrong, which
/// included the case where the mirror had never run at all — so the farm was
/// assured its books were backed up while the Sheet sat empty. Green now means
/// a row actually reached the Sheet.
class _SheetsTag extends StatelessWidget {
  const _SheetsTag();

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) {
      // Reads the settings the session already holds. This used to open a
      // second Firestore listener on the same document from every screen.
      final session = context.watch<Session>();
      if (session.settingsLoading) return const SizedBox.shrink();
      final settings = session.settings;

      if (settings.sheetId.isEmpty) {
        return const Tag('Sheets off', tone: TagTone.neutral);
      }
      if (settings.lastSyncAt == null) {
        return const Tag('Sheets waiting', tone: TagTone.warn);
      }
      return Tag(
        settings.syncOk ? 'Sheets synced' : 'Sync pending',
        tone: settings.syncOk ? TagTone.good : TagTone.warn,
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

/// Bottom tab bar. The tab you are on sits in a tinted rounded pill, so which
/// page is open reads without having to compare five icons' shades of grey.
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
      color: Colors.white,
      boxShadow: [
        BoxShadow(color: Color(0x140B2438), blurRadius: 16, offset: Offset(0, -3)),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            for (final (i, tab) in tabs.indexed)
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(T.radiusSm),
                    child: SizedBox(
                      height: 52,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 40,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: i == index
                                      ? T.accent100
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(T.radiusXs),
                                ),
                                child: Icon(
                                  tab.icon,
                                  size: 20,
                                  color: i == index ? T.accent : T.n500,
                                ),
                              ),
                              if (tab.badge > 0)
                                Positioned(
                                  right: -2,
                                  top: -3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: T.pending,
                                      borderRadius: BorderRadius.circular(T.pill),
                                    ),
                                    child: Text(
                                      '${tab.badge}',
                                      style: T.meta.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                        height: 1.2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.tabLabel.copyWith(
                              color: i == index ? T.accent : T.n500,
                              fontWeight: i == index
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Scrollable page body with the standard gutters.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padBottom = 24});

  /// A column of text and figures stops being readable somewhere past this,
  /// so on a tablet the page is centred rather than stretched end to end.
  static const maxContent = 720.0;

  final List<Widget> children;
  final double padBottom;

  /// Side padding for a page this wide: the usual margin on a phone, and
  /// enough on a tablet to hold the column to [maxContent].
  static double sidePad(double width) =>
      width > maxContent + T.pad * 2 ? (width - maxContent) / 2 : T.pad;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final side = sidePad(c.maxWidth);
      return ListView(
        padding: EdgeInsets.fromLTRB(side, T.pad, side, padBottom),
        children: children,
      );
    },
  );
}
