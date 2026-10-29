import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/user_repo.dart';
import '../../state/farm_store.dart';
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

  Future<void> _setSkin(Skin skin) async {
    final session = context.read<Session>();
    final user = session.user;
    if (user == null || user.skin == skin || _busy) return;

    // Change it on the spot, then save. The whole app repaints off this one
    // line, and waiting for Firestore to answer first would mean tapping a
    // colour and watching nothing happen for a second on a bad signal.
    skinNow.value = skin;
    setState(() => _busy = true);
    try {
      await UserRepo.setSkin(user.uid, skin);
    } catch (e) {
      if (mounted) toast(context, 'Could not save that. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Puts the farm's own hat on, or takes it off.
  Future<void> _setAsFarm(bool on) async {
    final session = context.read<Session>();
    final user = session.user;
    if (user == null || user.asFarm == on || _busy) return;

    setState(() => _busy = true);
    try {
      await UserRepo.setAsFarm(session.actor, user.uid, on);
      if (mounted) {
        toast(
          context,
          on
              ? L.read(context).t('Working as the farm account now')
              : L.read(context).t2('Working as %s again', user.name),
        );
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not save that. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
          // Only for whoever keeps the farm's cash, and the master. It is
          // not a role — the farm handed Rafeeq that job long before the
          // app had a way of saying so — it is the hat he puts on while he
          // is doing it.
          //
          // Asked for as nullable on purpose. This page is opened straight
          // off the top bar, from above the provider the farm's data is
          // pushed with, and a customer's app has no farm data at all; a
          // plain watch would throw, and a thrown widget is a grey box half
          // a screen tall in a release build. No store, no farm, no hat.
          if (session.role == Role.master ||
              (context.watch<FarmStore?>()?.runsTheFarmAccount(
                    user?.uid ?? '',
                  ) ??
                  false))
            _FarmHatCard(
              on: user?.asFarm ?? false,
              name: user?.name ?? '',
              busy: _busy,
              onChanged: _setAsFarm,
            ),
          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('Theme')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final skin in Skin.values) ...[
                      if (skin != Skin.values.first) const SizedBox(width: 8),
                      Expanded(
                        child: _SkinCard(
                          skin: skin,
                          chosen: (user?.skin ?? Skin.dark) == skin,
                          onTap: () => _setSkin(skin),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l.t(
                    'Dark is easiest at four in the morning and after sunset. '
                    'Light is easiest in the sun. It is yours alone; nobody '
                    'else on the farm changes with it.',
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

/// One skin to pick, painted in its own colours.
///
/// The swatch is a little screen: the page it would give you, a card on it,
/// a line of writing, and the accent. Nothing here goes through [T] — the
/// whole point is to show the two skins you are not wearing.
class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.chosen,
    required this.onTap,
  });

  final Skin skin;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: T.roundSm,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: T.surface,
            borderRadius: T.roundSm,
            border: Border.all(
              color: chosen ? T.accent : T.n300,
              width: chosen ? 1.8 : 1.2,
            ),
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1.25,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: skin.sampleBg,
                    borderRadius: BorderRadius.circular(T.radiusXs),
                    border: Border.all(color: T.n300, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 6,
                        width: 26,
                        decoration: BoxDecoration(
                          color: skin.sampleAccent,
                          borderRadius: BorderRadius.circular(T.pill),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: skin.sampleCard,
                          borderRadius: BorderRadius.circular(T.radiusXs),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 5,
                              width: 34,
                              color: skin.sampleInk,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              height: 4,
                              width: 20,
                              color: skin.sampleGood,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.t(skin.label),
                textAlign: TextAlign.center,
                style: T.meta.copyWith(
                  fontSize: 11.5,
                  fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
                  color: chosen ? T.accent : T.n600,
                ),
              ),
            ],
          ),
        ),
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
          color: chosen ? T.moneyGetWash : T.surface,
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

/// The switch between a man's own hands and the farm's own account.
///
/// Rafeeq keeps the farm's cash. He has his own money in the farm like the
/// others and he runs the farm's account besides, and until now the app knew
/// only the first of those: every entry he made came out under his own name,
/// and the farm's own account could be reached only by typing its name into
/// the handler field and remembering to. Then a purchase was split two ways
/// and the rest of it landed on Rafeeq as money out of his own pocket, which
/// is the day a hat became worth having.
///
/// It grants him nothing he did not have. Everything it touches he could
/// already type by hand; what it does is stop him having to remember to, and
/// say out loud which of the two he is being.
class _FarmHatCard extends StatelessWidget {
  const _FarmHatCard({
    required this.on,
    required this.name,
    required this.busy,
    required this.onChanged,
  });

  final bool on;
  final String name;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return RegCard(
      stripe: on ? T.accent700 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(l.t('Whose hands')),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                on ? Icons.account_balance : Icons.pan_tool_alt_outlined,
                size: 19,
                color: on ? T.accent700 : T.n600,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  on ? l.t(farmAccountName) : name,
                  style: T.bodyMid.copyWith(color: on ? T.accent700 : null),
                ),
              ),
              Switch(value: on, onChanged: busy ? null : onChanged),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            on
                ? l.t(
                    'Money you handle is the farm\'s. New entries open with '
                    'the farm account as the hands it passed through, and '
                    'the accounts page opens on the farm\'s. Your own '
                    'holding is untouched, and the log still names you.',
                  )
                : l.t2(
                    'Money you handle is your own. Turn this on while you '
                    'are running the farm\'s account and %s goes back to '
                    'being just you.',
                    name,
                  ),
            style: T.meta,
          ),
        ],
      ),
    );
  }
}
