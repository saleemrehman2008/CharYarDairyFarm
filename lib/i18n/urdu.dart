/// The app in Urdu, written the way Urdu is written.
///
/// Its own script, its own font, and the page running right to left. This is
/// not the Roman Urdu table in another dress: a man who reads this one cannot
/// read Latin letters at all, so nothing is left in English here that has an
/// Urdu word — and where Urdu itself has taken the English word (بل، آرڈر،
/// ریٹ، رپورٹ) that word is spelled in Urdu letters rather than left in
/// Latin ones, because the whole point is a page with no Latin on it.
///
/// Figures stay in the numerals the farm already reads: Rs 1,19,200, not
/// ۱٬۱۹٬۲۰۰. Every bill, every WhatsApp message and every rupee note in
/// Pakistan uses these, and a ledger is read for its figures first.
///
/// Keys are the exact English the screen passes to `L.t`, the same keys the
/// Roman Urdu table uses. A phrase not listed here shows in English —
/// checked by `dart run tool/check_words.dart`, which will not let a screen
/// ask for a phrase that no table answers.
library;

const Map<String, String> urduScript = {
  // ---- Roles and people ----
  'Master': 'ماسٹر',
  'Co-founder': 'شریک',
  'Delivery staff': 'رائیڈر',
  'Customer': 'گاہک',
  'Co-founders': 'شریک',
  'Partners': 'شریک',
  'Team': 'ٹیم',
  'Sign out': 'سائن آؤٹ',
  'Sign in with Google': 'گوگل سے سائن اِن کریں',

  // ---- Navigation ----
  'Home': 'گھر',
  'Orders': 'آرڈر',
  'Accounts': 'حساب',
  'Cattle': 'مویشی',
  'More': 'اور',
  'Round': 'راؤنڈ',
  'My day': 'میرا دن',
  'Collect': 'وصولی',
  'Shop': 'دکان',
  'Cart': 'ٹوکری',
  'Khaata': 'کھاتہ',
  'Approvals': 'منظوری',
  'Reports': 'رپورٹ',
  'Report': 'رپورٹ',
  'Settings': 'سیٹنگز',
  'Activity log': 'کام کا ریکارڈ',
  'Handovers': 'حوالگی',
  'Payment details': 'ادائیگی کی تفصیل',
  'Products': 'چیزیں',
  'Bills': 'بل',
  'New entry': 'نئی اینٹری',

  // ---- Money ----
  'Cash in hand': 'فارم کے پاس نقد',
  'With the rider': 'رائیڈر کے پاس',
  'To receive': 'لینا ہے',
  'To pay': 'دینا ہے',
  'Sales': 'فروخت',
  'Costs': 'خرچہ',
  'Running costs': 'چلانے کا خرچہ',
  'Expenses': 'خرچے',
  'Purchases': 'خریداری',
  'Receipts': 'وصولی',
  'Payments': 'ادائیگی',
  'Profit': 'منافع',
  'Net': 'خالص',
  'Total': 'کل',
  'Balance': 'بقایا',
  'Paid': 'ادا ہو گیا',
  'Unpaid': 'بقایا',
  'Amount': 'رقم',
  'Rate': 'ریٹ',
  'Accounts receivable': 'لینا ہے',
  'Accounts payable': 'دینا ہے',
  'Capital': 'سرمایہ',
  'Investment': 'سرمایہ کاری',
  'Withdraw': 'نکالنا ہے',
  'Add to investment': 'سرمایہ کاری میں ڈالیں',
  'Received': 'مل گیا',
  'All': 'سب',
  'Receivable': 'لینا ہے',
  'Payable': 'دینا ہے',

  // ---- Doing things ----
  'Save': 'محفوظ کریں',
  'Cancel': 'رہنے دیں',
  'Delete': 'مٹا دیں',
  'Undo': 'واپس کریں',
  'Approve': 'منظور کریں',
  'Approved': 'منظور',
  'Reject': 'منع کریں',
  'Confirm': 'پکا کریں',
  'Close': 'بند کریں',
  'Add': 'شامل کریں',
  'Edit': 'بدلیں',
  'Done': 'ہو گیا',
  'Pending': 'باقی ہے',
  'Completed': 'مکمل',
  'Open': 'کھلا',
  'Refresh': 'نئی خبر لیں',
  'Try again': 'دوبارہ کوشش کریں',
  'Not now': 'ابھی نہیں',
  'Search': 'ڈھونڈیں',
  'Mark paid': 'ادا شدہ لکھیں',
  'Mark delivered': 'پہنچا دیا لکھیں',
  'Delivered': 'پہنچ گیا',
  'Morning': 'صبح',
  'Evening': 'شام',
  'Today': 'آج',
  'Yesterday': 'کل',

  // ---- Milk and the round ----
  'Milk': 'دودھ',
  'Litres': 'لیٹر',
  'Ghee': 'گھی',
  'Deliveries': 'ڈلیوری',
  'Spot sale': 'ہاتھوں ہاتھ فروخت',
  'Handover': 'حوالگی',
  'Loaded': 'لے کر گیا',
  'Returned': 'واپس لایا',
  'Cash collected': 'نقد وصول',
  'Left to deliver': 'باقی ڈلیوری',
  'Which milking?': 'کون سا وقت؟',
  'Bought in from another farm': 'دوسرے فارم سے خریدا',
  'Our own herd': 'ہمارا اپنا دودھ',
  'Milk sold': 'دودھ کی فروخت',
  'Paid for milk bought in': 'خریدے ہوئے دودھ کی ادائیگی',
  'Left on the milk': 'دودھ پر بچا',
  'at Rs %s a litre on average': 'اوسطاً Rs %s فی لیٹر',
  'more was bought in than went out — check the entries':
      'جتنا گیا اُس سے زیادہ خریدا گیا — اینٹریاں دیکھ لیں',
  'What the milk itself left, before feed, salaries and everything else the '
          'farm spends.':
      'صرف دودھ پر کتنا بچا — ونڈا، تنخواہ اور باقی خرچوں سے پہلے۔',
  '%s L was entered before the app asked which milking. Those litres are in '
          'the totals above but in neither half.':
      '%s L اُس وقت لکھا گیا جب ایپ وقت نہیں پوچھتی تھی۔ وہ لیٹر اوپر کے کل '
      'میں ہیں، مگر صبح یا شام کسی میں نہیں۔',

  // ---- The period ----
  'Month': 'مہینہ',
  'Period': 'مدت',
  'Close month': 'مہینہ بند کریں',
  'Send to founders': 'شریکوں کو بھیجیں',
  'Your share': 'آپ کا حصہ',
  'Profit to share': 'بانٹنے والا منافع',
  'Sealed': 'جم چکا',
  'Waiting': 'انتظار',

  // ---- Cattle ----
  'Buffalo': 'بھینس',
  'Cow': 'گائے',
  'Calf': 'بچہ',
  'Goat': 'بکری',
  'Tag': 'ٹیگ',
  'Vaccination': 'ٹیکہ',
  'Health': 'صحت',
  'Photo': 'تصویر',
  'Add photo': 'تصویر لگائیں',

  // ---- Words the app says back ----
  'Nothing here yet.': 'ابھی یہاں کچھ نہیں۔',
  'Nothing to show.': 'دکھانے کو کچھ نہیں۔',
  'Needs attention': 'توجہ چاہیے',
  'This cannot be undone.': 'یہ واپس نہیں ہوگا۔',
  'Language': 'زبان',
  'My account': 'میرا اکاؤنٹ',
  'Theme': 'رنگ',
  'Dark': 'کالا',
  'Glow': 'سبز',
  'Ember': 'نارنجی',
  'Light': 'سفید',
  'Dark is easiest at four in the morning and after sunset. Light is easiest '
          'in the sun. It is yours alone; nobody else on the farm changes '
          'with it.':
      'صبح چار بجے اور شام کے بعد کالا آسان رہتا ہے، دھوپ میں سفید۔ یہ صرف '
      'آپ کا ہے؛ فارم میں کسی اور کا نہیں بدلتا۔',

  // ---- The farm's room ----
  'Chat': 'بات',
  'Farm room': 'فارم کا کمرہ',
  'Say something to the others': 'باقی سب سے کچھ کہیں',
  'Nothing said here yet.': 'ابھی یہاں کچھ نہیں کہا گیا۔',
  'This room is only for the people who run the farm. Write a name with an @ '
          'in front of it to call somebody out.':
      'یہ کمرہ صرف اُن لوگوں کے لیے ہے جو فارم چلاتے ہیں۔ کسی کو پکارنا ہو '
      'تو نام سے پہلے @ لگائیں۔',

  // ---- Home and getting around ----
  'Farm dashboard': 'فارم کا ڈیش بورڈ',
  'Do': 'کام',
  'Every day': 'روزانہ',
  'The farm': 'فارم',
  'The farm itself': 'خود فارم',
  'Master only': 'صرف ماسٹر',
  'You': 'آپ',
  'Signed in as': 'سائن اِن ہیں بطور',
  'Users': 'لوگ',
  'Users & roles': 'لوگ اور اُن کا کام',
  'User': 'نیا بندہ',
  'Team access': 'ٹیم کی اجازت',
  'Google Sheets': 'گوگل شیٹس',
  'Export books': 'حساب باہر نکالیں',
  'Preparing files…': 'فائلیں تیار ہو رہی ہیں…',
  'Nothing to export yet.': 'ابھی نکالنے کو کچھ نہیں۔',
  '%s files ready — pick where to save them':
      '%s فائلیں تیار — بتائیں کہاں محفوظ کرنی ہیں',
  'Could not export. %s': 'نہیں نکال سکے۔ %s',
  'No sheet linked yet.': 'ابھی کوئی شیٹ جوڑی نہیں گئی۔',
  'Could not open the sheet.': 'شیٹ نہیں کھل سکی۔',
  'Products & rates': 'چیزیں اور ریٹ',
  'Rates': 'ریٹ',
  'Cattle register': 'مویشی رجسٹر',
  'Khaata bills': 'کھاتے کے بل',
  'Khaata sign-ups': 'نئے کھاتے',
  'Daily round': 'روزانہ راؤنڈ',
  'Money to collect': 'وصولی',
  'Orders to deliver': 'پہنچانے والے آرڈر',
  'My orders': 'میرے آرڈر',
  'Checkout': 'ادائیگی',
  'Loading…': 'کھل رہا ہے…',

  // ---- Money on the home page ----
  'Everything the farm can spend today.': 'جو فارم آج خرچ کر سکتا ہے۔',
  '%s is still with the rider': '%s ابھی رائیڈر کے پاس ہے',
  'feed, salaries, bills': 'ونڈا، تنخواہ، بل',
  '+ %s assets': '+ %s کی چیزیں خریدیں',
  '%s unpaid': '%s بقایا',
  '%s bills': '%s بل',
  '%s entries': '%s اینٹریاں',
  'Advance still owed': 'ایڈوانس ابھی باقی ہے',
  'Not coming back': 'واپس نہیں آنا',
  'Take it back': 'واپس لے لیں',
  'The app reads in Urdu too': 'ایپ اردو میں بھی پڑھی جا سکتی ہے',
  'It opens in English for everybody. You can read it in Roman Urdu — Urdu in English letters — or in Urdu script. Change it on your own account; it changes nothing for anybody else.':
      'ایپ سب کے لیے انگریزی میں کھلتی ہے۔ آپ اِسے رومن اردو میں پڑھ سکتے ہیں — اردو، انگریزی حروف میں — یا اردو کی اپنی لکھائی میں۔ اپنے اکاؤنٹ سے بدل لیں؛ کسی اور کے لیے کچھ نہیں بدلے گا۔',
  'Change it': 'بدل لیں',
  'Keep English': 'انگریزی ہی رکھیں',
  'Take this record off?': 'یہ ریکارڈ ہٹا دیں؟',
  '%s comes off the wage list for good. Only a record nothing has been paid against can go — if a wage has been paid to him the app will say so and leave him alone.':
      '%s ہمیشہ کے لیے تنخواہ کی فہرست سے ہٹ جائے گا۔ صرف وہ ریکارڈ ہٹ سکتا '
      'ہے جس پر کچھ نہیں دیا گیا — اگر اُسے تنخواہ ملی ہے تو ایپ بتا دے گی '
      'اور اُسے چھوڑ دے گی۔',
  '%s removed': '%s ہٹا دیا',
  'Open his lines': 'اُس کی لائنیں کھولیں',
  'This is not the farm\'s cash in his pocket. It is %s of his own money put onto his investment with no entry behind it — so a handover cannot put it right.':
      'یہ فارم کا نقد اُس کی جیب میں نہیں ہے۔ یہ %s اُس کا اپنا پیسہ ہے جو '
      'اُس کی سرمایہ کاری پر ڈالا گیا اور اُس کے پیچھے کوئی اینٹری نہیں — اس '
      'لیے حوالگی سے ٹھیک نہیں ہوگا۔',
  'Was this his own money?': 'کیا یہ اُس کی اپنی جیب سے تھا؟',
  'Put it onto what %s has invested, against this entry.':
      'اِس اینٹری کے ساتھ %s کی سرمایہ کاری میں ڈال دیں۔',
  '%s has it on his investment for this entry.':
      'اِس اینٹری پر %s کی سرمایہ کاری میں ہے۔',
  'On %s\'s investment': '%s کی سرمایہ کاری میں',
  'Off %s\'s investment': '%s کی سرمایہ کاری سے باہر',
  'Split it between them': 'آپس میں بانٹ دیں',
  'Whose own money paid for it': 'کس کی اپنی جیب سے گیا',
  'Change whose money': 'کس کا پیسہ تھا، بدلیں',
  'Move his money too?': 'اُس کا پیسہ بھی لے جائیں؟',
  'Move it': 'لے جائیں',
  'Moved %s': '%s لے گئے',
  'His money cannot move': 'اُس کا پیسہ نہیں ہل سکتا',
  'I see': 'سمجھ گیا',
  'Nobody\'s — the farm\'s own cash paid for this. Nothing is on anybody\'s investment for it.':
      'کسی کی نہیں — فارم کے اپنے پیسوں سے ہوا۔ کسی کی سرمایہ کاری پر کچھ '
      'نہیں۔',
  'This is the one that moves what a man has put into the farm. Changing the name above does not.':
      'سرمایہ کاری یہی ہلاتا ہے۔ اوپر والا نام بدلنے سے کچھ نہیں ہلتا۔',
  '%s is on their investment for this entry. Changing the name above does not move it — this does.':
      'اِس اینٹری پر %s اُن کی سرمایہ کاری میں ہے۔ اوپر والا نام بدلنے سے وہ '
      'نہیں ہلتا — یہ ہلاتا ہے۔',
  'Whose hands the farm\'s money passed through. This alone does not say it was his own money — that is the question below.':
      'فارم کا پیسہ کس کے ہاتھ سے گزرا۔ اِس سے یہ نہیں ہوتا کہ پیسہ اُس کا '
      'اپنا تھا — وہ نیچے والا سوال ہے۔',
  'Take it back?': 'واپس لے لیں؟',
  'Taken back': 'واپس لے لیا',
  '%s payment': '%s ادائیگی',
  '%s payments': '%s ادائیگیاں',
  'Where the money is': 'پیسہ کہاں کہاں ہے',
  'Co-founders put in': 'شریکوں نے ڈالا',
  'Cattle & equipment bought': 'مویشی اور سامان خریدا',
  'the farm still owns these': 'یہ اب بھی فارم کی ملکیت ہیں',
  'Running costs so far': 'اب تک کا خرچہ',
  'Sales so far': 'اب تک کی فروخت',
  'Still to collect': 'ابھی لینا ہے',
  'Still to pay': 'ابھی دینا ہے',
  'taken at doors, not handed in yet': 'دروازوں سے ملا، ابھی جمع نہیں کرایا',
  'Earned, not held': 'کمایا، ہاتھ میں نہیں',
  'costs': 'خرچہ',
  'a month': 'ایک مہینے کا',
  'Order': 'آرڈر',
  '%s wants a monthly account': '%s ماہوار کھاتہ چاہتا ہے',
  '%s signed up': '%s نے اکاؤنٹ بنایا',
  'Nothing waiting. The farm is up to date.':
      'کچھ باقی نہیں۔ فارم پورا اپ ٹو ڈیٹ ہے۔',
  '%s of cattle & equipment bought is not counted here — the farm still owns it.':
      '%s کے مویشی اور سامان یہاں شمار نہیں — وہ اب بھی فارم کے ہیں۔',
  'This period has spent more than it has sold. That is not money lost — the farm still holds %s in cash. It is normal while stocking up: feed is bought in one go and eaten over months, while milk sells a little each day.':
      'اِس مدت میں فروخت سے زیادہ خرچ ہوا ہے۔ پیسہ ڈوبا نہیں — فارم کے پاس '
      'اب بھی %s نقد ہے۔ اسٹاک جمع کرتے وقت یہی ہوتا ہے: ونڈا ایک ساتھ آتا '
      'ہے اور مہینوں چلتا ہے، جبکہ دودھ روز تھوڑا تھوڑا بکتا ہے۔',
  'Add co-founders before closing a period — there is nobody to share the profit with yet.':
      'مدت بند کرنے سے پہلے شریک شامل کریں — ابھی منافع بانٹنے کو کوئی ہے '
      'ہی نہیں۔',
  'Work out shares': 'حصے نکالیں',
  '%s is out for decisions': '%s فیصلے کے لیے بھیجا ہوا ہے',

  // ---- The ledger ----
  'Add an entry': 'نئی اینٹری لگائیں',
  'Nothing booked here yet. Tap Add to start.':
      'ابھی یہاں کچھ نہیں لکھا۔ شروع کرنے کے لیے Add دبائیں۔',
  'All farm money in one place: milk & product sales, cattle, feed, bills, rent, food, salaries. Anything sold or bought on credit stays unpaid until you mark it paid.':
      'فارم کا سارا پیسہ ایک جگہ: دودھ اور چیزوں کی فروخت، مویشی، ونڈا، بل، '
      'کرایہ، کھانا، تنخواہ۔ جو اُدھار بکا یا خریدا گیا وہ بقایا رہے گا جب '
      'تک آپ ادا شدہ نہ لکھیں۔',
  'Delete entry': 'اینٹری مٹا دیں',
  'farm asset · not a cost': 'فارم کا مال · خرچہ نہیں',
  'not received': 'ملا نہیں',
  'not paid': 'دیا نہیں',
  'Sales this period': 'اِس مدت کی فروخت',

  // ---- The report ----
  'Chart': 'چارٹ',
  'Detail': 'تفصیل',
  'Money in': 'آمدنی',
  'Money out': 'خرچہ',
  '%s in, %s out': '%s آیا، %s گیا',
  'This period': 'یہ مدت',
  'Last 3 months': 'پچھلے 3 مہینے',
  'This year': 'اِس سال',
  'Everything': 'سب کچھ',
  'Nothing booked in this stretch yet.': 'اِس عرصے میں ابھی کچھ نہیں لکھا۔',
  'Nothing here.': 'یہاں کچھ نہیں۔',
  'Less cattle & equipment': 'مویشی اور سامان نکال کر',
  'Cattle and equipment are taken off the costs, because the money bought something the farm still has.':
      'مویشی اور سامان خرچے سے نکال دیے جاتے ہیں، کیونکہ اُس پیسے سے کوئی چیز '
      'آئی جو اب بھی فارم کے پاس ہے۔',
  'Less advance against wages': 'تنخواہ کا ایڈوانس نکال کر',
  '%s was given out as advance against wages. It is not counted as a cost above — the money is lent, and it comes off the wage it was taken against.':
      '%s تنخواہ کے ایڈوانس میں دیا گیا۔ اوپر اِسے خرچ نہیں گنا گیا — یہ '
      'پیسہ اُدھار ہے، اور جس تنخواہ پر لیا گیا اُس میں سے کٹ جائے گا۔',
  'An advance against wages is taken off the costs, because the money is lent — it comes back off the wage, and the wage itself is the cost.':
      'تنخواہ کا ایڈوانس خرچوں میں سے نکال دیا جاتا ہے، کیونکہ یہ پیسہ '
      'اُدھار ہے — یہ تنخواہ میں سے واپس آتا ہے، اور خرچ خود تنخواہ ہے۔',
  '%s of cattle and equipment was bought in this stretch. It is not counted as a cost above — the farm owns it.':
      'اِس عرصے میں %s کے مویشی اور سامان خریدے گئے۔ اوپر خرچے میں شمار '
      'نہیں — وہ فارم کی ملکیت ہیں۔',

  // ---- A co-founder's own page ----
  'Your share · %s': 'آپ کا حصہ · %s',
  'of %s made in %s so far': '%s میں سے، جو %s میں اب تک کمایا',
  'Your capital': 'آپ کا سرمایہ',
  'put in from your pocket': 'اپنی جیب سے ڈالا',
  'incl. %s left in': 'اِس میں %s چھوڑا ہوا',
  'Farm balance': 'فارم کا بیلنس',
  'cash in hand': 'ہاتھ میں نقد',
  '%s with the rider': '%s رائیڈر کے پاس',
  'Margin': 'منافع کی شرح',
  'of %s sold': '%s کی فروخت میں سے',
  'Milk out': 'دودھ گیا',
  'A DAY': 'روزانہ',
  'THIS PERIOD': 'اِس مدت میں',
  'Across %s days of selling. Counted from the milk that was sold.':
      '%s دن کی فروخت پر۔ جو دودھ بکا اُسی سے گنا گیا ہے۔',
  'Look at': 'دیکھیں',
  'Awaiting approval': 'منظوری کا انتظار',
  'Nothing needs your approval right now.':
      'ابھی آپ کی منظوری کسی چیز کو نہیں چاہیے۔',
  'Open the Approvals tab to act on these.':
      'منظوری والا ٹیب کھولیں اور فیصلہ کریں۔',
  'Your profit history': 'آپ کے منافع کا ریکارڈ',
  'No capital recorded for you yet.': 'ابھی آپ کا کوئی سرمایہ لکھا نہیں۔',
  'No period has been closed yet.': 'ابھی کوئی مدت بند نہیں ہوئی۔',
  'Taken out': 'نکالا',
  'Left in as investment': 'سرمایہ کاری کے طور پر چھوڑا',
  'Entered by %s': 'اینٹری %s نے کی',

  // ---- Google Sheet ----
  'Google Sheet': 'گوگل شیٹ',
  'A second copy of the books, kept up to date by itself. Every change in the '
          'app reaches the Sheet a few seconds later — there is nothing to '
          'press.':
      'حساب کی دوسری نقل، جو خود بخود اپ ڈیٹ رہتی ہے۔ ایپ میں جو بھی بدلے وہ '
      'چند سیکنڈ میں شیٹ تک پہنچ جاتا ہے — کچھ دبانا نہیں پڑتا۔',
  'not linked': 'جُڑی نہیں',
  'needs permission': 'اجازت چاہیے',
  'live': 'چل رہی ہے',
  'Paste the sheet link': 'شیٹ کا لنک یہاں لگائیں',
  'Link this sheet': 'یہ شیٹ جوڑیں',
  'Sheet linked.': 'شیٹ جُڑ گئی۔',
  'That does not look like a Google Sheet link.':
      'یہ گوگل شیٹ کا لنک نہیں لگ رہا۔',
  'Allow the app to write to it': 'ایپ کو لکھنے کی اجازت دیں',
  'Allowed. The Sheet will keep up on its own now.':
      'اجازت مل گئی۔ اب شیٹ خود ساتھ چلتی رہے گی۔',
  'Google did not allow it. %s': 'گوگل نے اجازت نہیں دی۔ %s',
  'Nothing written to it yet.': 'ابھی اِس میں کچھ نہیں لکھا گیا۔',
  'Last written %s': 'آخری بار لکھا %s',
  'Write it now': 'ابھی لکھ دیں',
  'Written to the Sheet.': 'شیٹ میں لکھ دیا۔',
  'Could not write. %s': 'لکھ نہیں سکے۔ %s',
  'Use another sheet': 'کوئی اور شیٹ',
  'The Sheet needs to be shared so that anyone with the link can edit it. The '
          'app writes its own tabs — Summary, Entries, Periods, Co-founders, '
          'Khaata, Deliveries, Cattle — and rewrites them each time. Any other '
          'tab you build is left alone.':
      'شیٹ ایسی شیئر ہونی چاہیے کہ جس کے پاس لنک ہو وہ ایڈٹ کر سکے۔ ایپ اپنے '
      'ٹیب لکھتی ہے — Summary، Entries، Periods، Co-founders، Khaata، '
      'Deliveries، Cattle — اور ہر بار نئے سرے سے۔ جو ٹیب آپ خود بنائیں '
      'اُسے ہاتھ نہیں لگاتی۔',

  // ---- The running ledger ----
  'closed here': 'یہاں بند ہوا',
  'Started %s': 'شروع ہوا %s',
  'open now': 'ابھی کھلا ہے',
  'sealed — waiting on the co-founders': 'جم گیا — شریکوں کا انتظار',
  'earlier': 'اِس سے پہلے',
  '%s shared between the co-founders': '%s شریکوں میں بٹا',
  'Nothing was shared out of this one.': 'اِس میں سے کچھ نہیں بٹا۔',

  // ---- Zero to here ----
  'Summary': 'خلاصہ',
  'Made since day one': 'شروع سے اب تک کمایا',
  'All time': 'شروع سے',
  '%s sold, %s spent on running the farm':
      '%s کا بکا، %s فارم چلانے پر خرچ ہوا',
  'Put in': 'ڈالا گیا',
  'by the co-founders': 'شریکوں نے',
  'Sold': 'بکا',
  'Spent': 'خرچ',
  'Owns': 'ملکیت',
  'cattle & equipment': 'مویشی اور سامان',
  'Cash now': 'ابھی نقد',
  'Period by period': 'ہر مدت کا حساب',
  'Newest first. The open one is still running.':
      'نیا سب سے اوپر۔ جو کھلا ہے وہ ابھی چل رہا ہے۔',
  'No period has been settled yet — this is the first one.':
      'ابھی کوئی مدت بند نہیں ہوئی — یہ پہلی ہے۔',
  '%s went to the co-founders': '%s شریکوں کو گیا',
  'open': 'کھلا',
  'closed': 'بند',
  'waiting': 'انتظار',

  // ---- Day by day, and the capital ----
  'Day by day': 'روز بہ روز',
  'Week by week': 'ہفتہ بہ ہفتہ',
  'In': 'آیا',
  'Out': 'گیا',
  'Best day: %s, %s': 'سب سے اچھا دن: %s، %s',
  'Best week: the one from %s, %s': 'سب سے اچھا ہفتہ: %s سے، %s',
  'What the co-founders have in': 'شریکوں کا لگایا ہوا',
  'No co-founders yet.': 'ابھی کوئی شریک نہیں۔',
  'put in from their own pocket': 'اپنی جیب سے ڈالا',
  'incl. %s left in from profit': 'اِس میں %s منافع کا چھوڑا ہوا',
  'Total capital': 'کل سرمایہ',
  'Taken out so far': 'اب تک نکالا',

  // ---- Settling the period ----
  'Settle %s': '%s کا حساب',
  'Freeze %s?': '%s کو جما دیں؟',
  'Send': 'بھیج دیں',
  'Send to co-founders': 'شریکوں کو بھیجیں',
  'Sent. Waiting on the co-founders.': 'بھیج دیا۔ اب شریکوں کا انتظار۔',
  'Could not send it. %s': 'بھیج نہیں سکے۔ %s',
  'Receivables': 'بقایا',
  'Receivables kept': 'بقایا شامل',
  'Uncollected receivables': 'جو وصول نہیں ہوا',

  // ---- Advances the farm is holding ----
  'Advances held': 'ایڈوانس جو رکھا ہوا ہے',
  'Advances paid out': 'ایڈوانس جو دیا ہوا ہے',
  'Earnings': 'کمائی',
  'Cost': 'خرچہ',
  'Only cash': 'صرف نقد',
  'Remove': 'ہٹائیں',
  'Removed.': 'ہٹا دیا۔',
  'Remove this?': 'اِسے ہٹائیں؟',
  'Remove a loan that was handed over?': 'جو قرض دے دیا گیا، اُسے ہٹائیں؟',
  'No money ever went through this one, so there is nothing to lose.':
      'اِس میں سے کبھی کوئی پیسہ گزرا ہی نہیں، تو کھونے کو کچھ نہیں۔',
  'This takes the arrangement off the list. The money is not touched — it really did leave the farm, and the ledger keeps saying so. If the whole thing was a mistake, delete those entries in Accounts instead.':
      'یہ صرف انتظام کو فہرست سے ہٹاتا ہے۔ پیسے کو ہاتھ نہیں لگتا — وہ واقعی '
      'فارم سے گیا تھا، اور کھاتہ یہی کہتا رہے گا۔ اگر پوری بات ہی غلط تھی '
      'تو وہ اینٹریاں حساب میں جا کر مٹائیں۔',
  'money that belongs to customers, and goes back when a contract ends':
      'یہ گاہک کا پیسہ ہے، معاہدہ ختم ہونے پر واپس جاتا ہے',
  'Advance the farm is holding': 'ایڈوانس جو فارم کے پاس پڑا ہے',
  'It belongs to them, not the farm. It goes back when they stop.':
      'یہ اُن کا پیسہ ہے، فارم کا نہیں۔ جب وہ چھوڑیں گے، واپس جائے گا۔',

  // ---- The statement ----
  //
  // Debit, credit and balance are written in Urdu letters here rather than
  // left in Latin ones: a page with no Latin on it is the whole point of
  // this table, and a customer handed the statement reads these three
  // words off it the same way he hears them said.
  'Statement': 'اسٹیٹمنٹ',
  'Statement of account': 'کھاتے کا اسٹیٹمنٹ',
  'Cash book': 'روزچہ',
  'Char Yar Dairy Farm': 'چار یار ڈیری فارم',
  'Whose statement?': 'کس کا اسٹیٹمنٹ؟',
  'The whole farm': 'پورا فارم',
  'All dates': 'سارے دن',
  '%s days': '%s دن',
  'Which days': 'کون سے دن',
  'Last 30 days': 'پچھلے 30 دن',
  '3 months': '3 مہینے',
  'A year': 'ایک سال',
  'Pick the days': 'دن چنیں',
  'Everything, from the start': 'شروع سے اب تک',
  'Issued': 'بنایا گیا',
  'Account': 'کھاتہ',
  'Opening': 'شروع کا بقایا',
  'Date': 'تاریخ',
  'Name': 'نام',
  'Entered by': 'اینٹری کی',
  'Debit': 'ڈیبٹ',
  'Credit': 'کریڈٹ',
  'Total debit': 'کل ڈیبٹ',
  'Total credit': 'کل کریڈٹ',
  'The farm owes': 'فارم کو دینا ہے',
  'Nothing in these days.': 'اِن دنوں میں کچھ نہیں۔',
  'Send as PDF': 'پی ڈی ایف بھیجیں',
  'Send as picture': 'تصویر بھیجیں',
  'Could not make the PDF. %s': 'پی ڈی ایف نہیں بن سکی۔ %s',
  'Could not make the picture. %s': 'تصویر نہیں بن سکی۔ %s',

  // ---- Every heading on the entry form ----
  'Butter': 'مکھن',
  'Cream': 'بالائی',
  'Khoya': 'کھویا',
  'Paneer': 'پنیر',
  'Dahi': 'دہی',
  'Lassi': 'لسی',
  'Cattle sale': 'جانور کی فروخت',
  'Dung / manure': 'گوبر اور کھاد',
  'Other sale': 'کوئی اور فروخت',
  'Fodder / feed': 'ونڈا اور چارہ',
  'Milk bought in': 'دوسرے فارم سے دودھ خریدا',
  'Vet & medicine': 'دوائی اور ڈاکٹر',
  'Food & kitchen': 'کھانا اور باورچی خانہ',
  'Salaries': 'تنخواہ',
  'Salary advance': 'تنخواہ کا ایڈوانس',
  'Rent': 'کرایہ',
  'Utilities (bijli, gas, pani)': 'بجلی، گیس، پانی',
  'Transport': 'ٹرانسپورٹ',
  'Repairs': 'مرمت',
  'Cattle purchase': 'جانور کی خرید',
  'Equipment': 'مشینری اور سامان',
  'Other purchase': 'کوئی اور خرید',
  'Loan repayment': 'قرض کی قسط',
  'Khaata receipt': 'کھاتے کی وصولی',
  'Profit share': 'منافع کا حصہ',
  'Cattle write-off': 'جانور کتاب سے نکالا',
  'Founder loan': 'شریک کو دیا قرض',
  'Given up on — not coming back': 'چھوڑ دیا — اب نہیں آنا',
  'Handed to a co-founder': 'شریک کو دیا',
  'Taken from a co-founder': 'شریک سے لیا',

  // ---- Correcting an entry that was written wrong ----
  'Correct this entry': 'اِس اینٹری کو ٹھیک کریں',
  'Corrections': 'درستیاں',
  'Save the correction': 'درستی محفوظ کریں',
  'Entry corrected': 'اینٹری ٹھیک کر دی',
  'What was written down, not what happened. Everything you change is kept on the entry with your name against it.':
      'جو لکھا گیا تھا وہ، نہ کہ جو ہوا تھا۔ آپ جو بھی بدلیں وہ اینٹری پر '
      'آپ کے نام کے ساتھ محفوظ رہتا ہے۔',
  'This entry belongs to %s, which is already settled. Nothing in a settled period can be corrected — the profit was worked out from it and shared. Put the correction in the open period as a new entry.':
      'یہ اینٹری %s کی ہے، جو بند ہو چکی ہے۔ بند مدت میں کچھ ٹھیک نہیں ہو '
      'سکتا — اُس کا منافع نکال کر بٹ چکا ہے۔ درستی کھلی مدت میں نئی اینٹری '
      'کے طور پر ڈالیں۔',

  // ---- The activity log ----
  'Changes to entries': 'اینٹریوں میں تبدیلیاں',
  'Who has changed what': 'کس نے کیا بدلا',
  '%s in all': 'کل %s',
  '%s times': '%s بار',
  'Counted out of the lines below. Every one of them says which entry it was and what moved.':
      'نیچے والی لائنوں سے گنا گیا۔ ہر لائن بتاتی ہے کون سی اینٹری تھی اور '
      'اُس میں کیا بدلا۔',
  'Nobody has gone back over an entry. Everything on the books is as it was first written.':
      'کسی نے کوئی اینٹری دوبارہ نہیں چھوئی۔ کتاب میں سب ویسا ہی ہے جیسا '
      'پہلے لکھا گیا تھا۔',
  'Nothing has been changed after it was written.':
      'لکھے جانے کے بعد کچھ نہیں بدلا گیا۔',
  'Nothing logged yet.': 'ابھی تک کچھ ریکارڈ نہیں ہوا۔',
  'Login': 'لاگ اِن',
  'Transaction': 'اینٹری',
  'Correction': 'درستی',
  'Entry deleted': 'اینٹری ہٹائی گئی',
  'Month close': 'مہینہ بند',
  'Udhaar': 'اُدھار',

  // ---- Giving up on money that is not coming back ----
  'Give up on %s': '%s چھوڑ دیں',
  'Give up on it': 'چھوڑ دیں',
  'Give up on this money?': 'یہ پیسہ چھوڑ دینا ہے؟',
  '%s written off': '%s چھوڑ دیا',
  'Could not write it off. %s': 'چھوڑا نہیں جا سکا۔ %s',
  'For money nobody is going to pay. The entry is settled and what is left of it becomes a cost — the profit drops by it, and no cash moves.':
      'اُس پیسے کے لیے جو کوئی نہیں دینے والا۔ اینٹری پوری ہو جاتی ہے اور جو '
      'بچا وہ خرچہ بن جاتا ہے — منافع اُتنا کم، اور نقد ہلتا بالکل نہیں۔',
  '%s · %s\n\nThe entry is marked settled and this becomes a cost of the open period, so the profit drops by it. No cash moves — it never came. It cannot be undone except by entering it again as a fresh sale.':
      '%s · %s\n\nاینٹری پوری لکھ دی جائے گی اور یہ کھلی مدت کا خرچہ بن جائے '
      'گا، تو منافع اُتنا کم ہو جائے گا۔ نقد نہیں ہلتا — وہ آیا ہی نہیں تھا۔ '
      'واپس صرف نئی فروخت ڈال کر ہی ہو سکتا ہے۔',

  // ---- Whose hands the farm's cash is in ----
  'Who is holding the money': 'پیسہ کس کے پاس ہے',
  '%s people': '%s لوگ',
  '%s taken in · %s handed out': '%s لیا · %s دیا',
  'in their hand': 'اُن کے پاس ہے',
  'farm owes them': 'فارم نے دینا ہے',
  'In their hands': 'اُن کے ہاتھ میں',
  'Out of their pockets': 'اُن کی اپنی جیب سے',
  'Nobody named': 'نام نہیں لکھا',
  'Nobody has handled any money yet. Every entry asks who took it in or handed it over, and that is what this is counted from.':
      'ابھی تک کسی نے پیسہ نہیں سنبھالا۔ ہر اینٹری پوچھتی ہے کس نے لیا یا '
      'دیا، اسی سے یہ حساب بنتا ہے۔',
  'Taken in, less handed out, for every entry with a name against it. Below nothing means they have paid the farm\'s costs out of their own pocket and the farm owes them.':
      'جتنا لیا، اُس میں سے جتنا دیا — ہر اُس اینٹری کا جس پر نام لکھا ہے۔ '
      'صفر سے نیچے کا مطلب ہے کہ اُنہوں نے فارم کا خرچہ اپنی جیب سے کیا اور '
      'فارم نے اُن کو دینا ہے۔',
  'Transfer': 'منتقلی',
  'Hand cash to somebody': 'کسی کو پیسہ دینا',
  'Into the farm account': 'فارم کے کھاتے میں جمع کریں',
  'Nobody is on the wage list yet. More → Wages puts them on it.':
      'ابھی تنخواہ کی فہرست پر کوئی نہیں۔ «اور» میں جا کر «تنخواہ» سے اُن کو فہرست پر '
      'ڈالیں۔',
  'Nobody of that name is on the wage list. Put him on it first, under More → Wages.':
      'اِس نام کا کوئی تنخواہ کی فہرست پر نہیں۔ پہلے اُسے «اور» میں جا کر «تنخواہ» میں '
      'ڈالیں۔',
  'Salary slip': 'تنخواہ کی پرچی',
  'Switched on, the form holds until it is told. Off, it fills in a sensible answer and trusts whoever is entering to change it.':
      'چالو ہو تو فارم رُکتا ہے جب تک بتایا نہ جائے۔ بند ہو تو خود ایک مناسب '
      'جواب بھر دیتا ہے اور بھرنے والے پر چھوڑ دیتا ہے کہ بدل لے۔',
  'What an entry must say': 'اینٹری میں کیا بتانا ضروری ہے',
  'Morning or evening': 'صبح یا شام',
  'Paid now, or on the account': 'ابھی دیا، یا کھاتے پر',
  'Who handled the money': 'پیسہ کس کے ہاتھ لگا',
  'A buffalo is milked twice a day. Left unanswered the litres land in neither half.':
      'بھینس دن میں دو بار دوہی جاتی ہے۔ نہ بتایا جائے تو لیٹر کسی طرف نہیں '
      'جاتے۔',
  'Picked for them, an entry that was really on credit goes in as cash whenever nobody looks at the toggle.':
      'پہلے سے چنا ہوا ہو تو جو اینٹری اصل میں اُدھار کی تھی وہ نقد میں چلی '
      'جاتی ہے، جب کوئی اُس بٹن کو دیکھتا ہی نہیں۔',
  'Money that moved with no name against it cannot be asked about a month later.':
      'جس پیسے پر کسی کا نام نہ ہو، اُس کے بارے میں مہینے بعد کوئی پوچھ بھی '
      'نہیں سکتا۔',
  'Pick one — cash now, or on the account.':
      'ایک چنیں — ابھی نقد، یا کھاتے پر۔',
  'Has it been paid? Pick one first.': 'پیسہ دیا گیا ہے؟ پہلے یہ بتائیں۔',
  'Which milking? A buffalo is milked twice a day, and left unanswered the litres land in neither half.':
      'کون سی دوہائی؟ بھینس دن میں دو بار دوہی جاتی ہے، اور نہ بتایا جائے تو '
      'لیٹر کسی طرف نہیں جاتے۔',
  'This one is needed. Money that moved with no name against it cannot be asked about a month later.':
      'یہ ضروری ہے۔ جس پیسے پر کسی کا نام نہ ہو، اُس کے بارے میں مہینے بعد '
      'کوئی پوچھ بھی نہیں سکتا۔',
  'Tag number': 'ٹیگ نمبر',
  'What is written on her tag': 'جو اُس کے ٹیگ پر لکھا ہے',
  'Leave it blank and the app will give her one.':
      'خالی چھوڑ دیں تو ایپ خود ایک دے دے گی۔',
  'Farm assets': 'فارم کی ملکیت',
  'What the farm keeps': 'جو فارم کے پاس رہتا ہے',
  '%s entries · %s on this page': '%s اینٹریاں · اِس صفحے پر %s',
  'A share follows what a man is in for, not what has arrived — so it is settled the day he says it and does not creep up as he pays.':
      'حصہ اِس بات سے چلتا ہے کہ آدمی نے کتنا دینے کا کہہ رکھا ہے، اِس سے '
      'نہیں کہ کتنا آ چکا — اس لیے وہ اُسی دن طے ہو جاتا ہے اور بعد میں '
      'بڑھتا نہیں۔',
  'About': 'ایپ کے بارے میں',
  'Built for this farm and nobody else. Every figure on every screen comes from the entries the four of you write down.':
      'صرف اِسی فارم کے لیے بنائی گئی ہے۔ ہر صفحے کا ہر ہندسہ اُنہی اینٹریوں '
      'سے بنتا ہے جو آپ چاروں لکھتے ہیں۔',
  'How it keeps the books': 'حساب کس اصول پر رکھتی ہے',
  'In for %s': '%s دینے ہیں',
  'Nobody is on the record yet.': 'ابھی ریکارڈ پر کوئی نہیں۔',
  'Nothing on anybody\'s record moves without a line saying why, and every line carries a name and a time.':
      'کسی کے ریکارڈ پر کچھ بھی بغیر وجہ لکھے نہیں ہلتا، اور ہر لائن پر نام '
      'اور وقت لکھا ہوتا ہے۔',
  'On this phone you are': 'اِس فون پر آپ',
  'The books four friends keep together': 'چار دوستوں کا سانجھا حساب',
  'The co-founders': 'شریک',
  'This app': 'یہ ایپ',
  'Version': 'ورژن',
  'What he spends of his own goes onto that promise until it is paid. Over it, the farm owes him the difference and gives it back out of its own account.':
      'جو وہ اپنی جیب سے خرچ کرتا ہے وہ اُسی وعدے میں جاتا رہتا ہے جب تک وہ '
      'پورا نہ ہو۔ اُس سے اوپر جو ہو وہ فارم اُس کا دینا ہے اور اپنے کھاتے '
      'سے واپس کرتا ہے۔',
  'What you may do': 'آپ کیا کر سکتے ہیں',
  'Whatever of the farm\'s money he takes in stands on its own and belongs in the farm account, whatever he has spent of his own.':
      'فارم کا جو بھی پیسہ وہ لیتا ہے وہ الگ کھڑا رہتا ہے اور فارم کے کھاتے '
      'میں جانا ہے، چاہے اُس نے اپنی جیب سے کتنا ہی خرچ کیا ہو۔',
  'Everything, including the figures nobody else may touch':
      'سب کچھ، وہ ہندسے بھی جنہیں کوئی اور نہیں چھو سکتا',
  'The books, and the day to day running of the farm':
      'حساب کتاب، اور فارم کا روزانہ کام',
  'Looks at everything. Changes nothing.': 'سب کچھ دیکھتا ہے۔ کچھ نہیں بدلتا۔',
  'The round: milk dropped off and money taken at the door':
      'راؤنڈ: دودھ پہنچانا اور دروازے پر پیسہ لینا',
  'Their own orders and their own khaata': 'اپنے آرڈر اور اپنا کھاتہ',
  'Silent investor': 'خاموش سرمایہ کار',
  '%s · open now': '%s · ابھی کھلا ہے',
  'From': 'کب سے',
  'To': 'کب تک',
  'Which period': 'کون سی مدت',
  'From which day': 'کس دن سے',
  'To which day': 'کس دن تک',
  'His account': 'اُس کا کھاتہ',
  'Running cost': 'چلانے کا خرچہ',
  'Spent on what the farm keeps': 'جو فارم کے پاس رہتا ہے اُس پر لگا',
  'Put in by the co-founders': 'شریکوں نے جو ڈالا',
  'Brought forward': 'پچھلا بقایا',
  'After paying them back': 'اُن کو واپس دینے کے بعد',
  'Every rupee in the account is owed back to one of them.':
      'کھاتے کا ہر روپیہ اُن میں سے کسی کو واپس دینا ہے۔',
  'It owes them more than it is holding. Nothing in this account is the farm\'s until that is paid back.':
      'جتنا فارم کے پاس ہے اُس سے زیادہ اُن کا دینا ہے۔ جب تک وہ واپس نہ ہو، '
      'اِس کھاتے میں فارم کا کچھ بھی نہیں۔',
  'The farm\'s own, free and clear': 'فارم کا اپنا، صاف',
  'Their own money, in the farm': 'اُن کا اپنا پیسہ، فارم میں',
  'He has not left': 'وہ گیا ہی نہیں',
  'His last month is worked out from these two days. Both of them count as worked.':
      'اُس کے آخری مہینے کا حساب اِنہی دو تاریخوں سے بنتا ہے۔ دونوں دن کام '
      'میں گنے جاتے ہیں۔',
  'Last day': 'آخری دن',
  'Still here': 'ابھی یہیں ہے',
  '%s of the old books to square': 'پرانے حساب میں %s برابر کرنے ہیں',
  'Anything taken in after today stands on its own and still has to be paid into the farm account.':
      'آج کے بعد جو بھی پیسہ لیا جائے گا وہ الگ کھڑا رہے گا اور فارم کے '
      'کھاتے میں جمع کرنا ہوگا۔',
  'Each of them took this much of the farm\'s money in and paid at least this much of the farm\'s costs back out. Agreeing it here says those were the same notes, so neither owes the other for them.':
      'اِن میں سے ہر ایک نے فارم کا اِتنا پیسہ لیا اور کم از کم اِتنا ہی فارم '
      'کے خرچوں میں دیا۔ یہاں ہاں کرنے کا مطلب ہے کہ یہ وہی نوٹ تھے، تو اب '
      'کوئی کسی کا مقروض نہیں۔',
  'Money they took in for the farm and spent on the farm before the rule was settled — the same notes, going out the same day they came in. The books now ask them to pay it in and hand it back, which is two trips to the same place.':
      'جو پیسہ اُنہوں نے فارم کے لیے لیا اور اصول طے ہونے سے پہلے فارم ہی پر '
      'خرچ کر دیا — وہی نوٹ، اُسی دن آئے اُسی دن گئے۔ اب کتاب کہہ رہی ہے کہ '
      'پہلے جمع کراؤ پھر واپس لو، جو ایک ہی جگہ کے دو چکر ہیں۔',
  'Nothing in the ledger moves. Every entry stays exactly where it is and every balance is still worked out from all of them — this only writes down what the four of you have agreed.':
      'کتاب میں کچھ نہیں ہلتا۔ ہر اینٹری اپنی جگہ رہے گی اور ہر بقایا اُن سب '
      'سے ہی بنے گا — یہ صرف وہ لکھ رہا ہے جس پر آپ چاروں راضی ہوئے ہیں۔',
  'Said once, with your name on it in the log. Nothing in the ledger moves. Anything taken in after today stands on its own and still has to reach the farm account.':
      'ایک بار کہا جاتا ہے، ریکارڈ میں آپ کے نام کے ساتھ۔ کتاب میں کچھ نہیں '
      'ہلتا۔ آج کے بعد کا لیا ہوا پیسہ الگ کھڑا رہے گا اور فارم کے کھاتے تک '
      'پہنچنا ہوگا۔',
  'Squared': 'برابر ہو گیا',
  'The day it changed hands': 'جس دن ہاتھ بدلا',
  'These were the same rupees': 'یہ وہی پیسے تھے',
  'They were the same': 'وہی تھے',
  'Were these the same rupees?': 'کیا یہ وہی پیسے تھے؟',
  '%s of it to pay into the farm account':
      'اِس میں سے %s فارم کے کھاتے میں جمع کرنے ہیں',
  '%s a full month': 'پورے مہینے کا %s',
  '%s has left?': '%s چھوڑ کر چلا گیا؟',
  '%s to %s': '%s سے %s تک',
  '%s wage · %s allowance': '%s تنخواہ · %s الاؤنس',
  '%s man': '%s بندہ',
  '%s men': '%s بندے',
  'A month': 'مہینے کا',
  'Allowance (Rs)': 'الاؤنس (Rs)',
  'CNIC': 'شناختی کارڈ',
  'Every month in wages': 'ہر مہینے تنخواہوں میں',
  'He comes off the wage list from today. His record stays where it is — the months he was paid for are already closed, and a figure whose name has gone is worth nothing to anybody.':
      'آج سے وہ تنخواہ کی فہرست سے نکل جائے گا۔ اُس کا ریکارڈ وہیں رہے گا — '
      'جن مہینوں کی اُس نے تنخواہ لی وہ بند ہو چکے ہیں، اور جس ہندسے کا نام '
      'ہی غائب ہو وہ کسی کام کا نہیں۔',
  'He has left': 'چلا گیا',
  'He is back': 'واپس آ گیا',
  'Joined': 'کب سے',
  'Mobile': 'موبائل نمبر',
  'No longer here': 'اب یہاں نہیں ہیں',
  'Nobody on the wage list yet. Anybody the farm pays every month belongs here — the man who milks, the one who cleans, the one who walks the round.':
      'ابھی تنخواہ کی فہرست میں کوئی نہیں۔ جس کو بھی فارم ہر مہینے پیسے دیتا '
      'ہے وہ یہاں ہونا چاہیے — دودھ نکالنے والا، صفائی کرنے والا، راؤنڈ پر '
      'جانے والا۔',
  'On the wage list': 'تنخواہ کی فہرست پر',
  'Or keep %s you are holding': 'یا جو %s آپ کے پاس ہے وہی رکھ لیں',
  'Pay %s from the farm account': 'فارم کے کھاتے سے %s دے دیں',
  'Pay it': 'دے دیں',
  'Put somebody on the wage list': 'کسی کو تنخواہ کی فہرست پر ڈالیں',
  'Since %s': '%s سے',
  'Take it out of the farm account?': 'فارم کے کھاتے سے نکال لیں؟',
  'The farm pays you %s out of its own account and stops owing it. That is where the farm\'s earnings sit, and it is what the account is for — nothing of anybody else\'s is touched.':
      'فارم اپنے کھاتے سے آپ کو %s دے دے گا اور اُس کا دینا ختم۔ فارم کی '
      'کمائی وہیں رہتی ہے اور کھاتہ اسی لیے ہے — کسی اور کا کچھ نہیں چھیڑا '
      'جاتا۔',
  'The farm\'s own account has %s in it, which is what it is for.':
      'فارم کے اپنے کھاتے میں %s موجود ہیں، اور کھاتہ اسی کام کے لیے ہے۔',
  'Wage a month (Rs)': 'مہینے کی تنخواہ (Rs)',
  'Wages': 'تنخواہیں',
  'What is he paid a month?': 'اُس کی مہینے کی تنخواہ کتنی ہے؟',
  'What they are owed a month, and the two numbers the farm needs to find them again. The salary entry then picks a name off this list and works the figure out from the record rather than from memory.':
      'کس کو مہینے کا کتنا دینا ہے، اور وہ دو نمبر جن سے فارم اُسے دوبارہ '
      'ڈھونڈ سکے۔ پھر تنخواہ کی اینٹری اِسی فہرست سے نام اٹھاتی ہے اور ہندسہ '
      'ریکارڈ سے بناتی ہے، یاد داشت سے نہیں۔',
  'Who is this?': 'یہ کون ہے؟',
  'Working here': 'یہاں کام کر رہے ہیں',
  '%s is holding none of the farm\'s cash — he is %s out of his own pocket.':
      '%s کے پاس فارم کا کوئی پیسہ نہیں — اُلٹا اُس کی اپنی جیب سے %s لگا '
      'ہوا ہے۔',
  'What came in through him has gone out again on the farm\'s costs. Anything he hands over now is his own money, and the farm will owe him that much more.':
      'جو پیسہ اُس کے ذریعے آیا تھا وہ فارم کے خرچوں میں نکل چکا ہے۔ اب وہ جو '
      'بھی دے گا وہ اُس کا اپنا پیسہ ہوگا، اور فارم کا اُتنا ہی زیادہ دینا '
      'ہو جائے گا۔',
  'Put into the farm account': 'فارم کے کھاتے میں جمع کیا',
  'Taken out of the farm account': 'فارم کے کھاتے سے نکالا',
  'Out of %s · into %s': '%s سے نکلا · %s میں آیا',
  'Bought and not yet paid for': 'خریدا ہے، پیسہ دینا باقی ہے',
  'Money changing hands': 'پیسہ ہاتھ بدل رہا ہے',
  'Nothing earned and nothing spent — the farm has as much as it had':
      'نہ کچھ کمایا نہ خرچ ہوا — فارم کے پاس اُتنا ہی ہے جتنا تھا',
  'Owed to the co-founders': 'شریکوں کا فارم پر',
  'Sold and not yet paid for': 'بیچا ہے، پیسہ ملنا باقی ہے',
  'Still to go out': 'دینا باقی',
  'Their own money, spent on the farm': 'اُن کا اپنا پیسہ جو فارم پر لگا',
  '%s goes onto what they have put in.':
      '%s اُن کے دیے ہوئے پیسوں میں شامل ہو جائے گا۔',
  '%s is more than they promised, so the farm still owes that back.':
      '%s اُن کے وعدے سے اوپر ہے، وہ فارم نے اُن کو واپس دینا ہے۔',
  'Count %s as money put in': '%s کو دیا ہوا پیسہ گنوا دیں',
  'Count it': 'گنوا دیں',
  'Count it as money they have put in?': 'اِس کو اُن کا دیا ہوا پیسہ گنوا دیں؟',
  'Counted': 'گن لیا',
  'Each gets a line of his own, dated today. What they are holding of the farm\'s cash comes back to nothing.':
      'ہر ایک کی اپنی الگ لائن بنے گی، آج کی تاریخ سے۔ فارم کا جو پیسہ اُن کے '
      'پاس تھا وہ صفر ہو جائے گا۔',
  'Money of their own that the farm has had the use of. Until somebody says so it sits here as a debt the farm owes them, because an entry says who found the money and not whose it was. Counted, it goes against what each of them is in for, and only what is over a man\'s promise stays owed to him.':
      'اُن کا اپنا پیسہ جو فارم کے کام آیا۔ جب تک کوئی نہ کہے، یہ یہاں فارم '
      'کے ذمے قرض بن کر رہتا ہے، کیونکہ اینٹری صرف اِتنا بتاتی ہے کہ پیسہ کس '
      'نے نکالا، یہ نہیں کہ کس کا تھا۔ گنوا دیں تو ہر ایک کے وعدے میں جاتا '
      'ہے، اور جو وعدے سے اوپر ہو صرف وہ اُس کا باقی رہتا ہے۔',
  '%s picked': '%s چنی گئی',
  '%s entry': '%s اینٹری',
  'Tap a shop to take everything of theirs at once, or single entries. The amount fills itself in. Leave them alone to hand over a plain figure instead.':
      'پوری دکان ایک ساتھ لینی ہو تو اُس کے نام پر دبائیں، یا الگ الگ اینٹری '
      'پر۔ رقم خود بھر جائے گی۔ چھوڑ دیں تو صرف ایک رقم لکھ کر بھی دے سکتے '
      'ہیں۔',
  '%s · already handed to %s': '%s · پہلے ہی %s کو دے دیا',
  'Handed on': 'آگے دیا گیا',
  'Still on its way — it is in nobody\'s hands until %s says he has it.':
      'ابھی راستے میں ہے — جب تک %s نہ کہے کہ مل گیا، کسی کے پاس نہیں ہے۔',
  'This money went to %s on %s.': 'یہ پیسہ %s کو %s کو گیا۔',
  'What %s paid for himself': '%s نے اپنی جیب سے کیا خرچہ',
  'What %s took in': '%s نے جو پیسہ لیا',
  'What the farm owes him, entry by entry. Nothing here is settled by this handover: his own spending goes against what he is in for until that is paid in full, and only what is over it is his to take back.':
      'فارم اُس کا جتنا دینا ہے، اینٹری کے حساب سے۔ اِس منتقلی سے یہاں کچھ '
      'واپس نہیں ہو رہا: اُس کا اپنا خرچہ پہلے اُس کے وعدے میں جاتا ہے، اور '
      'جو اُس سے اوپر ہو وہی اُس کو واپس ملتا ہے۔',
  'Hand cash over': 'پیسہ حوالے کریں',
  'Money passing between the four of them: taken at the gate by one and kept by another. The farm has exactly as much before and after, so nothing moves except who is answerable for it.':
      'آپس میں پیسہ اِدھر سے اُدھر: گیٹ پر ایک نے لیا، رکھا دوسرے نے۔ فارم کے '
      'پاس پہلے بھی اُتنا ہی تھا اور بعد میں بھی — صرف یہ بدلتا ہے کہ اب '
      'ذمہ دار کون ہے۔',
  'Nothing is earned and nothing is spent. The farm has the same money before and after — this only says whose hands it is in now.':
      'نہ کچھ کمایا نہ کچھ خرچ ہوا۔ فارم کے پاس پیسہ اُتنا ہی ہے — یہ صرف '
      'بتاتا ہے کہ اب کس کے ہاتھ میں ہے۔',
  'Handed over by': 'کس نے دیا',
  'Taken by': 'کس نے لیا',
  'How much (Rs)': 'کتنا (Rs)',
  'Who handed it over, and who took it?': 'کس نے دیا، اور کس نے لیا؟',
  'How much was handed over?': 'کتنا دیا گیا؟',
  '%s has %s in hand.': '%s کے پاس %s ہے۔',
  '%s is not holding anything the books know about. That is fine if the money has only just come in.':
      '%s کے پاس کتاب کے مطابق کچھ نہیں ہے۔ اگر پیسہ ابھی ابھی آیا ہے تو '
      'کوئی بات نہیں۔',
  '%s handed to %s': '%s، %s کو دے دیا',
  'Save the handover': 'محفوظ کریں',
  'Anything worth remembering': 'جو یاد رکھنے لائق ہو',

  // ---- The four of them funding the farm ----
  'To be returned': 'واپس دینا ہے',
  'Handed over': 'ہاتھ میں دیا',
  'Paid for something': 'کسی چیز کی ادائیگی',
  'Already recorded': 'پہلے سے درج',
  'Corrected': 'درستی',
  'In for': 'وعدہ',
  'Still to come': 'ابھی باقی',
  'Over': 'زیادہ دیا',
  'Profit kept': 'منافع رکھا',
  'Farm owes him': 'فارم نے دینا ہے',
  'He put in': 'اُس نے دیا',
  'His lines': 'اُس کی لائنیں',
  'Money in from %s': '%s کا پیسہ آیا',
  '%s in from %s': '%s، %s سے آیا',
  '%s — money in': '%s — جو پیسہ دیا',
  'He has put in %s so far.': 'اب تک %s دے چکا ہے۔',
  'He is in for %s and has put in %s.': 'وعدہ %s کا ہے اور %s دے چکا ہے۔',
  'In for %s · put in %s': 'وعدہ %s · دیا %s',
  'Put in %s': 'دیا %s',
  '%s still to come': '%s ابھی باقی',
  'The farm owes him %s': 'فارم نے اُس کو %s دینا ہے',
  'Fill in %s': '%s ڈال دیں',
  'Who took the money?': 'پیسہ کس نے لیا؟',
  'How much went in?': 'کتنا گیا؟',
  'Whoever is keeping the farm\'s cash, usually. It goes into their hands on the co-founders page.':
      'عام طور پر وہی جو فارم کا نقد رکھتا ہے۔ شریکوں والے صفحے پر اُس کے '
      'ہاتھ میں جمع ہو جاتا ہے۔',
  'This money was': 'یہ پیسہ تھا',
  'Which day': 'کس دن',
  'Save it': 'محفوظ کریں',
  'Put in: %s → %s': 'دیا: %s سے %s',
  'Put in so far: %s': 'اب تک دیا: %s',
  'Put in %s · still to come %s': 'دیا %s · باقی %s',
  'What %s is in for': '%s کا وعدہ',
  'In for (Rs)': 'وعدہ (Rs)',
  '%s is in for %s': '%s کا وعدہ %s',
  'His share would be %s%, from %s': 'اُس کا حصہ %s% ہوگا، %s پر',
  'The share is worked out from this, not from what has arrived — the four of them chose it that way so a share is settled once rather than creeping up with every instalment. Raise it and the share moves from today.':
      'حصہ اِسی سے بنتا ہے، آئے ہوئے پیسے سے نہیں — چاروں نے یہی طے کیا تھا، '
      'تاکہ حصہ ایک بار طے ہو اور ہر قسط کے ساتھ بڑھتا نہ رہے۔ بڑھائیں گے تو '
      'حصہ آج سے بدل جائے گا۔',
  'He has already put in more than that. The share follows his %s, because nobody is given a smaller share than his own money is paying for.':
      'وہ اِس سے زیادہ دے چکا ہے۔ حصہ اُس کے %s پر چلے گا، کیونکہ کسی کو اُس '
      'کے اپنے پیسے سے کم حصہ نہیں ملتا۔',
  'Nothing written down yet. Money he hands over, and his share of anything the farm buys, both appear here.':
      'ابھی کچھ درج نہیں۔ جو پیسہ وہ ہاتھ میں دے، اور فارم کی کسی بھی خریداری '
      'میں اُس کا حصہ — دونوں یہاں آتے ہیں۔',
  'What this record said before every rupee was given a line of its own. Nobody wrote it; it is what is left over.':
      'جو اِس ریکارڈ پر پہلے سے لکھا تھا، جب ہر روپے کی اپنی لائن نہیں رکھی '
      'جاتی تھی۔ یہ کسی نے لکھا نہیں — یہ بس بچا ہوا ہے۔',
  'taken by %s': '%s نے لیا',
  'The farm owes this back': 'فارم نے یہ واپس دینا ہے',
  'Count as investment': 'سرمایہ کاری میں گنیں',
  'Counted as his investment': 'اُس کی سرمایہ کاری میں گن لیا',
  'The farm owes it': 'فارم نے دینا ہے',
  'The farm owes it back now': 'اب فارم نے یہ واپس دینا ہے',
  'Take this line out?': 'یہ لائن ہٹا دیں؟',
  'Take it out': 'ہٹا دیں',
  '%s · %s\n\nIt comes off what he has put in, and off the farm\'s cash with it.':
      '%s · %s\n\nجو اُس نے دیا اُس میں سے کم ہو جائے گا، اور ساتھ ہی فارم کے '
      'نقد میں سے بھی۔',

  // ---- Who paid for one entry ----
  'Who paid for this?': 'اِس کا پیسہ کس نے دیا؟',
  'Paid for by': 'پیسہ کس نے دیا',
  'Split it between the co-founders in rupees. The entry is not touched — what each of them paid goes onto what he has put into the farm.':
      'شریکوں کے درمیان روپوں میں بانٹ دیں۔ اینٹری کو کچھ نہیں ہوتا — ہر ایک '
      'نے جو دیا وہ اُس کی سرمایہ کاری میں چلا جاتا ہے۔',
  'The farm owes back whatever is marked so.':
      'جس پر لکھا ہے، وہ فارم نے واپس دینا ہے۔',
  '%s · %s. The entry does not change and is never split — what is written here is whose money paid it.':
      '%s · %s۔ اینٹری بدلتی نہیں اور کبھی ٹوٹتی نہیں — یہاں صرف یہ لکھا '
      'جاتا ہے کہ پیسہ کس کا تھا۔',
  'No co-founders on the record yet. Add them first.':
      'ابھی کوئی شریک درج نہیں۔ پہلے اُن کو ڈالیں۔',
  'Put against it': 'اِس پر لگایا',
  'Adds up to the entry exactly.': 'اینٹری کے برابر پورا بیٹھ گیا۔',
  '%s more than the entry. Take it down before saving.':
      'اینٹری سے %s زیادہ ہے۔ محفوظ کرنے سے پہلے کم کریں۔',
  '%s of it is left — that part came out of the farm\'s own cash.':
      '%s ابھی بچا ہے — وہ حصہ فارم کے اپنے نقد سے گیا۔',
  'Share it equally': 'برابر بانٹ دیں',
  'Save who paid': 'کس نے دیا، محفوظ کریں',
  'Split saved · %s': 'تقسیم محفوظ · %s',
  'The farm would owe him %s': 'فارم نے اُس کو %s دینا ہوگا',

  // ---- What the farm's own rule does with a co-founder's money ----
  'What this does': 'اِس کا کیا ہوگا',
  '%s — %s goes onto his investment.':
      '%s — %s اُس کی سرمایہ کاری میں چلا جائے گا۔',
  '%s — his promise is already paid, so the farm owes him %s back.':
      '%s — اُس کا وعدہ پہلے ہی پورا ہے، تو فارم نے اُس کو %s واپس دینا ہے۔',
  '%s — %s finishes his promise, %s the farm owes him back.':
      '%s — %s سے اُس کا وعدہ پورا، اور %s فارم نے اُس کو واپس دینا ہے۔',
  'His promise is already paid, so the farm owes him %s of this back.':
      'اُس کا وعدہ پہلے ہی پورا ہے، تو اِس میں سے %s فارم نے اُس کو واپس دینا '
      'ہے۔',

  // ---- Cash handed over, waiting on the other man's word ----
  '%s has handed you money': '%s نے آپ کو پیسہ دیا ہے',
  '%s sent to %s — waiting on him': '%s، %s کو بھیجا — اُن کے جواب کا انتظار',
  // An arrow is drawn left to right and means nothing on its own. On a page
  // running the other way it points back at the man it came from, and the
  // line reads backwards. Said in words instead, which point the right way
  // in any direction.
  '%s → %s': '%s سے %s کو',
  'On its way': 'راستے میں',
  'Investment with no line against it': 'وہ سرمایہ کاری جس کی کوئی لائن نہیں',
  'Capital that went in without anything saying where. The farm has the money and the books balance; it is the list above that is short by this much. Write the lines and it comes down to nothing.':
      'وہ سرمایہ کاری جو اندر تو آئی مگر کہیں لکھا نہیں کہ کہاں گئی۔ پیسہ '
      'فارم کے پاس ہے اور کتاب برابر ہے؛ بس اوپر والی فہرست اِتنی ہی کم ہے۔ '
      'لائنیں لکھ دیں تو یہ صفر ہو جائے گی۔',
  'Handed over and not yet acknowledged, so it is in neither pair of hands. It joins the other man the moment he says he has it.':
      'دیا جا چکا ہے مگر ابھی تصدیق نہیں ہوئی، اس لیے یہ کسی کے بھی ہاتھ میں '
      'نہیں۔ جیسے ہی دوسرا کہے کہ مل گیا، اُس کے کھاتے میں چلا جائے گا۔',
  'Until you say so it is in nobody\'s hands — not his and not yours. Nothing has gone into the books yet.':
      'جب تک آپ نہ کہیں، یہ کسی کے ہاتھ میں نہیں — نہ اُن کے، نہ آپ کے۔ کتاب '
      'میں ابھی کچھ نہیں گیا۔',
  'I have it': 'مل گیا',
  'I did not': 'نہیں ملا',
  'Taken in': 'لے لیا',
  'Written down': 'لکھ دیا',
  'You did not get this?': 'یہ آپ کو نہیں ملا؟',
  'What happened': 'کیا ہوا',
  'Nothing goes into the books and the money stays where it was. What you write here is kept on it, and both of you can see it.':
      'کتاب میں کچھ نہیں جائے گا اور پیسہ وہیں رہے گا جہاں تھا۔ آپ جو یہاں '
      'لکھیں گے وہ اِس پر محفوظ رہے گا، اور آپ دونوں دیکھ سکیں گے۔',

  // ---- Taking back money of your own that the farm was holding ----
  'The farm owes you %s': 'فارم نے آپ کو %s دینا ہے',
  'You are holding %s of the farm\'s cash. Keep %s of it and the farm stops owing you.':
      'آپ کے پاس فارم کے %s ہیں۔ اُن میں سے %s رکھ لیں، پھر فارم کا کوئی قرض '
      'باقی نہیں رہے گا۔',
  'Keep %s': '%s رکھ لیں',
  'It stays owed. The card will be back.':
      'قرض ویسا ہی رہے گا۔ کارڈ پھر آ جائے گا۔',
  'Take it out of what you are holding?': 'جو آپ کے پاس ہے اُس میں سے لیں؟',
  '%s of the farm\'s cash in your hands becomes yours, and the farm stops owing it. Both halves are written down, and the rest of the farm can see it.':
      'آپ کے ہاتھ میں فارم کے %s آپ کے ہو جائیں گے، اور فارم کا قرض ختم۔ '
      'دونوں طرف لکھا جاتا ہے، اور باقی سب دیکھ سکتے ہیں۔',
  'Take it': 'لے لیں',
  '%s taken back': '%s واپس لے لیا',
  'Taken back lately': 'حال میں واپس لیا گیا',
  '%s took back %s': '%s نے %s واپس لیا',
  'Money of their own the farm was holding, taken out of farm cash already in their hands. Every one is in the activity log as well.':
      'اُن کا اپنا پیسہ جو فارم کے پاس تھا، اُن کے اپنے ہاتھ میں موجود فارم '
      'کے نقد میں سے لیا گیا۔ ہر ایک کام کے ریکارڈ میں بھی ہے۔',

  // ---- The receipt that came with the money ----
  'Receipt': 'رسید',
  'Tap to open it full size.': 'پوری دیکھنے کے لیے دبائیں۔',

  // ---- The strip of accounts, and one account opened out ----
  '%s (you)': '%s (آپ)',
  'In the farm\'s own keeping': 'فارم کے اپنے پاس',
  'Farm\'s cash on him': 'فارم کا پیسہ اُن کے پاس',
  'Out of his own pocket': 'اُن کی اپنی جیب سے',
  'His own, in the farm': 'فارم میں اُن کا اپنا',
  '%s in · %s out': '%s آیا · %s گیا',
  '%s promised': '%s کا وعدہ',
  'Nothing has gone through it yet': 'ابھی اِس میں سے کچھ نہیں گزرا',
  'What has gone through it': 'اِس میں سے کیا گزرا',
  '%s after': 'بعد میں %s',
  '%s on its way out, waiting on the other man':
      '%s راستے میں ہے، دوسرے کے جواب کا انتظار',
  '%s sent to him and not yet acknowledged':
      '%s اُن کو بھیجا گیا، ابھی تصدیق نہیں ہوئی',
  'Nothing has gone through this account yet. Every entry with this name against it appears here.':
      'اِس کھاتے میں سے ابھی کچھ نہیں گزرا۔ ہر وہ اینٹری جس پر یہ نام لکھا '
      'ہو، یہاں آتی ہے۔',

  // ---- The two charts on the dashboard ----
  'Month by month': 'مہینہ بہ مہینہ',
  'No period has been settled yet.': 'ابھی کوئی مہینہ بند نہیں ہوا۔',
  'so far': 'اب تک',
  'Made %s this period so far.': 'اِس مدت میں اب تک %s بنایا۔',
  'Settled periods are drawn from the figures frozen into them. The last column is the period still running, so it is faint — half a month against six whole ones proves nothing.':
      'بند مہینے اُن کے اپنے جمے ہوئے ہندسوں سے بنتے ہیں۔ آخری کھمبا چلتا ہوا '
      'مہینہ ہے، اس لیے ہلکا ہے — آدھا مہینہ چھ پورے مہینوں کے سامنے کچھ '
      'ثابت نہیں کرتا۔',
  'What the farm is worth': 'فارم کی کل مالیت',
  'Cash — in the box and in their hands': 'نقد — بکس میں اور ہاتھوں میں',
  'Still to come in': 'جو ابھی آنا ہے',
  'Cattle & equipment': 'مال مویشی اور مشینری',
  'Owed out — bills, securities, co-founders':
      'جو دینا ہے — بل، سیکیورٹی، شریک',

  // ---- Which day an entry is for, and who may move it ----
  'Any day up to today, back or forward. Where it ends up is kept on the entry with the day it came from.':
      'آج تک کوئی بھی دن، آگے یا پیچھے۔ جہاں جائے وہ اور جہاں سے آئی تھی، '
      'دونوں اینٹری پر محفوظ رہتے ہیں۔',
  'Anywhere inside this period — %s to today, back or forward. Both days are kept on the entry.':
      'اِسی مدت کے اندر کہیں بھی — %s سے آج تک، آگے یا پیچھے۔ دونوں تاریخیں '
      'اینٹری پر محفوظ رہتی ہیں۔',
  'Written in later, on %s. Every figure reads the day above — this is only the day somebody typed it.':
      'بعد میں لکھی گئی، %s کو۔ ہر حساب اوپر والے دن سے چلتا ہے — یہ صرف وہ '
      'دن ہے جب کسی نے لکھی۔',
  'For this day · written %s': 'اِسی دن کی · لکھی %s',

  // ---- The two lists that carry one row per rupee ----
  'Money received': 'جو پیسہ ملا',
  'Money paid out': 'جو پیسہ دیا',
  'Money against an entry written earlier': 'پہلی لکھی اینٹری کا پیسہ',
  'balance owed': 'بقایا',
  'balance to pay': 'دینا باقی',

  // ---- Security deposits ----
  'Security the farm is holding': 'سیکیورٹی جو فارم کے پاس رکھی ہے',
  'Security held': 'سیکیورٹی رکھی ہوئی',
  'Security paid out': 'سیکیورٹی جو دی ہوئی ہے',
  'Qty': 'مقدار',
  'Rate / unit': 'ریٹ فی یونٹ',
  'Total amount (Rs)': 'کل رقم (Rs)',
  'What for': 'کس چیز کا',
  'Add the total amount.': 'کل رقم ڈالیں۔',
  'Who is this entry for? Add a party name.':
      'یہ اینٹری کس کے لیے ہے؟ نام ڈالیں۔',

  // ---- One entry opened out in full ----
  'Settled': 'پیسہ آیا یا نہیں',
  'Yes, in full': 'ہاں، پورا',
  '%s so far': 'اب تک %s',
  'Still to receive': 'ابھی لینا ہے',
  'How': 'کس طرح',
  'Received by': 'کس نے لیا',
  'Paid by': 'کس نے دیا',
  'Money moved on': 'پیسہ ہلا',
  'Written on': 'لکھا گیا',
  'Someone': 'کوئی',
  'Quantity': 'مقدار',
  'Note': 'نوٹ',
  'Security taken': 'سیکیورٹی ملی (گاہک سے)',
  'Security given back': 'گاہک کی سیکیورٹی واپس کی',
  'Security paid': 'سیکیورٹی دی (کرائے والی)',
  'Security got back': 'اپنی سیکیورٹی واپس ملی',
  'Advance': 'ایڈوانس',
  'Advance returned': 'ایڈوانس واپس کیا',
  'Advance paid': 'ایڈوانس دیا',
  'Advance recovered': 'ایڈوانس وصول',
  'Security we are holding': 'سیکیورٹی جو ہمارے پاس ہے',
  'Security we have with them': 'سیکیورٹی جو اُن کے پاس ہے',
  'entries': 'اینٹریاں',
  'One person’s account, and only theirs — nothing the farm did with anybody else is on it. What they took puts the balance up whether it is paid for or not; money they hand over brings it down. What the farm bought from them runs the other way, and when the balance ends up on that side the foot of the page says so.':
      'ایک بندے کا کھاتہ، صرف اُسی کا — فارم نے کسی اور کے ساتھ جو کیا وہ اِس '
      'میں نہیں آتا۔ جو اُنہوں نے لیا وہ بقایا بڑھاتا ہے، پیسہ آیا ہو یا '
      'نہیں؛ جو پیسہ وہ دیں وہ بقایا گھٹاتا ہے۔ جو فارم نے اُن سے خریدا وہ '
      'اُلٹا چلتا ہے، اور جب بقایا اُس طرف نکلے تو نیچے لکھا آتا ہے۔',
  'The farm’s cash book. Only what actually moved money is in it, so it opens '
          'at what the co-founders put in and closes at what is in the box today.':
      'فارم کا روزچہ۔ صرف وہ چیزیں جن میں پیسہ اصل میں ہلا، اس لیے یہ سرمایے '
      'سے شروع ہوتا ہے اور آج کے نقد پر ختم۔',

  // ---- The two halves of the ledger ----
  'Still open': 'ابھی باقی ہیں',
  'Done with': 'ہو چکی ہیں',
  'Everything here': 'یہاں کی سب اینٹریاں',

  // ---- Part payments, and the name off the books ----
  '%s in, %s still to come': '%s ملا، %s ابھی باقی',
  'part paid': 'تھوڑا ملا',
  'ticked': 'نشان',
  'milk': 'دودھ',
  'owed': 'باقی',
  'How much is being handed over': 'کتنا پیسہ مل رہا ہے',
  'Leave it empty for all of it — %s': 'پورا لینا ہو تو خالی چھوڑ دیں — %s',
  'Take in %s': '%s وصول کریں',
  'Taking it in…': 'وصول ہو رہا ہے…',
  'to pay': 'دینا ہے',
  'How much is being paid': 'کتنا پیسہ دیا جا رہا ہے',
  'Pay %s': '%s ادا کریں',
  'Paying…': 'ادا ہو رہا ہے…',
  '%s will still be owing to them. The oldest bills are paid first; whatever '
          'is left over stops part way through one, and that is the one the next '
          'payment finishes.':
      '%s ابھی اُن کا باقی رہے گا۔ سب سے پرانے بل پہلے ادا ہوں گے؛ جو بچے گا '
      'وہ آخری والے پر ادھورا رہ جائے گا، اور اگلی بار وہی پورا ہوگا۔',
  '%s settled, %s still owed': '%s کا حساب ہوا، %s ابھی باقی',
  'Could not take it in. %s': 'وصول نہیں ہو سکا۔ %s',
  '%s will still be owed. The oldest entries are settled first; whatever is '
          'left over stops part way through one, and that is the one the next '
          'payment fills.':
      '%s ابھی باقی رہے گا۔ سب سے پرانی اینٹریاں پہلے پوری ہوں گی؛ جو بچے گا '
      'وہ آخری والی پر ادھورا رہ جائے گا، اور اگلی بار وہی پہلے بھرے گی۔',
  'New name — "%s"': 'نیا نام — "%s"',
  'Not written down before': 'پہلے کبھی نہیں لکھا گیا',
  '%s owed': '%s باقی',
  'Change': 'بدلیں',

  // ---- Settling a week of credit in one go ----
  '%s not settled yet': '%s ابھی باقی ہیں',
  'Settle several': 'ایک ساتھ حساب',
  'Tick what they are paying for': 'جس کا پیسہ دے رہے ہیں، نشان لگائیں',
  '%s ticked': '%s پر نشان',
  'All of them': 'سب پر',
  'Clear': 'نشان ہٹائیں',
  'Mark %s paid': '%s کو ادا شدہ کریں',
  'Settling…': 'حساب ہو رہا ہے…',
  '%s settled · %s': '%s کا حساب ہو گیا · %s',
  '%s of %s went through': '%s میں سے %s ہو گئے',
  'Money coming in and money going out have to be settled apart.':
      'جو پیسہ آ رہا ہے اور جو جا رہا ہے، دونوں کا حساب الگ کرنا ہوگا۔',
  'Asked once how the money came, then each entry is settled on its own — so '
          'a part payment marks only what it covers.':
      'پیسہ کیسے آیا، یہ ایک ہی بار پوچھا جائے گا، پھر ہر اینٹری اپنی جگہ '
      'پوری ہوگی — اس لیے تھوڑا پیسہ دیں تو صرف اُتنی ہی اینٹریوں پر نشان '
      'لگے گا۔',

  // ---- Looking up one name or one kind of entry ----
  'Anyone': 'کوئی بھی',
  'Anything': 'کچھ بھی',
  'Everybody': 'سب لوگ',
  'Whose entries?': 'کس کی اینٹریاں؟',
  'Which kind of entry?': 'کس قسم کی اینٹری؟',
  'Nothing by that name.': 'اِس نام سے کچھ نہیں ملا۔',
  'Sold to them, all time': 'اُن کو بیچا، شروع سے اب تک',
  'Bought from them, all time': 'اُن سے خریدا، شروع سے اب تک',
  'They still owe': 'اُن کے ذمے باقی ہے',
  'The farm still owes them': 'فارم کے ذمے باقی ہے',
  'Nothing outstanding either way.': 'دونوں طرف کچھ باقی نہیں۔',
  'Paid out to co-founders': 'شریکوں کو دیا',
  'Other money in': 'دوسری آمدنی',
  'receipts with no sale booked against them':
      'جو پیسہ آیا لیکن اُس کی کوئی فروخت نہیں لگی',
  'Every rupee is accounted for.': 'ہر روپے کا حساب پورا ہے۔',
  '%s is not accounted for. An entry is probably missing, or one has been '
          'typed twice.':
      '%s کا حساب پورا نہیں۔ یا تو کوئی اینٹری رہ گئی ہے، یا کوئی دو بار لگ '
      'گئی ہے۔',
  'Who did what': 'کس نے کیا کیا',
  'Cattle & equipment owned': 'مویشی اور سامان جو فارم کا ہے',
  'money that turned into animals, not money spent':
      'پیسہ جو جانور بن گیا، خرچ نہیں ہوا',
  'their share of the profit': 'اُن کا منافع کا حصہ',
  '%s rolled from last time is back in this figure — it was held back then, '
          'so it is shared now.':
      'پچھلی بار کا %s اِس میں واپس شامل ہے — اُس وقت روک لیا تھا، اب بانٹا '
      'جا رہا ہے۔',
  'Received %s': '%s کو ملا',
  'Paid %s': '%s کو دیا',
  "Count as this period's income (share on paper)":
      'اِس مدت کی آمدنی گنیں (کاغذ پر بانٹیں)',
  'Roll into the next period (share cash only)':
      'اگلی مدت میں لے جائیں (صرف نقد بانٹیں)',
  "Each co-founder's share": 'ہر شریک کا حصہ',
  '%s of cattle & equipment was bought. It is not a cost — the farm owns it — so it is not taken off the profit.':
      '%s کے مویشی اور سامان خریدے گئے۔ یہ خرچہ نہیں — فارم کا اپنا مال ہے — '
      'اس لیے منافع سے نہیں کاٹا گیا۔',
  'Settling in the middle of the month': 'مہینے کے بیچ میں حساب',
  'Khaata carries on exactly as it is — customers are billed at the end of their month, not now, and nobody gets an extra bill because of this.':
      'کھاتہ بالکل ویسا ہی چلے گا — گاہکوں کو اُن کے مہینے کے آخر میں بل جائے '
      'گا، ابھی نہیں، اور اِس وجہ سے کسی کو اضافی بل نہیں ملے گا۔',
  'Khaata milk counts as income the day the customer pays for it, so this period holds what has been collected. The rest arrives in the period it is collected in. Nothing is lost; it moves along.':
      'کھاتے کا دودھ اُس دن آمدنی بنتا ہے جس دن گاہک پیسہ دیتا ہے، اس لیے اِس '
      'مدت میں وہی ہے جو وصول ہو چکا۔ باقی اُس مدت میں آئے گا جس میں وصول '
      'ہوگا۔ کچھ گم نہیں ہوتا، آگے کھسک جاتا ہے۔',
  'The figures freeze the moment you send it. Everything sold or spent after this belongs to the next period, whatever the date says — so a co-founder answering in two days sees exactly what you are looking at now.':
      'بھیجتے ہی ہندسے جم جاتے ہیں۔ اُس کے بعد جو بھی بکا یا خرچ ہوا وہ اگلی '
      'مدت کا ہے، تاریخ چاہے کچھ بھی کہے — اس لیے دو دن بعد جواب دینے والے '
      'شریک کو بالکل وہی نظر آئے گا جو ابھی آپ کو۔',
  '%s goes out to %s co-founders to decide on.\n\nFrom this moment the figures cannot change, and every new entry — even one dated today — belongs to the next period.':
      '%s، %s شریکوں کے فیصلے کے لیے جا رہا ہے۔\n\nاِس لمحے کے بعد ہندسے نہیں '
      'بدل سکتے، اور ہر نئی اینٹری — چاہے آج کی تاریخ کی ہو — اگلی مدت کی '
      'ہے۔',
  'There is nothing to share, so there is nothing to send. Settle once the period has made a profit.':
      'بانٹنے کو کچھ نہیں، اس لیے بھیجنے کو بھی کچھ نہیں۔ مدت منافع دے لے، '
      'پھر حساب کریں۔',
  'This period is at a loss of %s, so there is nothing to share out. Check that every sale is entered — a big one-off buy like cattle will show as a loss in the period you pay for it.':
      'اِس مدت میں %s کا گھاٹا ہے، اس لیے بانٹنے کو کچھ نہیں۔ دیکھ لیں کہ ہر '
      'فروخت لکھی گئی ہے — مویشی جیسی بڑی خرید اُس مدت میں گھاٹا دکھاتی ہے '
      'جس میں پیسہ دیا جاتا ہے۔',
  'End this period': 'یہ مدت ختم کریں',
  'End it': 'ختم کریں',
  'Settling before the month ends': 'مہینہ ختم ہونے سے پہلے حساب',
  'You can settle up on any day you like — the period simply ends here and the next one starts. Khaata is not touched: customers are still billed at the end of their own month, and nobody gets an extra bill because of this.':
      'آپ جس دن چاہیں حساب کر سکتے ہیں — مدت یہاں ختم اور اگلی شروع۔ کھاتے کو '
      'اِس سے کچھ نہیں: گاہکوں کو اُن کے اپنے مہینے کے آخر میں ہی بل جائے گا، '
      'اور اِس وجہ سے کسی کو اضافی بل نہیں ملے گا۔',
  'Nothing to share this time. The period still ends here and the next one opens.':
      'اِس دفعہ بانٹنے کو کچھ نہیں۔ مدت پھر بھی یہاں ختم ہوگی اور اگلی کھل '
      'جائے گی۔',
  'This period is %s down, so there is nothing to share out — and nothing '
          'comes off anybody\'s capital either. The shortfall is already in the '
          'cash the next period starts with.\n\nBefore you end it, check every '
          'sale is entered. A big one-off buy like cattle shows as a loss in '
          'the period you pay for it, even though the farm still has the '
          'animal.':
      'اِس مدت میں %s کا گھاٹا ہے، اس لیے بانٹنے کو کچھ نہیں — اور کسی کے '
      'سرمائے سے بھی کچھ نہیں کٹا۔ یہ کمی پہلے ہی اُس نقد میں شامل ہے جس سے '
      'اگلی مدت شروع ہوگی۔\n\nختم کرنے سے پہلے دیکھ لیں کہ ہر فروخت لکھی گئی '
      'ہے۔ مویشی جیسی بڑی خرید اُس مدت میں گھاٹا دکھاتی ہے جس میں پیسہ دیا '
      'جاتا ہے، چاہے جانور فارم ہی کے پاس ہو۔',
  'There is nothing to share, so nobody is asked to decide.\n\nFrom this '
          'moment the figures cannot change, and every new entry — even one '
          'dated today — belongs to the next period.':
      'بانٹنے کو کچھ نہیں، اس لیے کسی سے فیصلہ نہیں پوچھا جائے گا۔\n\nاِس '
      'لمحے کے بعد ہندسے نہیں بدل سکتے، اور ہر نئی اینٹری — چاہے آج کی تاریخ '
      'کی ہو — اگلی مدت کی ہے۔',
  'Nothing to hand out': 'بانٹنے کو کچھ نہیں',
  'Nothing to share': 'کچھ نہیں بانٹنا',
  'This period made no profit, so nobody is being asked to decide anything. Close it and the next period carries on from here.':
      'اِس مدت میں منافع نہیں ہوا، اس لیے کسی سے کچھ نہیں پوچھا جا رہا۔ بند '
      'کر دیں، اگلی مدت یہاں سے چلتی رہے گی۔',
  'Nothing is paid out. The period is finished and filed.':
      'کوئی ادائیگی نہیں ہوگی۔ مدت ختم ہو کر ریکارڈ میں چلی جائے گی۔',

  // ---- The decisions ----
  '%s — decisions': '%s — فیصلے',
  'All in': 'سب آ گئے',
  '%s waiting': '%s کا انتظار',
  'Frozen %s. It will not change.': '%s کو جم گیا۔ اب نہیں بدلے گا۔',
  'Frozen %s. This figure will not change.':
      '%s کو جم گیا۔ یہ ہندسہ نہیں بدلے گا۔',
  'Taking out': 'نکال رہے ہیں',
  'Back into the farm': 'واپس فارم میں',
  'What each of them wants': 'ہر ایک کیا چاہتا ہے',
  'Share': 'حصہ',
  'Into investment': 'سرمایہ کاری میں',
  'Decided': 'فیصلہ ہو گیا',
  'Waiting on you': 'آپ کا انتظار',
  'Decide': 'فیصلہ کریں',
  'Enter after ringing them': 'فون کر کے یہاں لکھیں',
  'Confirmed by phone and entered by the master.':
      'فون پر تصدیق ہوئی، ماسٹر نے لکھا۔',
  'Approve all & close the period': 'سب منظور کریں اور مدت بند کریں',
  'Every share is posted, the withdrawals are entered as payments, and the investments go up. This cannot be undone.':
      'ہر حصہ لگ جائے گا، نکالی ہوئی رقم ادائیگی کے طور پر لکھی جائے گی، اور '
      'سرمایہ کاری بڑھ جائے گی۔ یہ واپس نہیں ہوگا۔',
  'Waiting on %s. The decision is theirs — ring them, and if they tell you what they want, enter it on their row. It will be recorded as confirmed by phone.':
      '%s کا انتظار ہے۔ فیصلہ اُن کا اپنا ہے — فون کریں، اور جو وہ کہیں وہ '
      'اُن کی لائن میں لکھ دیں۔ لکھا جائے گا کہ فون پر تصدیق ہوئی۔',
  'Close %s?': '%s بند کریں؟',
  '%s goes out to the co-founders and %s stays in the farm as investment.\n\nThis cannot be undone from the app.':
      '%s شریکوں کو جائے گا اور %s سرمایہ کاری بن کر فارم میں رہے گا۔\n\nایپ '
      'سے یہ واپس نہیں ہوگا۔',
  'Close the period': 'مدت بند کریں',
  '%s closed.': '%s بند ہو گیا۔',
  'Could not close it. %s': 'بند نہیں کر سکے۔ %s',
  'Reopen this period': 'یہ مدت دوبارہ کھولیں',
  'Reopen it?': 'دوبارہ کھولیں؟',
  'Reopen': 'کھولیں',
  'The figures go back to being worked out and every decision so far is cleared. The co-founders will have to choose again.':
      'ہندسے دوبارہ بنتے ہیں اور اب تک کے سب فیصلے مٹ جاتے ہیں۔ شریکوں کو '
      'دوبارہ چننا ہوگا۔',
  'Puts the figures back to being worked out, and clears every decision. Only for a period sealed by mistake — nothing has been paid yet at this stage.':
      'ہندسے دوبارہ بننے لگتے ہیں اور ہر فیصلہ مٹ جاتا ہے۔ صرف اُس مدت کے لیے '
      'جو غلطی سے جم گئی ہو — اِس مرحلے تک کوئی ادائیگی نہیں ہوئی ہوتی۔',
  'Could not reopen it. %s': 'دوبارہ نہیں کھول سکے۔ %s',

  // ---- A co-founder's own share ----
  '%s share': '%s کا حصہ',
  '%s is settled': '%s کا حساب ہو گیا',
  'Your share. Say how much of it you want to take out — the rest is added to your investment. Nothing moves until every co-founder has answered.':
      'آپ کا حصہ۔ بتائیں کتنا نکالنا ہے — باقی آپ کی سرمایہ کاری میں جمع ہو '
      'جائے گا۔ جب تک ہر شریک جواب نہ دے، کچھ نہیں ہوگا۔',
  'Tap to change it until the master closes the period.':
      'ماسٹر کے مدت بند کرنے تک دبا کر بدل سکتے ہیں۔',
  'Entered by the master after speaking to you. Tap to change it while the period is still open.':
      'ماسٹر نے آپ سے بات کر کے لکھا۔ مدت کھلی ہے، دبا کر بدل سکتے ہیں۔',
  'You take out': 'آپ نکال رہے ہیں',
  'Stays as investment': 'سرمایہ کاری میں رہے گا',
  'How much do you want to take out?': 'کتنا نکالنا چاہتے ہیں؟',
  'Take nothing': 'کچھ نہیں',
  'Take all of it': 'پورا نکال لیں',
  'Your share is only %s — you cannot take more than that.':
      'آپ کا حصہ صرف %s ہے — اِس سے زیادہ نہیں نکال سکتے۔',
  'Taking the whole share. Nothing goes to investment.':
      'پورا حصہ نکال رہے ہیں۔ سرمایہ کاری میں کچھ نہیں جائے گا۔',
  '%s is added to your investment, so your share of the next period goes up.':
      '%s آپ کی سرمایہ کاری میں جمع ہوگا، اس لیے اگلی مدت میں آپ کا حصہ بڑھ '
      'جائے گا۔',
  'Entering this for someone else': 'یہ کسی اور کے لیے لکھ رہے ہیں',
  'Only do this after speaking to %s. It will be saved as confirmed by phone, with your name on it, and they will be told what was entered.':
      'یہ صرف %s سے بات کرنے کے بعد کریں۔ یہ فون پر تصدیق شدہ لکھا جائے گا، '
      'آپ کے نام کے ساتھ، اور اُنہیں بتا دیا جائے گا کہ کیا لکھا گیا۔',
  'Save what they told you': 'جو اُنہوں نے کہا وہ محفوظ کریں',
  'Confirm my decision': 'میرا فیصلہ پکا کریں',
  'Save for %s?': '%s کے لیے محفوظ کریں؟',
  'Confirm?': 'پکا؟',
  '%s out, %s into investment.': '%s باہر، %s سرمایہ کاری میں۔',
  'Saved': 'محفوظ ہو گیا',
  'Saved.': 'محفوظ ہو گیا۔',
  'Could not save it. %s': 'محفوظ نہیں ہو سکا۔ %s',
  'You can change this until the master closes the period. After that it is final.':
      'ماسٹر کے مدت بند کرنے تک بدل سکتے ہیں۔ اُس کے بعد آخری ہے۔',
  'There is nothing to decide right now. The master will send the figures when the period is settled.':
      'ابھی فیصلہ کرنے کو کچھ نہیں۔ مدت کا حساب ہوتے ہی ماسٹر ہندسے بھیج دے '
      'گا۔',

  // ---- What the farm runs ----
  'What the farm runs': 'فارم میں کیا کیا چل رہا ہے',
  'Selling': 'فروخت',
  'Online orders': 'آن لائن آرڈر',
  'Shop, cart, and orders going out to doors':
      'دکان، ٹوکری، اور دروازوں تک جانے والے آرڈر',
  'Daily milk on account, billed once a month':
      'روزانہ کھاتے پر دودھ، مہینے میں ایک بل',
  'Out on the round': 'راؤنڈ پر',
  "The rider's work": 'رائیڈر کا کام',
  'Round, spot sale, handover, collection':
      'راؤنڈ، ہاتھوں ہاتھ فروخت، حوالگی، وصولی',
  'Online orders and khaata are both off, so there is nothing for a rider to take out. Switch one of them on and this comes back by itself.':
      'آن لائن آرڈر اور کھاتہ دونوں بند ہیں، اس لیے رائیڈر کے لے جانے کو کچھ '
      'نہیں۔ کوئی ایک چالو کریں، یہ خود واپس آ جائے گا۔',
  'Animals, tags, milk yield, vet visits': 'جانور، ٹیگ، دودھ، ڈاکٹر کے چکر',
  'Books': 'حساب کتاب',
  'Entries, accounts, reports, closing a period':
      'اینٹری، حساب، رپورٹ، مدت بند کرنا',
  'The books always run. Everything else can be switched off; the farm still has to know what it has.':
      'حساب ہمیشہ چلتا ہے۔ باقی سب بند ہو سکتا ہے؛ فارم کو پھر بھی پتہ ہونا '
      'چاہیے اُس کے پاس کیا ہے۔',
  'What switching off does': 'بند کرنے سے کیا ہوتا ہے',
  'The tab disappears from every phone on the farm and the notifications stop. Nothing is deleted — every khaata, order and bill stays exactly where it is, and comes back untouched when you switch it on again.':
      'وہ ٹیب فارم کے ہر فون سے غائب ہو جاتا ہے اور اُس کی اطلاع بند ہو جاتی '
      'ہے۔ کچھ مٹتا نہیں — ہر کھاتہ، آرڈر اور بل جہاں ہے وہیں رہتا ہے، اور '
      'دوبارہ چالو کرنے پر جیسا تھا ویسا ہی آ جاتا ہے۔',
  'Only you can see this screen. Co-founders, riders and customers have no such setting.':
      'یہ صفحہ صرف آپ دیکھ سکتے ہیں۔ شریکوں، رائیڈر اور گاہکوں کے پاس ایسی '
      'کوئی سیٹنگ ہے ہی نہیں۔',
  'Switch the round off too?': 'راؤنڈ بھی بند کر دیں؟',
  'With neither online orders nor khaata running there is nothing for the rider to take out, so the round, spot sales, the handover and the collection screens all go with it.\n\nNothing is deleted. It all comes back when you switch a delivery channel on again.':
      'نہ آن لائن آرڈر چل رہے ہیں نہ کھاتہ، تو رائیڈر کے لے جانے کو کچھ نہیں۔ '
      'اس لیے راؤنڈ، ہاتھوں ہاتھ فروخت، حوالگی اور وصولی — سب ساتھ جائیں '
      'گے۔\n\nکچھ مٹتا نہیں۔ کوئی ایک چالو کرتے ہی سب واپس آ جائے گا۔',
  'Switch off': 'بند کریں',
  'Could not save that. %s': 'یہ محفوظ نہیں ہو سکا۔ %s',

  // ---- Language and account ----
  'The whole app reads in this language — bills, alerts and reports too. It is yours alone; nobody else on the farm changes with it.':
      'پوری ایپ اِسی زبان میں پڑھی جائے گی — بل، اطلاع اور رپورٹ بھی۔ یہ صرف '
      'آپ کی ہے؛ فارم پر کسی اور کا کچھ نہیں بدلتا۔',

  // ---- The round ----
  '%s khaata houses done': '%s کھاتہ گھر ہو گئے',
  '%s still to collect from orders': 'آرڈر سے %s ابھی وصول کرنا ہے',
  'This round is done.': 'یہ راؤنڈ پورا ہو گیا۔',
  '%s still to go on the %s round.': '%s راؤنڈ میں %s ابھی باقی ہیں۔',
  'morning': 'صبح والے',
  'evening': 'شام والے',
  'Show all': 'سب دکھائیں',
  'Only left (%s)': 'صرف باقی (%s)',
  '%s orders are waiting for a co-founder to approve. They appear here as soon as that happens.':
      '%s آرڈر کسی شریک کی منظوری کا انتظار کر رہے ہیں۔ منظوری ملتے ہی یہاں '
      'آ جائیں گے۔',
  '%s orders are waiting for a co-founder to approve. They reach the round after that.':
      '%s آرڈر کسی شریک کی منظوری کا انتظار کر رہے ہیں۔ اُس کے بعد راؤنڈ پر '
      'آئیں گے۔',
  '%s orders are for later days.': '%s آرڈر آگے کے دنوں کے ہیں۔',
  'Nothing on this round. Khaata customers appear here every day once a co-founder approves them, and shop orders appear on the days the customer asked for.':
      'اِس راؤنڈ پر کچھ نہیں۔ کھاتہ گاہک شریک کی منظوری کے بعد روز یہاں آتے '
      'ہیں، اور دکان کے آرڈر اُن دنوں آتے ہیں جو گاہک نے چنے تھے۔',
  'What is coming. Milk is marked delivered on the round, where the day and the money are.':
      'کیا کیا آ رہا ہے۔ دودھ راؤنڈ پر پہنچا دیا لکھا جاتا ہے، جہاں دن اور '
      'پیسہ دونوں ہیں۔',
  'Undo this delivery?': 'یہ ڈلیوری واپس کریں؟',
  '%s comes back out of the books, and the day goes back on the round. The entry stays in the log marked deleted.':
      '%s حساب سے واپس نکل جائے گا اور وہ دن دوبارہ راؤنڈ پر آ جائے گا۔ اینٹری '
      'ریکارڈ میں مٹائی ہوئی لکھی رہے گی۔',
  'Undo it': 'واپس کریں',
  'Undone': 'واپس ہو گیا',
  'Could not undo it. %s': 'واپس نہیں کر سکے۔ %s',
  '#%s delivered': '#%s پہنچ گیا',
  'Ready': 'تیار',
  'Nothing to collect': 'کچھ وصول نہیں کرنا',
  'Collect %s': '%s وصول کریں',
  'Goes on their khaata — billed at month end':
      'اُن کے کھاتے میں جائے گا — مہینے کے آخر میں بل',
  'On their khaata.': 'اُن کے کھاتے میں۔',
  '%s taken.': '%s لے لیا۔',
  'The rider marks this delivered.': 'یہ رائیڈر پہنچا دیا لکھے گا۔',
  'Not yet': 'ابھی نہیں',
  'No rate set': 'ریٹ نہیں لگا',
  'usually %s L': 'عام طور پر %s L',
  'nothing to collect, billed at month end':
      'کچھ وصول نہیں کرنا، بل مہینے کے آخر میں',
  'Set a rate in Khaata sign-ups before delivering, or this milk is billed at nothing.':
      'ڈلیوری سے پہلے نئے کھاتے میں ریٹ لگا دیں، ورنہ یہ دودھ صفر پر بل ہوگا۔',
  'Set a rate for %s first, in Khaata sign-ups.':
      'پہلے %s کا ریٹ لگائیں، نئے کھاتے میں۔',
  'How many litres?': 'کتنے لیٹر؟',
  '%s cleared': '%s کا دن صاف کر دیا',
  'bill raised': 'بل بن گیا',
  'Update': 'بدلیں',
  'by %s': '%s نے',

  // ---- Customer ----
  'The farm is not taking orders yet': 'فارم ابھی آرڈر نہیں لے رہا',
  'Char Yar Dairy Farm has not opened online ordering or monthly khaata accounts yet. You will be able to order here as soon as it does.':
      'چار یار ڈیری فارم نے ابھی نہ آن لائن آرڈر شروع کیا ہے نہ ماہوار کھاتہ۔ '
      'جیسے ہی شروع ہوگا، آپ یہیں سے آرڈر کر سکیں گے۔',
  'Cancel order #%s?': 'آرڈر #%s منسوخ کریں؟',
  'The farm will not prepare it.': 'فارم اِسے تیار نہیں کرے گا۔',
  'Cancel it': 'منسوخ کریں',
  'Order #%s cancelled': 'آرڈر #%s منسوخ ہو گیا',
  'Could not cancel it. %s': 'منسوخ نہیں کر سکے۔ %s',
  'No orders yet. Your first one will show up here.':
      'ابھی کوئی آرڈر نہیں۔ پہلا آرڈر یہیں نظر آئے گا۔',
  'Nothing on its way right now.': 'ابھی راستے میں کچھ نہیں۔',
  'Nothing delivered yet.': 'ابھی کچھ پہنچا نہیں۔',

  // ---- Rider ----
  'No round today': 'آج کوئی راؤنڈ نہیں',
  'The farm has deliveries switched off at the moment, so there is nothing to take out. This screen will fill up again as soon as the master switches them back on.':
      'فارم نے فی الحال ڈلیوری بند کی ہوئی ہے، اس لیے لے جانے کو کچھ نہیں۔ '
      'ماسٹر کے دوبارہ چالو کرتے ہی یہ صفحہ پھر بھر جائے گا۔',
  'Particulars': 'تفصیل',
  'Showing': 'دکھا رہا ہے',
  'Show everything, paid or not': 'سب کچھ دکھائیں، ادا ہو یا نہ ہو',
  'Feed bought on credit, a buffalo that died, milk still owed for. The running total stops being the cash in the box and becomes the total of what is on the page.':
      'اُدھار پر لیا ہوا ونڈا، مری ہوئی بھینس، وہ دودھ جس کا پیسہ ابھی آنا '
      'ہے۔ نیچے کا ہندسہ پھر تجوری کا نقد نہیں رہتا — وہ اُس سب کا جوڑ بن '
      'جاتا ہے جو اِس صفحے پر ہے۔',
  'Every entry, paid or not': 'ہر اینٹری، ادا ہو یا نہ ہو',
  'Extract': 'خلاصہ',
  'Total shown': 'جو دکھایا گیا، اُس کا کل',
  '%s still to decide': '%s کا فیصلہ باقی ہے',

  // ---- What the co-founders have in ----
  'Put in from their pockets': 'اپنی جیب سے لگایا',
  'Profit left in the farm': 'منافع جو فارم میں چھوڑا',
  'Total investment': 'کل سرمایہ کاری',
  'Capital account': 'حصہ داری کا کھاتہ',
  'Their stake in the farm': 'فارم میں اُن کا حصہ',
  'Every period settled so far': 'اب تک کی تمام بند شدہ مدتیں',

  // ---- Writing a category out ----
  'Something else — write it out': 'کوئی اور چیز — خود لکھیں',
  'What is it for?': 'یہ کس چیز کے لیے ہے؟',
  'It will be filed under %s.': 'یہ %s میں درج ہوگی۔',
  'Write it out': 'خود لکھیں',
  'Tubewell repair, trolley, mazdoori…': 'ٹیوب ویل مرمت، ٹرالی، مزدوری…',
  'already there': 'پہلے سے موجود',
  'Use this': 'یہی رکھیں',
  '"%s" is already being used': '"%s" پہلے سے استعمال ہو رہا ہے',
  'It is already in use under %s. If that is where this belongs, go back and write it there — the summary keeps one word in one place. Make it here as well only if it is genuinely a different thing.':
      'یہ پہلے سے %s کے نیچے استعمال ہو رہا ہے۔ اگر اِس کا اصل مقام وہی ہے تو '
      'واپس جا کر وہاں لکھیں — خلاصہ ایک لفظ کو ایک ہی جگہ رکھتا ہے۔ یہاں بھی '
      'تبھی بنائیں جب یہ واقعی الگ چیز ہو۔',
  'Make it here anyway': 'پھر بھی یہاں بنائیں',
  'What kind of thing is "%s"?': '"%s" کس قسم کی چیز ہے؟',
  'A buffalo, a machine, a trolley the farm bought — it still owns them afterwards, so the cash moved and the profit did not. Wanda, tankhwah, bijli and marammat are spent and gone, and they do come off the profit.':
      'بھینس، مشین، یا ٹرالی جو فارم نے خریدی — بعد میں بھی فارم کی ملکیت '
      'رہتی ہے، اس لیے نقد نکلا مگر منافع کم نہیں ہوا۔ ونڈا، تنخواہ، بجلی '
      'اور مرمت خرچ ہو کر ختم — یہ منافع سے کٹتی ہیں۔',
  'The farm keeps it': 'فارم کے پاس رہے گی',
  'Spent and gone': 'خرچ ہو گیا',

  // ---- Settling up ----
  'How much goes out?': 'کتنا باہر جائے گا؟',
  'The same for all four. Whatever is left stays in the farm, in each of their names — it buys the next buffalo, and it is still theirs.':
      'چاروں کے لیے ایک جیسا۔ جو بچے وہ فارم میں رہے گا، ہر ایک کے نام پر — '
      'اُس سے اگلی بھینس آئے گی، اور وہ پھر بھی اُن کی ہے۔',
  'Nothing out': 'کچھ باہر نہیں',
  'Going out': 'باہر جا رہا ہے',
  'Staying in the farm': 'فارم میں رہ رہا ہے',
  'What each of them gets': 'ہر ایک کو کیا ملتا ہے',
  'Frozen': 'جم چکا',
  'Lost this period': 'اِس مدت میں نقصان',
  'Their share of the loss': 'نقصان میں اُن کا حصہ',
  'This period lost money, so there is nothing going out. The loss is split the same way a profit would be and comes off what each of them has kept in the farm — a bad month belongs to all four, the same as a good one.':
      'اِس مدت میں نقصان ہوا، اس لیے باہر کچھ نہیں جا رہا۔ نقصان اُسی طرح '
      'بانٹا جاتا ہے جیسے منافع، اور ہر ایک نے جو فارم میں رکھا ہے اُس میں سے '
      'کٹتا ہے — برا مہینہ بھی چاروں کا ہے، اچھے کی طرح۔',
  'What goes out is entered as a payment, what stays in goes to each of their profit accounts, and the other three are shown the figures. This cannot be undone.':
      'جو باہر جاتا ہے وہ ادائیگی کی اینٹری بنتی ہے، جو رہتا ہے وہ ہر ایک کے '
      'منافع کھاتے میں جاتا ہے، اور باقی تینوں کو ہندسے دکھا دیے جاتے ہیں۔ '
      'یہ واپس نہیں ہوگا۔',
  'The loss is posted to all four accounts and the period is filed. This cannot be undone.':
      'نقصان چاروں کے کھاتوں میں درج ہو جائے گا اور مدت بند ہو جائے گی۔ یہ '
      'واپس نہیں ہوگا۔',
  'The loss of %s goes onto all four accounts, split the way a profit would be.\n\nThis cannot be undone from the app.':
      '%s کا نقصان چاروں کے کھاتوں میں جائے گا، اُسی طرح جیسے منافع بانٹتا '
      'ہے۔\n\nایپ سے یہ واپس نہیں ہوگا۔',
  'Puts the figures back to being worked out. Only for a period sealed by mistake — nothing has been paid yet at this stage.':
      'ہندسے دوبارہ نکالنے کے لیے کھل جاتے ہیں۔ صرف اُس مدت کے لیے جو غلطی سے '
      'جم گئی — ابھی تک کسی کو کچھ دیا نہیں گیا۔',
  'The figures go back to being worked out. Nothing has been paid yet, so nothing is taken back.':
      'ہندسے دوبارہ نکالنے کے لیے کھل جاتے ہیں۔ ابھی تک کچھ دیا نہیں گیا، اس '
      'لیے کچھ واپس بھی نہیں لینا۔',
  'Reopen it': 'دوبارہ کھولیں',

  // ---- What a co-founder is shown ----
  'See the figures': 'ہندسے دیکھیں',
  'Your share. All of it has stayed in the farm, in your name, and it does not change your share of the farm.':
      'آپ کا حصہ۔ پورا فارم میں ہی رہا، آپ کے نام پر — اور اِس سے فارم میں آپ '
      'کا حصہ نہیں بدلتا۔',
  'Your share. %s of it has been handed over and the rest has stayed in the farm, in your name.':
      'آپ کا حصہ۔ اِس میں سے %s دے دیا گیا، باقی فارم میں ہی رہا، آپ کے نام '
      'پر۔',
  'Your share of what the farm lost this period. It has come off what you had kept in the farm.':
      'اِس مدت میں فارم کو جو نقصان ہوا، اُس میں آپ کا حصہ۔ آپ نے جو فارم میں '
      'رکھا تھا اُس میں سے کٹ گیا۔',
  'Your share of the loss': 'نقصان میں آپ کا حصہ',
  'Your %s of what the farm made this period.':
      'اِس مدت میں فارم نے جو کمایا، اُس کا آپ کا %s۔',
  'The period': 'مدت',
  'What the farm made': 'فارم نے کیا کمایا',
  'What the farm lost': 'فارم کو کیا نقصان ہوا',
  'Your share of the farm': 'فارم میں آپ کا حصہ',
  'Handed out this period': 'اِس مدت میں دیا گیا',
  'Taken off what you had kept': 'آپ نے جو رکھا تھا اُس میں سے کٹا',
  'Paid out to you': 'آپ کو دیا گیا',
  'Kept in the farm, in your name': 'فارم میں رہا، آپ کے نام پر',
  'Kept in the farm': 'فارم میں رہا',
  'Whatever is kept in stays yours. It does not change your share of the farm — that comes from what you have put in out of your own pocket, and only moves when you put in more.':
      'جو فارم میں رہتا ہے وہ آپ ہی کا ہے۔ اُس سے فارم میں آپ کا حصہ نہیں '
      'بدلتا — وہ اُس سے بنتا ہے جو آپ نے اپنی جیب سے لگایا، اور تبھی بدلتا '
      'ہے جب آپ اور لگائیں۔',
  'A month that loses money is shared the same way a month that makes it — your part of it comes off what you have kept in the farm. Nothing is hidden and nothing is carried quietly.':
      'جس مہینے نقصان ہو وہ اُسی طرح بانٹا جاتا ہے جس طرح کمائی — آپ کا حصہ '
      'اُس میں سے کٹتا ہے جو آپ نے فارم میں رکھا ہے۔ کچھ چھپایا نہیں جاتا اور '
      'کچھ چپ چاپ آگے نہیں لے جایا جاتا۔',
  'I have seen this': 'میں نے یہ دیکھ لیا',
  'It changes nothing about the money. It puts your name and the date against these figures, so nobody has to remember later who was told what.':
      'اِس سے پیسوں میں کچھ نہیں بدلتا۔ بس اِن ہندسوں کے ساتھ آپ کا نام اور '
      'تاریخ لکھی جاتی ہے، تاکہ بعد میں کسی کو یاد نہ رکھنا پڑے کہ کس کو کیا '
      'بتایا گیا تھا۔',
  'Noted — thank you.': 'درج ہو گیا — شکریہ۔',
  'Seen': 'دیکھ لیا',
  'New': 'نیا',
  'You saw this on %s.': 'آپ نے یہ %s کو دیکھا تھا۔',
  'That period is no longer here.': 'وہ مدت اب یہاں نہیں ہے۔',
  '%s — your share': '%s — آپ کا حصہ',
  '%s — settling up': '%s — حساب چکتا',
  'A loss': 'نقصان',
  '%s is open again.': '%s دوبارہ کھل گیا۔',
  '%s goes out to the co-founders and %s stays in the farm in their names.\n\nThis cannot be undone from the app.':
      '%s شریکوں کو جا رہا ہے اور %s فارم میں اُن کے نام پر رہ رہا ہے۔\n\nایپ '
      'سے یہ واپس نہیں ہوگا۔',

  // ---- What the cash is spoken for ----
  'Of that, the co-founders': 'اُس میں سے شریکوں کا',
  'profit they have earned and left in the farm':
      'اُن کا کمایا ہوا منافع جو فارم میں ہی چھوڑا',
  'Lent to co-founders': 'شریکوں کو قرض دیا',
  'out of the cash, and still owed to the farm':
      'نقد میں سے نکلا، اور ابھی فارم کو واپس آنا ہے',

  // ---- Loans ----
  'Ask the farm for a loan': 'فارم سے قرض مانگیں',
  'How much': 'کتنا',
  'Over how many months': 'کتنے مہینوں میں',
  '%s a month': '%s ماہانہ',
  'over %s months · %s a month': '%s مہینوں میں · %s ماہانہ',
  'Taken off your share when a period is settled. No interest — it is the farm\'s money and you pay back what you took, nothing more.':
      'مدت بند ہونے پر آپ کے حصے میں سے کٹ جائے گا۔ کوئی سود نہیں — یہ فارم '
      'کا پیسہ ہے، جتنا لیا اُتنا ہی واپس، اُس سے ایک روپیہ زیادہ نہیں۔',
  'Ask': 'مانگیں',
  'Asked. The master will see it.': 'مانگ لی۔ ماسٹر کو دکھ جائے گی۔',
  'Could not ask. %s': 'مانگ نہیں سکے۔ %s',
  'Waiting for the master to hand it over.': 'ماسٹر کے دینے کا انتظار ہے۔',
  'The cash leaves the farm when you hand it over. It is not a cost and it does not touch anybody\'s profit — it is the farm\'s money, in their pocket, until it comes back.':
      'آپ کے دیتے ہی پیسہ فارم سے نکل جائے گا۔ یہ خرچہ نہیں ہے اور اِس سے کسی '
      'کا منافع نہیں ہلتا — یہ فارم کا ہی پیسہ ہے، اُن کی جیب میں، جب تک واپس '
      'نہ آ جائے۔',
  'Hand it over': 'دے دیں',
  'Hand %s over?': '%s دے دیں؟',
  '%s leaves the farm now and comes back at %s a month out of what they are handed when a period is settled.\n\nIt is not a cost and nobody\'s profit changes.':
      '%s ابھی فارم سے نکل جائے گا اور %s ماہانہ واپس آئے گا — اُس میں سے جو '
      'اُن کو مدت بند ہونے پر ملتا ہے۔\n\nیہ خرچہ نہیں ہے اور کسی کا منافع '
      'نہیں بدلتا۔',
  'Handed over.': 'دے دیا۔',
  'Noted.': 'درج ہو گیا۔',
  'Paid back': 'واپس ہوا',
  'Paid back in full — %s.': 'پورا واپس ہو گیا — %s۔',
  'Loan': 'قرض',
  'The whole loan, from the day it was handed over':
      'پورا قرض، جس دن دیا گیا اُس دن سے',
  'Loan account': 'قرض کا کھاتہ',
  'Still owed': 'ابھی باقی',
  'The instalment comes off what they are handed when a period is settled. In a month where nothing goes out there is nothing to take it from, so it waits — and they can pay it in themselves any time.':
      'قسط اُس میں سے کٹتی ہے جو اُن کو مدت بند ہونے پر ملتا ہے۔ جس مہینے کچھ '
      'باہر ہی نہ جائے، اُس مہینے کاٹنے کو کچھ نہیں ہوتا، تو قسط رک جاتی ہے — '
      'اور وہ خود کبھی بھی جمع کرا سکتے ہیں۔',
  'They paid some in': 'اُنہوں نے کچھ جمع کرایا',
  'How much did they pay in?': 'کتنا جمع کرایا؟',
  'Taken in.': 'لے لیا۔',
  'Could not do it. %s': 'یہ نہیں ہو سکا۔ %s',
  'Asked for': 'مانگا ہوا',
  'Running': 'چل رہا ہے',
  'Paid off': 'چکتا ہو گیا',
  'Not given': 'نہیں دیا',

  // ---- Freezing the figures ----
  'Freeze the figures': 'ہندسے جما دیں',
  'The figures freeze here. Everything sold or spent after this belongs to the next period, whatever the date says. Nothing is handed out yet — that is the next step, where you say how much of it goes out and how much stays in the farm.':
      'ہندسے یہیں جم جاتے ہیں۔ اِس کے بعد جو بھی بیچا یا خرچ ہوا وہ اگلی مدت '
      'کا ہے، تاریخ چاہے جو کہے۔ ابھی کسی کو کچھ دیا نہیں جا رہا — وہ اگلا '
      'قدم ہے، جہاں آپ بتاتے ہیں کہ کتنا باہر جائے گا اور کتنا فارم میں رہے '
      'گا۔',
  '%s is cut into %s shares and held there.\n\nFrom this moment the figures cannot change, and every new entry — even one dated today — belongs to the next period. Nothing is paid out until you close it.':
      '%s کو %s حصوں میں کاٹ کر رکھ دیا جائے گا۔\n\nاِس وقت کے بعد ہندسے نہیں '
      'بدل سکتے، اور ہر نئی اینٹری — چاہے آج کی تاریخ کی ہو — اگلی مدت کی '
      'ہے۔ جب تک آپ بند نہیں کرتے، کسی کو کچھ نہیں دیا جائے گا۔',
  'There is nothing to share this time.\n\nFrom this moment the figures cannot change, and every new entry — even one dated today — belongs to the next period.':
      'اِس بار بانٹنے کو کچھ نہیں ہے۔\n\nاِس وقت کے بعد ہندسے نہیں بدل سکتے، '
      'اور ہر نئی اینٹری — چاہے آج کی تاریخ کی ہو — اگلی مدت کی ہے۔',

  // ---- What a figure is made of ----
  '%s entries, %s between them': '%s اینٹریاں، سب ملا کر %s',
  'Tap any one of them to read the whole entry — the same sheet the ledger opens, with everything written on it.':
      'اِن میں سے کسی پر بھی دبائیں تو پوری اینٹری کھل جائے گی — وہی ونڈو جو '
      'کھاتے میں کھلتی ہے، سب کچھ لکھا ہوا۔',
  'handed to %s': '%s کو دے دی',
  '%s taken in, less %s handed out': '%s لیا، اُس میں سے %s دیا',
  'less %s on its way to somebody': 'اور %s راستے میں ہے',
  'farm money taken in, still to be paid into its account':
      'فارم کا پیسہ جو لیا، ابھی فارم کے کھاتے میں جمع کرنا ہے',
  'every entry the four of them have taken money in on':
      'ہر وہ اینٹری جس پر اِن چاروں میں سے کسی نے پیسہ لیا',
  'every farm cost one of them paid for himself':
      'فارم کا ہر وہ خرچہ جو اِن میں سے کسی نے اپنی جیب سے دیا',

  // ---- The farm's own account on the "who paid" list ----
  'Farm account': 'فارم کا کھاتہ',
  'whatever is left': 'جو بچے',
  'The farm\'s own cash paid this part. Type against a man above and this comes down by it.':
      'یہ حصہ فارم کے اپنے نقد سے گیا۔ اوپر کسی کے سامنے لکھیں تو یہ اُتنا ہی '
      'کم ہو جائے گا۔',
  'Nothing left for the farm — more has been put against the men above than the entry comes to.':
      'فارم کے لیے کچھ نہیں بچا — اوپر والوں کے سامنے اینٹری سے زیادہ لکھ دیا '
      'گیا ہے۔',
  'The four of them paid all of it between them.':
      'پورا خرچہ اِن لوگوں نے آپس میں ہی دیا ہے۔',
  '%s — %s came out of the farm\'s own cash, so nobody\'s investment moves.':
      '%s — %s فارم کے اپنے نقد سے گیا، اس لیے کسی کی سرمایہ کاری نہیں بدلتی۔',

  // ---- Whose hands the rest of a split goes out through ----
  'Nobody is named on the entry as having handled this, so this much is the farm\'s cash with no pair of hands against it. Put a name on the entry.':
      'اینٹری پر کسی کا نام نہیں کہ یہ کس نے سنبھالا، اس لیے اِتنا فارم کا '
      'نقد بغیر کسی ہاتھ کے پڑا ہے۔ اینٹری پر نام ڈال دیں۔',
  'The farm\'s own account paid this part, and it comes off the farm account. Type against a man above and this comes down by it.':
      'یہ حصہ فارم کے اپنے کھاتے نے دیا، اور فارم کے کھاتے ہی سے کٹے گا۔ اوپر '
      'کسی کے سامنے لکھیں تو یہ اُتنا کم ہو جائے گا۔',
  'The farm\'s cash, out through %s\'s hands — it comes off what they are holding, not off the farm account. If the farm\'s own account paid it, change who handled the entry to the farm account.':
      'فارم کا نقد، %s کے ہاتھ سے — یہ اُن کے پاس جو ہے اُس میں سے کٹتا ہے، '
      'فارم کے کھاتے سے نہیں۔ اگر فارم کے اپنے کھاتے نے دیا ہے تو اینٹری میں '
      '«کس نے سنبھالا» بدل کر فارم کا کھاتہ کر دیں۔',
  '%s — %s of the farm\'s own cash goes out through their hands, so nobody\'s investment moves.':
      '%s — فارم کے اپنے نقد میں سے %s اُن کے ہاتھ سے گیا، اس لیے کسی کی '
      'سرمایہ کاری نہیں بدلتی۔',

  // ---- Working as the farm's own account ----
  'Whose hands': 'کس کے ہاتھ',
  'You are working as the farm account':
      'آپ فارم کے کھاتے کی طرف سے کام کر رہے ہیں',
  'Working as the farm account now': 'اب فارم کے کھاتے کی طرف سے',
  'Working as %s again': 'دوبارہ %s کی طرف سے',
  'Money you handle is the farm\'s. New entries open with the farm account as the hands it passed through, and the accounts page opens on the farm\'s. Your own holding is untouched, and the log still names you.':
      'جو پیسہ آپ سنبھالیں وہ فارم کا ہے۔ نئی اینٹری میں «کس نے سنبھالا» فارم '
      'کا کھاتہ آئے گا، اور حساب کا صفحہ فارم کے کھاتے پر کھلے گا۔ آپ کے '
      'اپنے پاس جو ہے وہ ویسے ہی رہتا ہے، اور ریکارڈ میں نام آپ کا ہی آتا '
      'ہے۔',
  'Money you handle is your own. Turn this on while you are running the farm\'s account and %s goes back to being just you.':
      'جو پیسہ آپ سنبھالیں وہ آپ کا اپنا ہے۔ جب فارم کا کھاتہ چلا رہے ہوں تو '
      'یہ چالو کر لیں، اور بند کرتے ہی %s صرف آپ رہ جاتے ہیں۔',
  'paid out more than came in': 'جتنا آیا اُس سے زیادہ دیا',
  'The farm\'s own account paid this part, and it comes off the farm\'s balance. Type against a man above and this comes down by it.':
      'یہ حصہ فارم کے اپنے کھاتے نے دیا، اور فارم کے بقایا سے ہی کٹے گا۔ اوپر '
      'کسی کے سامنے لکھیں تو یہ اُتنا کم ہو جائے گا۔',

  // ---- Bringing a deleted entry back ----
  'Bring it back': 'واپس لائیں',
  '%s is back on the books': '%s واپس کتاب میں آ گیا',
  'That entry is no longer there.': 'وہ اینٹری اب موجود ہی نہیں۔',
  'That entry is already back.': 'وہ اینٹری پہلے ہی واپس آ چکی ہے۔',
  'Could not bring it back. %s': 'واپس نہیں لا سکے۔ %s',
  'Open the entry': 'اینٹری کھولیں',
  'Back on the books': 'واپس کتاب میں',
  'Not paid after all': 'پیسہ آیا ہی نہیں',
  'One payment, across %s entries': 'ایک ہی ادائیگی، %s اینٹریوں پر',
  'One payment, across %s entries — tap to open':
      'ایک ہی ادائیگی، %s اینٹریوں پر — کھولنے کے لیے دبائیں',
  'One payment, across %s entries — tap to close':
      'ایک ہی ادائیگی، %s اینٹریوں پر — بند کرنے کے لیے دبائیں',

  // ---- Correcting one handful of money ----
  'Change this payment': 'یہ ادائیگی بدلیں',
  'What was handed over?': 'کتنا دیا گیا تھا؟',
  'It is laid across what they owe, oldest first — the same as when it was first taken in. Raise it and it reaches further down the days; lower it and it stops sooner. The day stays %s.':
      'یہ اُن کے بقایا پر بچھایا جاتا ہے، سب سے پرانے سے شروع — ویسے ہی جیسے '
      'پہلی بار لیا گیا تھا۔ بڑھا دیں تو اور اگلے دنوں تک پہنچے گا؛ کم کر '
      'دیں تو پہلے رک جائے گا۔ تاریخ %s ہی رہے گی۔',
  '%s · %s entries settled': '%s · %s اینٹریاں چکتا ہوئیں',
  'Could not change it. %s': 'بدل نہیں سکے۔ %s',
  '%s of the %s on this entry has already been paid back to %s. Moving it now would leave him owing the farm that much, with nothing on the books saying so.\n\nSettle the refund first, then change whose money it was.':
      'اِس اینٹری کے %s میں سے %s پہلے ہی %s کو واپس جا چکا ہے۔ اب اِس کو ہلایا تو اُس کے ذمے فارم کا اُتنا قرض بن جائے گا، اور کتاب میں کہیں لکھا نہیں ہوگا۔\n\nپہلے وہ واپسی کا حساب کریں، پھر نام بدلیں۔',
  '%s of this entry is on %s\'s investment. The name has moved to %s — should the money move with it?\n\nIt comes off his investment and goes onto theirs. Nothing else changes.':
      'اِس اینٹری کا %s ابھی %s کی سرمایہ کاری پر ہے۔ نام بدل کر %s ہو گیا ہے — پیسہ بھی ساتھ لے جائیں؟\n\nاُس کی سرمایہ کاری سے نکل کر اُن کی سرمایہ کاری میں چلا جائے گا۔ اور کچھ نہیں بدلتا۔',
  '%s → %s · %s\n\nNothing in the books moves. A handover writes nothing until the other man says he has the money, so this is only the note between you being torn up.':
      '%s سے %s کو · %s\n\nکتاب میں کچھ نہیں ہلتا۔ حوالگی تب تک کچھ لکھتی ہی نہیں جب تک دوسرا نہ کہے کہ پیسہ مل گیا، اس لیے یہ صرف آپ دونوں کے درمیان کی پرچی پھاڑی جا رہی ہے۔',
  'Advance against wages': 'تنخواہ کا ایڈوانس',
  'out of the cash, and coming back off a wage':
      'نقد میں سے نکلا، اور تنخواہ میں سے واپس آئے گا',
  '%s of it': 'اِس میں سے %s',
  '%s others': '%s اور',
  'Where it came from': 'پیسہ کہاں سے آیا',
  'Where it went': 'پیسہ کہاں گیا',
  'Spent on running the farm': 'فارم چلانے پر خرچ ہوا',
  'The farm is owed %s more than it owes.':
      'فارم کو جتنا دینا ہے اُس سے %s زیادہ لینا ہے۔',
  'Cattle, equipment and advances are in this list but not in the cost above — the farm still has the one and is still owed the other.':
      'مویشی، سامان اور ایڈوانس اِس فہرست میں ہیں مگر اوپر والے خرچے میں نہیں — ایک اب بھی فارم کے پاس ہے اور دوسرا فارم کو واپس آنا ہے۔',
  'Nearly all of what was put in is standing in the shed rather than spent. That is why a period can read as a loss while the farm is worth more than it was.':
      'جو ڈالا گیا اُس کا لگ بھگ سب کچھ خرچ ہونے کے بجائے شیڈ میں کھڑا ہے۔ اسی لیے کوئی مدت گھاٹے کی دکھ سکتی ہے جب کہ فارم پہلے سے زیادہ کا ہو چکا ہوتا ہے۔',
};
