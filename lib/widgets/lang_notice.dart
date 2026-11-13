import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/words.dart';
import '../screens/shared/my_account_screen.dart';
import '../services/db.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Said once: the app reads in Roman Urdu too.
///
/// It opens in English for everybody and will go on doing so — that is
/// what the farm chose. But the choice lives on a screen a man has no
/// reason to open, so somebody who would rather read it in his own has no
/// way of finding out he can.
///
/// Shown until he has seen it, and then never again. Choosing a language
/// counts as having seen it: a man who has already gone and set one does
/// not need telling.
class LangNotice extends StatefulWidget {
  const LangNotice({super.key});

  @override
  State<LangNotice> createState() => _LangNoticeState();
}

class _LangNoticeState extends State<LangNotice> {
  bool _busy = false;

  Future<void> _done() async {
    final uid = context.read<Session>().user?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await Db.users.doc(uid).set({
        'langToldAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Told either way. Worst case it is offered once more.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final me = context.watch<Session>().user;
    if (me == null || me.langToldAt != null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        stripe: T.accent600,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate, size: 18, color: T.accent700),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l.t('The app reads in Roman Urdu too'),
                    style: T.cardTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l.t(
                'It opens in English for everybody. If you would rather '
                'read it in Roman Urdu, change it on your own account — '
                'it changes nothing for anybody else.',
              ),
              style: T.meta,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                GhostButton(
                  label: l.t('Change it'),
                  icon: Icons.person_outline,
                  compact: true,
                  onPressed: _busy
                      ? null
                      : () {
                          _done();
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const MyAccountScreen(),
                            ),
                          );
                        },
                ),
                const SizedBox(width: 8),
                GhostButton(
                  label: l.t('Keep English'),
                  icon: Icons.check,
                  compact: true,
                  onPressed: _busy ? null : _done,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
