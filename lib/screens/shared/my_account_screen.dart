import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/user_repo.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Everybody's own settings: who they are, and which language they read the
/// app in.
///
/// The language belongs to the person, not the farm. A rider who reads Roman
/// Urdu and a master who reads English are looking at the same records.
class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  bool _busy = false;

  Future<void> _setLang(Lang lang) async {
    final session = context.read<Session>();
    final user = session.user;
    if (user == null || user.lang == lang || _busy) return;

    setState(() => _busy = true);
    try {
      await UserRepo.setLang(user.uid, lang);
    } catch (e) {
      if (mounted) toast(context, 'Could not save that. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final l = L.of(context);
    final user = session.user;

    return FarmScaffold(
      title: l.t('My account'),
      showBack: true,
      body: PageBody(
        children: [
          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('Language')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final lang in Lang.values) ...[
                      if (lang != Lang.values.first) const SizedBox(width: 10),
                      Expanded(
                        child: _LangCard(
                          lang: lang,
                          chosen: (user?.lang ?? Lang.en) == lang,
                          onTap: () => _setLang(lang),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l.t(
                    'The whole app reads in this language — bills, alerts and '
                    'reports too. It is yours alone; nobody else on the farm '
                    'changes with it.',
                  ),
                  style: T.meta,
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('Signed in as')),
                const SizedBox(height: 8),
                Text(user?.name ?? '', style: T.cardTitle),
                Text(user?.email ?? '', style: T.meta),
                const SizedBox(height: 10),
                Tag(l.t(user?.role.label ?? ''), tone: TagTone.accent),
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          GhostButton(
            label: l.t('Sign out'),
            icon: Icons.logout,
            onPressed: session.signOut,
          ),
        ],
      ),
    );
  }
}

/// One language to pick, shown in that language so the choice needs no
/// translating — a reader recognises their own words.
class _LangCard extends StatelessWidget {
  const _LangCard({
    required this.lang,
    required this.chosen,
    required this.onTap,
  });

  final Lang lang;
  final bool chosen;
  final VoidCallback onTap;

  static const _sample = {
    Lang.en: 'Cash in hand',
    Lang.ur: 'Farm ke paas cash',
  };

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: T.roundSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: chosen ? T.moneyGetWash : Colors.white,
          borderRadius: T.roundSm,
          border: Border.all(
            color: chosen ? T.accent : T.n300,
            width: chosen ? 1.6 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Text(
              lang.label,
              style: T.cardTitle.copyWith(
                fontWeight: FontWeight.w600,
                color: chosen ? T.accent700 : T.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _sample[lang]!,
              textAlign: TextAlign.center,
              style: T.meta.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    ),
  );
}
