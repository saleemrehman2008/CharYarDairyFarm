import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import 'words.dart';

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

/// The same sentences in Urdu's own script, for the reader who has chosen
/// it.
///
/// Roman Urdu is written in English letters, so a man who cannot read those
/// letters cannot read a word of the table above — and he is exactly the
/// reader this feature exists for. Same keys, same meanings, one alphabet
/// further.
const samjhaoUrdu = <String, String>{
  // ---- Who is holding the money ----
  'Who is holding the money':
      'فارم کا نقد اِس وقت کس کس کے پاس ہے۔ جو کسی نے فارم کے لیے لیا، اُس '
      'میں سے جو اُس نے آگے دے دیا — باقی اُس کے پاس ہے۔\n\n'
      'یہ اُس کا حصہ یا اُس کی سرمایہ کاری نہیں ہے۔ یہ صرف فارم کا وہ پیسہ '
      'ہے جو ابھی اُس کے ہاتھ میں ہے۔',

  'in their hand':
      'فارم کا اِتنا پیسہ ابھی اِس بندے کے پاس ہے۔ جب وہ فارم کے کھاتے میں '
      'ڈال دے گا یا کسی اور کو دے دے گا، یہ صفر ہو جائے گا۔',

  'farm owes them':
      'اِس بندے نے فارم کا خرچہ اپنی جیب سے کیا اور اُس کا پیسہ ابھی واپس '
      'نہیں ملا۔ یعنی فارم اُس کا اِتنا مقروض ہے۔',

  'In their hands':
      'سب کے پاس ملا کر فارم کا کتنا نقد ہے۔ فارم کا کھاتہ بھی اِس میں شامل '
      'ہے۔',

  'Out of their pockets':
      'سب نے مل کر اپنی جیب سے فارم کا کتنا خرچہ کیا جو ابھی واپس نہیں ملا۔ '
      'فارم اِتنا اُن کا مقروض ہے۔',

  'On its way':
      'ایک بندے نے دوسرے کو پیسہ دیا ہے، مگر لینے والے نے ابھی «مل گیا» '
      'نہیں کہا۔ اُس وقت تک وہ پیسہ کسی کے بھی کھاتے میں نہیں گنا جاتا — '
      'بیچ میں ہوتا ہے۔\n\n'
      'جیسے ہی لینے والا قبول کرے، اُس کے کھاتے میں چلا جائے گا۔',

  // ---- The two cards at the top ----
  'Still to come in':
      'جو مال فارم نے بیچ دیا مگر اُس کی رقم ابھی آنی ہے۔ یہ نقد نہیں ہے — '
      'یہ وعدہ ہے کہ آئے گا۔',

  'Still to go out':
      'جو مال فارم نے خرید لیا مگر اُس کی رقم ابھی دینی ہے۔ یہ بھی نقد نہیں '
      '— یہ فارم کا قرض ہے۔',

  // ---- The entry's two "who" ----
  'Paid by':
      'فارم کا پیسہ کس کے ہاتھ سے نکلا۔ صرف اِتنا۔\n\n'
      'اِس سے یہ نہیں ہوتا کہ پیسہ اُس کا اپنا تھا — وہ الگ سوال ہے، «کیا یہ '
      'اُس کی اپنی جیب سے تھا؟» والا۔',

  'Received by':
      'فارم کا پیسہ کس نے وصول کیا۔ جس نے لیا، اُس کے پاس گنا جائے گا جب تک '
      'وہ آگے نہ دے دے۔',

  'Whose own money paid for it':
      'کس نے اپنی جیب سے اِس خرچے کا پیسہ دیا۔\n\n'
      'یہی وہ چیز ہے جو کسی کی سرمایہ کاری کو بڑھاتی ہے۔ اوپر والا نام '
      '(«کس نے دیا») سرمایہ کاری کو ہاتھ نہیں لگاتا۔',

  'Was this his own money?':
      'اگر شریک نے اپنی جیب سے یہ خرچہ کیا ہے تو یہ چالو کر دیں — رقم اُس کی '
      'سرمایہ کاری میں چلی جائے گی، اور اِسی اینٹری کے ساتھ بندھی رہے گی۔'
      '\n\nبندھی ہونے کا فائدہ: بعد میں اگر اینٹری کا نام بدلیں، تو ایپ خود '
      'پوچھے گی کہ پیسہ بھی لے جائیں۔',

  // ---- The ledger ----
  'Still open': 'جن کا حساب ابھی باقی ہے — پیسہ آنا ہے یا دینا ہے۔',

  'Done with': 'جن کا حساب پورا ہو چکا۔ نہ کچھ آنا، نہ دینا۔',

  'One payment, across %s entries — tap to open/close':
      'ایک ہی رقم جو کئی دنوں کا حساب چکا گئی۔ کھاتے میں وہ ایک لائن کی طرح '
      'دکھتی ہے؛ دبانے پر وہ سارے دن کھل جاتے ہیں جن پر وہ لگی۔',

  // ---- Wages ----
  'Advance still owed':
      'اِس آدمی نے تنخواہ سے پہلے جو پیسہ لیا تھا، اُس میں سے اِتنا ابھی '
      'واپس نہیں ہوا۔\n\n'
      'اگلی تنخواہ بناتے وقت ایپ خود پوچھے گی کہ اِس میں سے کتنا کاٹنا ہے۔ '
      'جو نہ کاٹیں وہ اگلے مہینے پر چلا جاتا ہے۔',

  'Coming off this wage':
      'اِس مہینے کی تنخواہ میں سے ایڈوانس کا کتنا حصہ کاٹ رہے ہیں۔ صفر بھی '
      'لکھ سکتے ہیں — باقی اگلے مہینے پر چلا جائے گا۔',
};

/// The table this reader should be shown.
Map<String, String> samjhaoFor(Lang lang) =>
    lang == Lang.urdu ? samjhaoUrdu : samjhao;

/// Shows what one of these means, if the app has a sentence for it.
Future<void> showSamjhao(BuildContext context, String term) {
  final l = L.read(context);
  final said = samjhaoFor(l.lang)[term];
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
        padding: const EdgeInsetsDirectional.fromSTEB(
          T.pad,
          T.pad,
          T.pad,
          T.pad,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The heading reads in the reader's own language, so the sheet
            // does not open with the one English word he came here about.
            Text(l.t(term), style: T.cardTitle),
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
    if (!samjhaoFor(L.of(context).lang).containsKey(term)) return child;
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
