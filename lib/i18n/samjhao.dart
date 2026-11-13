import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// What a figure on screen actually means, said in Roman Urdu.
///
/// The app runs in English because that is what the farm chose, and it
/// will go on doing so. But a man reading "in their hand" against a
/// figure he did not expect has no way to find out what the app means by
/// it, and the farm has twice gone a long way round after guessing.
///
/// So the words that carry money keep a plain sentence behind them,
/// always in Roman Urdu whatever the app is set to — because the person
/// who needs it is the person the English did not reach.
///
/// Keyed on the English exactly as it is written on screen.
const samjhao = <String, String>{
  // ---- Who is holding the money ----
  'Who is holding the money':
      'Farm ka naqd is waqt kis kis ke paas hy. Jo kisi ne farm ke liye '
      'liya, us me se jo us ne aage de diya — baqi us ke paas hy.\n\n'
      'Ye us ka hissa ya us ka investment nahi hy. Ye sirf farm ka wo '
      'paisa hy jo abhi us ke haath me hy.',

  'in their hand':
      'Farm ka itna paisa abhi is bande ke paas hy. Jab wo farm ke account '
      'me daal dega ya kisi aur ko de dega, ye sifar ho jayega.',

  'farm owes them':
      'Is bande ne farm ka kharcha apni jaib se kiya aur us ka paisa abhi '
      'wapas nahi mila. Yani farm us ka itna qarzdar hy.',

  'In their hands':
      'Sab ke paas mila kar farm ka kitna naqd hy. Farm account bhi is me '
      'shamil hy.',

  'Out of their pockets':
      'Sab ne mila kar apni jaib se farm ka kitna kharcha kiya jo abhi '
      'wapas nahi mila. Farm itna un ka qarzdar hy.',

  'On its way':
      'Ek bande ne doosre ko paisa diya hy, magar lene wale ne abhi "mil '
      'gaya" nahi kaha. Us waqt tak wo paisa kisi ke bhi khate me nahi '
      'ginaa jata — beech me hota hy.\n\n'
      'Jaise hi lene wala qubool kare, us ke khate me chala jayega.',

  // ---- The two cards at the top ----
  'Still to come in':
      'Jo maal farm ne bech diya magar us ki raqam abhi aani hy. Ye naqd '
      'nahi hy — ye wada hy ke aayega.',

  'Still to go out':
      'Jo maal farm ne khareed liya magar us ki raqam abhi deni hy. Ye bhi '
      'naqd nahi — ye farm ka qarz hy.',

  // ---- The entry's two "who" ----
  'Paid by':
      'Farm ka paisa kis ke haath se nikla. Sirf itna.\n\n'
      'Is se ye nahi hota ke paisa us ka apna tha — wo alag sawal hy, "Kya '
      'ye us ki apni jaib se tha?" wala.',

  'Received by':
      'Farm ka paisa kis ne wasool kiya. Jis ne liya, us ke paas gina '
      'jayega jab tak wo aage na de de.',

  'Whose own money paid for it':
      'Kis ne apni jaib se is kharche ka paisa diya.\n\n'
      'Yehi wo cheez hy jo kisi ke investment ko barhati hy. Upar wala naam '
      '("Paid by") investment ko haath nahi lagata.',

  'Was this his own money?':
      'Agar founder ne apni jaib se ye kharcha kiya hy to ye on kar dein — '
      'raqam us ke investment me chali jaye gi, aur isi entry ke saath '
      'bandhi rahe gi.\n\n'
      'Bandhi hone ka faida: baad me agar entry ka naam badlein, to app '
      'khud poochhegi ke paisa bhi le jayen.',

  // ---- The ledger ----
  'Still open': 'Jin ka hisaab abhi baqi hy — paisa aana hy ya dena hy.',

  'Done with': 'Jin ka hisaab poora ho chuka. Na kuch aana, na dena.',

  'One payment, across %s entries — tap to open/close':
      'Ek hi raqam jo kai dinon ka hisaab chuka gayi. Ledger me wo ek line '
      'ki tarah dikhti hy; tap karne per wo saare din khul jate hain jin '
      'per wo lagi.',

  // ---- Wages ----
  'Advance still owed':
      'Is aadmi ne tankhwah se pehle jo paisa liya tha, us me se itna abhi '
      'wapas nahi hua.\n\n'
      'Agli tankhwah banate waqt app khud poochhegi ke is me se kitna '
      'kaatna hy. Jo na kaatein wo agle mahine per chala jata hy.',

  'Coming off this wage':
      'Is mahine ki tankhwah me se advance ka kitna hissa kaat rahe hain. '
      'Sifar bhi likh sakte hain — baqi agle mahine per chala jayega.',
};

/// Shows what one of these means, if the app has a sentence for it.
Future<void> showSamjhao(BuildContext context, String term) {
  final said = samjhao[term];
  if (said == null) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(T.radius)),
    ),
    builder: (_) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(T.pad, T.pad, T.pad, T.pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(term, style: T.cardTitle),
            const SizedBox(height: 10),
            Text(said, style: T.body.copyWith(height: 1.55)),
            const SizedBox(height: T.pad),
          ],
        ),
      ),
    ),
  );
}

/// A word on screen with its meaning a tap away.
///
/// The mark only appears where there is something to say, so an untouched
/// label never grows a question mark it cannot answer.
class Samjhao extends StatelessWidget {
  const Samjhao({super.key, required this.term, required this.child});

  /// The English exactly as it is written on screen, which is the key.
  final String term;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!samjhao.containsKey(term)) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showSamjhao(context, term),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: child),
          const SizedBox(width: 5),
          Icon(Icons.help_outline, size: 14, color: T.n600),
        ],
      ),
    );
  }
}
