import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// What this app is, which version of it is on this phone, and whose farm it
/// keeps the books for.
///
/// Four people run this farm from four different phones, and when one of them
/// says a figure is wrong the first useful question is which build he is
/// looking at. Until now there was no way to answer it without asking him to
/// read a number off the Play listing he never installed from.
///
/// The names are here for the same reason the share ratios are: the books are
/// open to the people whose money is in them, and who those people are is part
/// of the books.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<FarmStore>();
    final session = context.watch<Session>();
    final ratios = ratiosOf(store.partners);

    return FarmScaffold(
      title: l.t('About'),
      showBack: true,
      body: PageBody(
        children: [
          Center(
            child: Column(
              children: [
                const FarmLogo(width: 64, mark: true),
                const SizedBox(height: 10),
                Text(
                  store.settings.name.isEmpty
                      ? l.t('Char Yar Dairy Farm')
                      : store.settings.name,
                  style: T.screenTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  l.t('The books four friends keep together'),
                  style: T.meta,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // The one thing worth asking for when a figure is disputed: which
          // build the person looking at it is running.
          SectionTitle(l.t('This app')),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final info = snap.data;
              return RegCard(
                stripe: T.accent600,
                child: Column(
                  children: [
                    _Fact(
                      label: l.t('Version'),
                      value: info == null
                          ? '…'
                          : '${info.version}+${info.buildNumber}',
                    ),
                    const Divider(height: 18),
                    _Fact(
                      label: l.t('Signed in as'),
                      value: session.user?.name ?? '—',
                    ),
                    const Divider(height: 18),
                    _Fact(
                      label: l.t('On this phone you are'),
                      value: l.t(session.role.label),
                    ),
                    const Divider(height: 18),
                    _Fact(
                      label: l.t('What you may do'),
                      value: l.t(session.role.what),
                      wrap: true,
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 18),
          SectionTitle(l.t('The co-founders')),
          const SizedBox(height: 8),
          if (store.partners.isEmpty)
            EmptyNote(l.t('Nobody is on the record yet.'))
          else
            RegCard(
              child: Column(
                children: [
                  for (final (i, p) in store.partners.indexed) ...[
                    if (i > 0) const Divider(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          color: T.partnerColors[i % T.partnerColors.length],
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: T.bodyMid,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                p.pledged > 0
                                    ? l.t2('In for %s', rs(p.pledged))
                                    : l.t2('Put in %s', rs(p.invested)),
                                style: T.meta,
                              ),
                            ],
                          ),
                        ),
                        Tag(
                          '${((ratios[p.id] ?? 0) * 100).toStringAsFixed(0)}%',
                          tone: TagTone.accent,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 18),
          SectionTitle(l.t('How it keeps the books')),
          const SizedBox(height: 8),
          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in [
                  l.t(
                    'A share follows what a man is in for, not what has '
                    'arrived — so it is settled the day he says it and does '
                    'not creep up as he pays.',
                  ),
                  l.t(
                    'What he spends of his own goes onto that promise until '
                    'it is paid. Over it, the farm owes him the difference '
                    'and gives it back out of its own account.',
                  ),
                  l.t(
                    'Whatever of the farm\'s money he takes in stands on its '
                    'own and belongs in the farm account, whatever he has '
                    'spent of his own.',
                  ),
                  l.t(
                    'Nothing on anybody\'s record moves without a line '
                    'saying why, and every line carries a name and a time.',
                  ),
                ]) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 9),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: T.accent600,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(child: Text(line, style: T.body)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),
          Text(
            l.t(
              'Built for this farm and nobody else. Every figure on every '
              'screen comes from the entries the four of you write down.',
            ),
            style: T.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.wrap = false});

  final String label;
  final String value;
  final bool wrap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label, style: T.meta)),
      const SizedBox(width: 12),
      Expanded(
        flex: wrap ? 2 : 1,
        child: Text(value, style: T.bodyMid, textAlign: TextAlign.right),
      ),
    ],
  );
}
