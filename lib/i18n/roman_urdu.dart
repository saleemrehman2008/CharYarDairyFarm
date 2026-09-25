/// The app's English, written the way the farm speaks it.
///
/// Roman Urdu, not Urdu script: the same alphabet, the same numerals, the same
/// left-to-right page. Spellings follow how people actually type on WhatsApp
/// in Pakistan (khaata, hisaab, wasooli), not a transliteration scheme.
///
/// Banking and dairy words that arrived in Pakistan in English are left in
/// English on purpose — "bill", "cash", "order", "litre", "bank" — because
/// that is what a rider and a customer say out loud. Translating them would
/// make the app harder to read, not easier.
///
/// Keys are the exact English the screen passes to `L.t`. A phrase not listed
/// here shows in English.
const Map<String, String> romanUrdu = {
  // ---- Roles and people ----
  'Master': 'Master',
  'Co-founder': 'Co-founder',
  'Delivery staff': 'Rider',
  'Customer': 'Customer',
  'Co-founders': 'Saathi',
  'Partners': 'Saathi',
  'Team': 'Team',
  'Sign out': 'Sign out',
  'Sign in with Google': 'Google se sign in karen',

  // ---- Navigation ----
  'Home': 'Home',
  'Orders': 'Orders',
  'Accounts': 'Hisaab',
  'Cattle': 'Maweshi',
  'More': 'Aur',
  'Round': 'Round',
  'My day': 'Mera din',
  'Collect': 'Wasooli',
  'Shop': 'Shop',
  'Cart': 'Cart',
  'Khaata': 'Khaata',
  'Approvals': 'Manzoori',
  'Reports': 'Report',
  'Report': 'Report',
  'Settings': 'Settings',
  'Activity log': 'Kaam ka record',
  'Handovers': 'Handover',
  'Payment details': 'Payment ki tafseel',
  'Products': 'Cheezen',
  'Bills': 'Bill',
  'New entry': 'Nayi entry',

  // ---- Money ----
  'Cash in hand': 'Farm ke paas cash',
  'With the rider': 'Rider ke paas',
  'To receive': 'Lena hai',
  'To pay': 'Dena hai',
  'Sales': 'Farokht',
  'Costs': 'Kharcha',
  'Running costs': 'Chalne ka kharcha',
  'Expenses': 'Kharche',
  'Purchases': 'Khareed',
  'Receipts': 'Wasooli',
  'Payments': 'Adaigi',
  'Profit': 'Munafa',
  'Net': 'Net',
  'Total': 'Kul',
  'Balance': 'Baqaya',
  'Paid': 'Ada ho gaya',
  'Unpaid': 'Baqaya',
  'Amount': 'Raqam',
  'Rate': 'Rate',
  'Accounts receivable': 'Lena hai',
  'Accounts payable': 'Dena hai',
  'Capital': 'Sarmaya',
  'Investment': 'Investment',
  'Withdraw': 'Nikalna hai',
  'Add to investment': 'Investment me daalen',
  'Received': 'Mil gaya',
  'All': 'Sab',
  'Receivable': 'Lena hai',
  'Payable': 'Dena hai',

  // ---- Doing things ----
  'Save': 'Save karen',
  'Cancel': 'Rehne den',
  'Delete': 'Mitayen',
  'Undo': 'Wapas karen',
  'Approve': 'Manzoor karen',
  'Approved': 'Manzoor',
  'Reject': 'Mana karen',
  'Confirm': 'Pakka karen',
  'Close': 'Band karen',
  'Add': 'Shamil karen',
  'Edit': 'Badlen',
  'Done': 'Ho gaya',
  'Pending': 'Baqi hai',
  'Completed': 'Mukammal',
  'Open': 'Khula',
  'Refresh': 'Nayi khabar len',
  'Try again': 'Dobara koshish karen',
  'Not now': 'Abhi nahi',
  'Search': 'Dhoonden',
  'Mark paid': 'Ada shuda likhen',
  'Mark delivered': 'Delivered likhen',
  'Delivered': 'Pohanch gaya',
  'Morning': 'Subah',
  'Evening': 'Sham',
  'Today': 'Aaj',
  'Yesterday': 'Kal',

  // ---- Milk and the round ----
  'Milk': 'Doodh',
  'Litres': 'Litre',
  'Ghee': 'Ghee',
  'Deliveries': 'Delivery',
  'Spot sale': 'Spot sale',
  'Handover': 'Handover',
  'Loaded': 'Le kar gaya',
  'Returned': 'Wapas laya',
  'Cash collected': 'Cash wasool',
  'Left to deliver': 'Baqi delivery',

  // ---- The period ----
  'Month': 'Month',
  'Period': 'Period',
  'Close month': 'Month band karen',
  'Send to founders': 'Founders ko bhejen',
  'Your share': 'Aap ka hissa',
  'Profit to share': 'Munafa baantne ko',
  'Sealed': 'Jam chuka',
  'Waiting': 'Intezaar',

  // ---- Cattle ----
  'Buffalo': 'Bhains',
  'Cow': 'Gaay',
  'Calf': 'Bacha',
  'Goat': 'Bakri',
  'Tag': 'Tag',
  'Vaccination': 'Teeka',
  'Health': 'Sehat',
  'Photo': 'Tasveer',
  'Add photo': 'Tasveer lagayen',

  // ---- Words the app says back ----
  'Nothing here yet.': 'Abhi yahan kuch nahi.',
  'Nothing to show.': 'Dikhane ko kuch nahi.',
  'Needs attention': 'Tawajjo chahiye',
  'This cannot be undone.': 'Ye wapas nahi hoga.',
  'Language': 'Zubaan',
  'My account': 'Mera account',
  // ---- Home and getting around ----
  'Farm dashboard': 'Farm ka dashboard',
  'Do': 'Kaam',
  'Every day': 'Rozana',
  'The farm': 'Farm',
  'The farm itself': 'Khud farm',
  'Master only': 'Sirf master',
  'You': 'Aap',
  'Signed in as': 'Sign in kiye hue',
  'Users': 'Log',
  'Users & roles': 'Log aur un ka kaam',
  'User': 'Naya banda',
  'Team access': 'Team ki ijazat',
  'Google Sheets': 'Google Sheets',
  'Export books': 'Hisaab bahar nikalen',
  'Preparing files…': 'Files tayyar ho rahi hain…',
  'Nothing to export yet.': 'Abhi nikalne ko kuch nahi.',
  '%s files ready — pick where to save them':
      '%s files tayyar — batayen kahan save karni hain',
  'Could not export. %s': 'Nahi nikal saka. %s',
  'No sheet linked yet.': 'Abhi koi sheet jori nahi gayi.',
  'Could not open the sheet.': 'Sheet nahi khul saki.',
  'Products & rates': 'Cheezen aur rate',
  'Rates': 'Rate',
  'Cattle register': 'Maweshi register',
  'Khaata bills': 'Khaata ke bill',
  'Khaata sign-ups': 'Naye khaate',
  'Daily round': 'Rozana round',
  'Money to collect': 'Wasooli',
  'Orders to deliver': 'Pohanchane wale orders',
  'My orders': 'Mere orders',
  'Checkout': 'Checkout',
  'Loading…': 'Khul raha hai…',

  // ---- Money on the home page ----
  'Everything the farm can spend today.': 'Jo farm aaj kharch kar sakta hai.',
  '%s is still with the rider': '%s abhi rider ke paas hai',
  'feed, salaries, bills': 'wanda, tankhwah, bill',
  '+ %s assets': '+ %s ki cheezen khareedi',
  '%s unpaid': '%s baqaya',
  '%s bills': '%s bill',
  '%s entries': '%s entries',
  'Where the money is': 'Paisa kahan kahan hai',
  'Co-founders put in': 'Saathiyon ne daala',
  'Cattle & equipment bought': 'Maweshi aur saman khareeda',
  'the farm still owns these': 'ye ab bhi farm ki milkiyat hain',
  'Running costs so far': 'Ab tak ka kharcha',
  'Sales so far': 'Ab tak ki farokht',
  'Still to collect': 'Abhi lena hai',
  'Still to pay': 'Abhi dena hai',
  'taken at doors, not handed in yet':
      'darwazon se mila, abhi jama nahi karaya',
  'Earned, not held': 'Kamaya, haath me nahi',
  'costs': 'kharcha',
  'a month': 'ek maheene ka',
  'Order': 'Order',
  '%s wants a monthly account': '%s maheewar khaata chahta hai',
  '%s signed up': '%s ne account banaya',
  'Nothing waiting. The farm is up to date.':
      'Kuch baqi nahi. Farm poora update hai.',
  '%s of cattle & equipment bought is not counted here — the farm still owns it.':
      '%s ke maweshi aur saman yahan shumar nahi — wo ab bhi farm ke hain.',
  'This period has spent more than it has sold. That is not money lost — the farm still holds %s in cash. It is normal while stocking up: feed is bought in one go and eaten over months, while milk sells a little each day.':
      'Is period me farokht se zyada kharch hua hai. Paisa doob nahi gaya — farm ke paas ab bhi %s cash hai. Stock jama karte waqt yehi hota hai: wanda ek saath aata hai aur maheenon chalta hai, jab ke doodh roz thora thora bikta hai.',
  'Add co-founders before closing a period — there is nobody to share the profit with yet.':
      'Period band karne se pehle saathi shamil karen — abhi munafa baantne ko koi hai hi nahi.',
  'Work out shares': 'Hissay nikalen',
  '%s is out for decisions': '%s faisle ke liye bheja hua hai',

  // ---- The ledger ----
  'Add an entry': 'Nayi entry lagayen',
  'Nothing booked here yet. Tap Add to start.':
      'Abhi yahan kuch nahi likha. Shuru karne ke liye Add dabayen.',
  'All farm money in one place: milk & product sales, cattle, feed, bills, rent, food, salaries. Anything sold or bought on credit stays unpaid until you mark it paid.':
      'Farm ka saara paisa ek jagah: doodh aur cheezon ki farokht, maweshi, wanda, bill, kiraya, khana, tankhwah. Jo udhaar bika ya khareeda gaya wo baqaya rahega jab tak aap ada shuda na likhen.',
  'Delete entry': 'Entry mitayen',
  'farm asset · not a cost': 'farm ka maal · kharcha nahi',
  'not received': 'mila nahi',
  'not paid': 'diya nahi',
  'Sales this period': 'Is period ki farokht',

  // ---- The report ----
  'Chart': 'Chart',
  'Detail': 'Tafseel',
  'Money in': 'Aamdani',
  'Money out': 'Kharcha',
  '%s in, %s out': '%s aaya, %s gaya',
  'This period': 'Ye period',
  'Last 3 months': 'Pichle 3 maheene',
  'This year': 'Is saal',
  'Everything': 'Sab kuch',
  'Nothing booked in this stretch yet.': 'Is arse me abhi kuch nahi likha.',
  'Nothing here.': 'Yahan kuch nahi.',
  'Less cattle & equipment': 'Maweshi aur saman nikal kar',
  'Cattle and equipment are taken off the costs, because the money bought something the farm still has.':
      'Maweshi aur saman kharche se nikal diye jate hain, kyunke us paise se koi cheez aayi jo ab bhi farm ke paas hai.',
  '%s of cattle and equipment was bought in this stretch. It is not counted as a cost above — the farm owns it.':
      'Is arse me %s ke maweshi aur saman khareede gaye. Upar kharche me shumar nahi — wo farm ki milkiyat hain.',

  // ---- A co-founder's own page ----
  'Your share · %s': 'Aap ka hissa · %s',
  'of %s made in %s so far': '%s me se, jo %s me ab tak kamaya',
  'Your capital': 'Aap ka sarmaya',
  'put in from your pocket': 'apni jeb se daala',
  'incl. %s left in': 'is me %s chhora hua',
  'Farm balance': 'Farm ka balance',
  'cash in hand': 'haath me cash',
  '%s with the rider': '%s rider ke paas',
  'Margin': 'Munafe ki shirakat',
  'of %s sold': '%s ki farokht me se',
  'Milk out': 'Doodh gaya',
  'A DAY': 'ROZANA',
  'THIS PERIOD': 'IS PERIOD ME',
  'Across %s days of selling. Counted from the milk that was sold.':
      '%s din ki farokht per. Jo doodh bika usi se ginaa gaya hai.',
  'Look at': 'Dekhen',
  'Awaiting approval': 'Manzoori ka intezaar',
  'Nothing needs your approval right now.':
      'Abhi aap ki manzoori kisi cheez ko nahi chahiye.',
  'Open the Approvals tab to act on these.':
      'Manzoori wala tab kholen aur faisla karen.',
  'Your profit history': 'Aap ke munafe ka record',
  'No capital recorded for you yet.': 'Abhi aap ka koi sarmaya likha nahi.',
  'No period has been closed yet.': 'Abhi koi period band nahi hua.',
  'Taken out': 'Nikala',
  'Left in as investment': 'Investment ke tor per chhora',
  'Entered by %s': 'Entry %s ne ki',

  // ---- Google Sheet ----
  'Google Sheet': 'Google Sheet',
  'A second copy of the books, kept up to date by itself. Every change in the '
          'app reaches the Sheet a few seconds later — there is nothing to '
          'press.':
      'Hisaab ki doosri naqal, jo khud ba khud update rehti hai. App me jo bhi '
      'badle wo chand second me Sheet tak pohanch jata hai — kuch dabana '
      'nahi parta.',
  'not linked': 'juri nahi',
  'needs permission': 'ijazat chahiye',
  'live': 'live',
  'Paste the sheet link': 'Sheet ka link yahan lagayen',
  'Link this sheet': 'Ye sheet joren',
  'Sheet linked.': 'Sheet jur gayi.',
  'That does not look like a Google Sheet link.':
      'Ye Google Sheet ka link nahi lag raha.',
  'Allow the app to write to it': 'App ko likhne ki ijazat den',
  'Allowed. The Sheet will keep up on its own now.':
      'Ijazat mil gayi. Ab Sheet khud saath chalti rahegi.',
  'Google did not allow it. %s': 'Google ne ijazat nahi di. %s',
  'Nothing written to it yet.': 'Abhi is me kuch nahi likha gaya.',
  'Last written %s': 'Aakhri bar likha %s',
  'Write it now': 'Abhi likh den',
  'Written to the Sheet.': 'Sheet me likh diya.',
  'Could not write. %s': 'Likh nahi saka. %s',
  'Use another sheet': 'Koi aur sheet',
  'The Sheet needs to be shared so that anyone with the link can edit it. The '
          'app writes its own tabs — Summary, Entries, Periods, Co-founders, '
          'Khaata, Deliveries, Cattle — and rewrites them each time. Any other '
          'tab you build is left alone.':
      'Sheet aisi share honi chahiye ke jis ke paas link ho wo edit kar sake. '
      'App apne tabs likhti hai — Summary, Entries, Periods, Co-founders, '
      'Khaata, Deliveries, Cattle — aur har bar naye sire se. Jo tab aap '
      'khud banayen us ko haath nahi lagati.',

  // ---- The running ledger ----
  'closed here': 'yahan band hua',
  'Started %s': 'Shuru hua %s',
  'open now': 'abhi khula hai',
  'sealed — waiting on the co-founders': 'jam gaya — saathiyon ka intezaar',
  'earlier': 'is se pehle',
  '%s shared between the co-founders': '%s saathiyon me banta',
  'Nothing was shared out of this one.': 'Is me se kuch nahi banta.',

  // ---- Zero se ab tak ----
  'Summary': 'Khulasa',
  'Made since day one': 'Shuru se ab tak kamaya',
  'All time': 'Shuru se',
  '%s sold, %s spent on running the farm':
      '%s ka bika, %s farm chalane per kharch hua',
  'Put in': 'Daala gaya',
  'by the co-founders': 'saathiyon ne',
  'Sold': 'Bika',
  'Spent': 'Kharch',
  'Owns': 'Milkiyat',
  'cattle & equipment': 'maweshi aur saman',
  'Cash now': 'Abhi cash',
  'Period by period': 'Har period ka hisaab',
  'Newest first. The open one is still running.':
      'Naya sab se upar. Jo khula hai wo abhi chal raha hai.',
  'No period has been settled yet — this is the first one.':
      'Abhi koi period band nahi hua — ye pehla hai.',
  '%s went to the co-founders': '%s saathiyon ko gaya',
  'open': 'khula',
  'closed': 'band',
  'waiting': 'intezaar',

  // ---- Day by day, and the capital ----
  'Day by day': 'Roz ba roz',
  'Week by week': 'Hafta ba hafta',
  'In': 'Aaya',
  'Out': 'Gaya',
  'Best day: %s, %s': 'Sab se achha din: %s, %s',
  'Best week: the one from %s, %s': 'Sab se achha hafta: %s se, %s',
  'What the co-founders have in': 'Saathiyon ka lagaya hua',
  'No co-founders yet.': 'Abhi koi saathi nahi.',
  'put in from their own pocket': 'apni jeb se daala',
  'incl. %s left in from profit': 'is me %s munafe ka chhora hua',
  'Total capital': 'Kul sarmaya',
  'Taken out so far': 'Ab tak nikala',

  // ---- Settling the period ----
  'Settle %s': '%s ka hisaab',
  'Freeze %s?': '%s ko jama den?',
  'Send': 'Bhej den',
  'Send to co-founders': 'Saathiyon ko bhejen',
  'Sent. Waiting on the co-founders.': 'Bhej diya. Ab saathiyon ka intezaar.',
  'Could not send it. %s': 'Bhej nahi saka. %s',
  'Receivables': 'Baqaya',
  'Receivables kept': 'Baqaya shamil',
  'Uncollected receivables': 'Jo wasool nahi hua',

  // ---- Advances the farm is holding ----
  'Advances held': 'Advance jo rakha hua hai',
  'money that belongs to customers, and goes back when a contract ends':
      'ye customer ka paisa hai, contract khatam hone per wapas jata hai',
  'Advance the farm is holding': 'Advance jo farm ke paas para hai',
  'It belongs to them, not the farm. It goes back when they stop.':
      'Ye un ka paisa hai, farm ka nahi. Jab wo chhoren ge, wapas jayega.',

  // ---- The statement ----
  //
  // Debit, credit and balance stay in English on purpose. Every bank in
  // Pakistan prints them that way, so a customer handed this page has read
  // these three words a hundred times before.
  'Statement': 'Statement',
  'Statement of account': 'Khaate ka statement',
  'Cash book': 'Rozcha',
  'Char Yar Dairy Farm': 'Char Yar Dairy Farm',
  'Whose statement?': 'Kis ka statement?',
  'The whole farm': 'Poora farm',
  'All dates': 'Saare din',
  '%s days': '%s din',
  'Which days': 'Kaun se din',
  'Last 30 days': 'Pichhle 30 din',
  '3 months': '3 maheene',
  'A year': 'Ek saal',
  'Pick the days': 'Din chunen',
  'Everything, from the start': 'Shuru se ab tak',
  'Issued': 'Banaya gaya',
  'Account': 'Khaata',
  'Opening': 'Shuru ka baqaya',
  'Date': 'Tareekh',
  'Name': 'Naam',
  'Entered by': 'Entry ki',
  'Debit': 'Debit',
  'Credit': 'Credit',
  'Total debit': 'Kul debit',
  'Total credit': 'Kul credit',
  'Balance owed': 'Baqaya',
  'The farm owes': 'Farm ko dena hai',
  'Nothing in these days.': 'In dinon me kuch nahi.',
  'Send as PDF': 'PDF bhejen',
  'Send as picture': 'Tasveer bhejen',
  'Could not make the PDF. %s': 'PDF nahi ban saki. %s',
  'Could not make the picture. %s': 'Tasveer nahi ban saki. %s',
  'Advance': 'Advance',
  'entries': 'entries',
  'One person’s account. Milk they took puts the balance up whether it is '
          'paid for or not; money they hand over brings it down.':
      'Ek bande ka khaata. Jo doodh gaya wo baqaya barhata hai, paisa aaya ho '
      'ya nahi; jo paisa wo den wo baqaya ghatata hai.',
  'The farm’s cash book. Only what actually moved money is in it, so it opens '
          'at what the co-founders put in and closes at what is in the box today.':
      'Farm ka rozcha. Sirf wo cheezen jin me paisa asal me hila, is liye ye '
      'sarmaye se shuru hota hai aur aaj ke cash per khatam.',

  // ---- The two halves of the ledger ----
  'Still open': 'Abhi baqi hain',
  'Done with': 'Ho chuki hain',
  'Everything here': 'Yahan ki sab entries',

  // ---- Part payments, and the name off the books ----
  '%s in, %s still to come': '%s mila, %s abhi baqi',
  'part paid': 'thora mila',
  'ticked': 'nishan',
  'milk': 'doodh',
  'owed': 'baqi',
  'How much is being handed over': 'Kitna paisa mil raha hai',
  'Leave it empty for all of it — %s': 'Poora lena ho to khali chhor den — %s',
  'Take in %s': '%s wasool karen',
  'Taking it in…': 'Wasool ho raha hai…',
  'to pay': 'dena hai',
  'How much is being paid': 'Kitna paisa diya ja raha hai',
  'Pay %s': '%s ada karen',
  'Paying…': 'Ada ho raha hai…',
  '%s will still be owing to them. The oldest bills are paid first; whatever '
          'is left over stops part way through one, and that is the one the next '
          'payment finishes.':
      '%s abhi un ka baqi rahega. Sab se purane bill pehle ada honge; jo '
      'bachega wo aakhri wale per adhoora reh jayega, aur agli bar wohi '
      'poora hoga.',
  '%s settled, %s still owed': '%s ka hisaab hua, %s abhi baqi',
  'Could not take it in. %s': 'Wasool nahi ho saka. %s',
  '%s will still be owed. The oldest entries are settled first; whatever is '
          'left over stops part way through one, and that is the one the next '
          'payment fills.':
      '%s abhi baqi rahega. Sab se purani entries pehle poori hongi; jo bachega '
      'wo aakhri wali per adhoora reh jayega, aur agli bar wohi pehle '
      'bharegi.',
  'New name — "%s"': 'Naya naam — "%s"',
  'Not written down before': 'Pehle kabhi nahi likha gaya',
  '%s owed': '%s baqi',
  'Change': 'Badlen',

  // ---- Settling a week of credit in one go ----
  '%s not settled yet': '%s abhi baqi hain',
  'Settle several': 'Ek sath hisaab',
  'Tick what they are paying for': 'Jis ka paisa de rahe hain, nishan lagayen',
  '%s ticked': '%s per nishan',
  'All of them': 'Sab per',
  'Clear': 'Nishan hatayen',
  'Mark %s paid': '%s ko paid karen',
  'Settling…': 'Hisaab ho raha hai…',
  '%s settled · %s': '%s ka hisaab ho gaya · %s',
  '%s of %s went through': '%s me se %s ho gaye',
  'Money coming in and money going out have to be settled apart.':
      'Jo paisa aa raha hai aur jo ja raha hai, dono ka hisaab alag karna hoga.',
  'Asked once how the money came, then each entry is settled on its own — so '
          'a part payment marks only what it covers.':
      'Paisa kaise aaya, ye ek hi bar poocha jayega, phir har entry apni jagah '
      'paid hogi — is liye thora paisa den to sirf utni hi entries per '
      'nishan lagega.',

  // ---- Looking up one name or one kind of entry ----
  'Anyone': 'Koi bhi',
  'Anything': 'Kuch bhi',
  'Everybody': 'Sab log',
  'Whose entries?': 'Kis ki entries?',
  'Which kind of entry?': 'Kis qism ki entry?',
  'Nothing by that name.': 'Is naam se kuch nahi mila.',
  'Sold to them, all time': 'Un ko becha, shuru se ab tak',
  'Bought from them, all time': 'Un se khareeda, shuru se ab tak',
  'They still owe': 'Un ke zimme baqi hai',
  'The farm still owes them': 'Farm ke zimme baqi hai',
  'Nothing outstanding either way.': 'Dono taraf kuch baqi nahi.',
  'Paid out to co-founders': 'Founders ko diya',
  'Other money in': 'Doosri aamdani',
  'receipts with no sale booked against them':
      'jo paisa aaya lekin us ki koi sale nahi lagi',
  'Every rupee is accounted for.': 'Har rupay ka hisaab poora hai.',
  '%s is not accounted for. An entry is probably missing, or one has been '
          'typed twice.':
      '%s ka hisaab poora nahi. Ya to koi entry reh gayi hai, ya koi do bar '
      'lag gayi hai.',
  'Who did what': 'Kis ne kya kiya',
  'Cattle & equipment owned': 'Maweshi aur saaman jo farm ka hai',
  'money that turned into animals, not money spent':
      'paisa jo jaanwar ban gaya, kharch nahi hua',
  'their share of the profit': 'unka munafe ka hissa',
  '%s rolled from last time is back in this figure — it was held back then, '
          'so it is shared now.':
      'Pichli bar ka %s is me wapas shamil hai — us waqt rok liya tha, ab '
      'baant diya ja raha hai.',
  'Received %s': '%s ko mila',
  'Paid %s': '%s ko diya',
  "Count as this period's income (share on paper)":
      'Is period ki aamdani ginen (kaaghaz per baanten)',
  'Roll into the next period (share cash only)':
      'Agle period me le jayen (sirf cash baanten)',
  "Each co-founder's share": 'Har saathi ka hissa',
  '%s of cattle & equipment was bought. It is not a cost — the farm owns it — so it is not taken off the profit.':
      '%s ke maweshi aur saman khareede gaye. Ye kharcha nahi — farm ka apna maal hai — is liye munafe se nahi kaata gaya.',
  'Settling in the middle of the month': 'Maheene ke beech me hisaab',
  'Khaata carries on exactly as it is — customers are billed at the end of their month, not now, and nobody gets an extra bill because of this.':
      'Khaata bilkul waisa hi chalega — customers ko un ke maheene ke aakhir me bill jayega, abhi nahi, aur is wajah se kisi ko extra bill nahi milega.',
  'Khaata milk counts as income the day the customer pays for it, so this period holds what has been collected. The rest arrives in the period it is collected in. Nothing is lost; it moves along.':
      'Khaata ka doodh us din aamdani banta hai jis din customer paisa deta hai, is liye is period me wohi hai jo wasool ho chuka. Baqi us period me aayega jis me wasool hoga. Kuch gum nahi hota, aage khisak jata hai.',
  'The figures freeze the moment you send it. Everything sold or spent after this belongs to the next period, whatever the date says — so a co-founder answering in two days sees exactly what you are looking at now.':
      'Bhejte hi figures jam jate hain. Us ke baad jo bhi bika ya kharch hua wo agle period ka hai, tareekh chahe kuch bhi kahe — is liye do din baad jawab dene wale saathi ko bilkul wohi nazar aayega jo abhi aap ko.',
  '%s goes out to %s co-founders to decide on.\n\nFrom this moment the figures cannot change, and every new entry — even one dated today — belongs to the next period.':
      '%s, %s saathiyon ke faisle ke liye ja raha hai.\n\nIs lamhe ke baad figures nahi badal sakte, aur har nayi entry — chahe aaj ki tareekh ki ho — agle period ki hai.',
  'There is nothing to share, so there is nothing to send. Settle once the period has made a profit.':
      'Baantne ko kuch nahi, is liye bhejne ko bhi kuch nahi. Period munafa de le, phir hisaab karen.',
  'This period is at a loss of %s, so there is nothing to share out. Check that every sale is entered — a big one-off buy like cattle will show as a loss in the period you pay for it.':
      'Is period me %s ka ghaata hai, is liye baantne ko kuch nahi. Dekh len ke har farokht likhi gayi hai — maweshi jaisi bari khareed us period me ghaata dikhati hai jis me paisa diya jata hai.',

  'End this period': 'Ye period khatam karen',
  'End it': 'Khatam karen',
  'Settling before the month ends': 'Maheena khatam hone se pehle hisaab',
  'You can settle up on any day you like — the period simply ends here and the next one starts. Khaata is not touched: customers are still billed at the end of their own month, and nobody gets an extra bill because of this.':
      'Aap jis din chahen hisaab kar sakte hain — period yahan khatam aur agla shuru. Khaata is se nahi chherta: customers ko un ke apne maheene ke aakhir me hi bill jayega, aur is wajah se kisi ko extra bill nahi milega.',
  'Nothing to share this time. The period still ends here and the next one opens.':
      'Is dafa baantne ko kuch nahi. Period phir bhi yahan khatam hoga aur agla khul jayega.',
  'This period is %s down, so there is nothing to share out — and nothing '
          'comes off anybody\'s capital either. The shortfall is already in the '
          'cash the next period starts with.\n\nBefore you end it, check every '
          'sale is entered. A big one-off buy like cattle shows as a loss in '
          'the period you pay for it, even though the farm still has the '
          'animal.':
      'Is period me %s ka ghaata hai, is liye baantne ko kuch nahi — aur kisi '
      'ke sarmaye se bhi kuch nahi kata. Ye kami pehle hi us cash me '
      'shamil hai jis se agla period shuru hoga.\n\nKhatam karne se pehle '
      'dekh len ke har farokht likhi gayi hai. Maweshi jaisi bari khareed '
      'us period me ghaata dikhati hai jis me paisa diya jata hai, chahe '
      'jaanwar farm hi ke paas ho.',
  'There is nothing to share, so nobody is asked to decide.\n\nFrom this '
          'moment the figures cannot change, and every new entry — even one '
          'dated today — belongs to the next period.':
      'Baantne ko kuch nahi, is liye kisi se faisla nahi poocha jayega.\n\nIs '
      'lamhe ke baad figures nahi badal sakte, aur har nayi entry — chahe '
      'aaj ki tareekh ki ho — agle period ki hai.',
  'Nothing to hand out': 'Baantne ko kuch nahi',
  'Nothing to share': 'Kuch nahi baantna',
  'This period made no profit, so nobody is being asked to decide anything. Close it and the next period carries on from here.':
      'Is period me munafa nahi hua, is liye kisi se kuch nahi poocha ja raha. Band kar den, agla period yahan se chalta rahega.',
  'Nothing is paid out. The period is finished and filed.':
      'Koi adaigi nahi hogi. Period khatam ho kar record me chala jayega.',

  // ---- The decisions ----
  '%s — decisions': '%s — faisle',
  'All in': 'Sab aa gaye',
  '%s waiting': '%s ka intezaar',
  'Frozen %s. It will not change.': '%s ko jam gaya. Ab nahi badlega.',
  'Frozen %s. This figure will not change.':
      '%s ko jam gaya. Ye figure nahi badlega.',
  'Taking out': 'Nikal rahe hain',
  'Back into the farm': 'Wapas farm me',
  'What each of them wants': 'Har ek kya chahta hai',
  'Share': 'Hissa',
  'Into investment': 'Investment me',
  'Decided': 'Faisla ho gaya',
  'Waiting on you': 'Aap ka intezaar',
  'Decide': 'Faisla karen',
  'Enter after ringing them': 'Phone kar ke yahan likhen',
  'Confirmed by phone and entered by the master.':
      'Phone per confirm hua, master ne likha.',
  'Approve all & close the period': 'Sab manzoor karen aur period band karen',
  'Every share is posted, the withdrawals are entered as payments, and the investments go up. This cannot be undone.':
      'Har hissa lag jayega, nikali hui raqam adaigi ke tor per likhi jayegi, aur investment barh jayegi. Ye wapas nahi hoga.',
  'Waiting on %s. The decision is theirs — ring them, and if they tell you what they want, enter it on their row. It will be recorded as confirmed by phone.':
      '%s ka intezaar hai. Faisla un ka apna hai — phone karen, aur jo wo kahen wo un ki line me likh den. Likha jayega ke phone per confirm hua.',
  'Close %s?': '%s band karen?',
  '%s goes out to the co-founders and %s stays in the farm as investment.\n\nThis cannot be undone from the app.':
      '%s saathiyon ko jayega aur %s investment ban kar farm me rahega.\n\nApp se ye wapas nahi hoga.',
  'Close the period': 'Period band karen',
  '%s closed.': '%s band ho gaya.',
  'Could not close it. %s': 'Band nahi kar saka. %s',
  'Reopen this period': 'Ye period dobara kholen',
  'Reopen it?': 'Dobara kholen?',
  'Reopen': 'Kholen',
  'The figures go back to being worked out and every decision so far is cleared. The co-founders will have to choose again.':
      'Figures dobara bante hain aur ab tak ke sab faisle mit jate hain. Saathiyon ko dobara chunna hoga.',
  'Puts the figures back to being worked out, and clears every decision. Only for a period sealed by mistake — nothing has been paid yet at this stage.':
      'Figures dobara banne lagte hain aur har faisla mit jata hai. Sirf us period ke liye jo galti se jam gaya ho — is marhale tak koi adaigi nahi hui hoti.',
  'Could not reopen it. %s': 'Dobara nahi khol saka. %s',

  // ---- A co-founder's own share ----
  '%s share': '%s ka hissa',
  '%s is settled': '%s ka hisaab ho gaya',
  'Your share. Say how much of it you want to take out — the rest is added to your investment. Nothing moves until every co-founder has answered.':
      'Aap ka hissa. Batayen kitna nikalna hai — baqi aap ki investment me jama ho jayega. Jab tak har saathi jawab na de, kuch nahi hoga.',
  'Tap to change it until the master closes the period.':
      'Master ke period band karne tak dabakar badal sakte hain.',
  'Entered by the master after speaking to you. Tap to change it while the period is still open.':
      'Master ne aap se baat kar ke likha. Period khula hai, dabakar badal sakte hain.',
  'You take out': 'Aap nikal rahe hain',
  'Stays as investment': 'Investment me rahega',
  'How much do you want to take out?': 'Kitna nikalna chahte hain?',
  'Take nothing': 'Kuch nahi',
  'Take all of it': 'Poora nikal len',
  'Your share is only %s — you cannot take more than that.':
      'Aap ka hissa sirf %s hai — is se zyada nahi nikal sakte.',
  'Taking the whole share. Nothing goes to investment.':
      'Poora hissa nikal rahe hain. Investment me kuch nahi jayega.',
  '%s is added to your investment, so your share of the next period goes up.':
      '%s aap ki investment me jama hoga, is liye agle period me aap ka hissa barh jayega.',
  'Entering this for someone else': 'Ye kisi aur ke liye likh rahe hain',
  'Only do this after speaking to %s. It will be saved as confirmed by phone, with your name on it, and they will be told what was entered.':
      'Ye sirf %s se baat karne ke baad karen. Ye phone per confirm shuda likha jayega, aap ke naam ke saath, aur unhen bata diya jayega ke kya likha gaya.',
  'Save what they told you': 'Jo unhon ne kaha wo save karen',
  'Confirm my decision': 'Mera faisla pakka karen',
  'Save for %s?': '%s ke liye save karen?',
  'Confirm?': 'Pakka?',
  '%s out, %s into investment.': '%s bahar, %s investment me.',
  'Saved.': 'Save ho gaya.',
  'Could not save it. %s': 'Save nahi ho saka. %s',
  'You can change this until the master closes the period. After that it is final.':
      'Master ke period band karne tak badal sakte hain. Us ke baad final hai.',
  'There is nothing to decide right now. The master will send the figures when the period is settled.':
      'Abhi faisla karne ko kuch nahi. Period ka hisaab hote hi master figures bhej dega.',

  // ---- What the farm runs ----
  'What the farm runs': 'Farm me kya kya chal raha hai',
  'Selling': 'Farokht',
  'Online orders': 'Online orders',
  'Shop, cart, and orders going out to doors':
      'Shop, cart, aur darwazon tak jane wale orders',
  'Daily milk on account, billed once a month':
      'Rozana khaate per doodh, maheene me ek bill',
  'Out on the round': 'Round per',
  "The rider's work": 'Rider ka kaam',
  'Round, spot sale, handover, collection':
      'Round, spot sale, handover, wasooli',
  'Online orders and khaata are both off, so there is nothing for a rider to take out. Switch one of them on and this comes back by itself.':
      'Online orders aur khaata dono band hain, is liye rider ke le jane ko kuch nahi. Koi ek chalu karen, ye khud wapas aa jayega.',
  'Animals, tags, milk yield, vet visits':
      'Jaanwar, tag, doodh, doctor ke chakkar',
  'Books': 'Hisaab kitaab',
  'Entries, accounts, reports, closing a period':
      'Entry, hisaab, report, period band karna',
  'The books always run. Everything else can be switched off; the farm still has to know what it has.':
      'Hisaab hamesha chalta hai. Baqi sab band ho sakta hai; farm ko phir bhi pata hona chahiye us ke paas kya hai.',
  'What switching off does': 'Band karne se kya hota hai',
  'The tab disappears from every phone on the farm and the notifications stop. Nothing is deleted — every khaata, order and bill stays exactly where it is, and comes back untouched when you switch it on again.':
      'Wo tab farm ke har phone se ghayab ho jata hai aur us ki ittila band ho jati hai. Kuch mitta nahi — har khaata, order aur bill jahan hai wahin rehta hai, aur dobara on karne per jaisa tha waisa hi aa jata hai.',
  'Only you can see this screen. Co-founders, riders and customers have no such setting.':
      'Ye safha sirf aap dekh sakte hain. Saathiyon, rider aur customers ke paas aisi koi setting hai hi nahi.',
  'Switch the round off too?': 'Round bhi band kar den?',
  'With neither online orders nor khaata running there is nothing for the rider to take out, so the round, spot sales, the handover and the collection screens all go with it.\n\nNothing is deleted. It all comes back when you switch a delivery channel on again.':
      'Na online orders chal rahe hain na khaata, to rider ke le jane ko kuch nahi. Is liye round, spot sale, handover aur wasooli — sab saath jayenge.\n\nKuch mitta nahi. Koi ek chalu karte hi sab wapas aa jayega.',
  'Switch off': 'Band karen',
  'Could not save that. %s': 'Ye save nahi ho saka. %s',

  // ---- Language and account ----
  'The whole app reads in this language — bills, alerts and reports too. It is yours alone; nobody else on the farm changes with it.':
      'Poori app isi zubaan me parhi jayegi — bill, ittila aur report bhi. Ye sirf aap ki hai; farm per kisi aur ka kuch nahi badalta.',

  // ---- The round ----
  '%s khaata houses done': '%s khaata ghar ho gaye',
  '%s still to collect from orders': 'Orders se %s abhi wasool karna hai',
  'This round is done.': 'Ye round poora ho gaya.',
  '%s still to go on the %s round.': '%s round me %s abhi baqi hain.',
  'morning': 'subah wale',
  'evening': 'sham wale',
  'Show all': 'Sab dikhayen',
  'Only left (%s)': 'Sirf baqi (%s)',
  '%s orders are waiting for a co-founder to approve. They appear here as soon as that happens.':
      '%s orders kisi saathi ki manzoori ka intezaar kar rahe hain. Manzoori milte hi yahan aa jayenge.',
  '%s orders are waiting for a co-founder to approve. They reach the round after that.':
      '%s orders kisi saathi ki manzoori ka intezaar kar rahe hain. Us ke baad round per aayenge.',
  '%s orders are for later days.': '%s orders aage ke dinon ke hain.',
  'Nothing on this round. Khaata customers appear here every day once a co-founder approves them, and shop orders appear on the days the customer asked for.':
      'Is round per kuch nahi. Khaata customers saathi ki manzoori ke baad roz yahan aate hain, aur shop ke orders un dinon aate hain jo customer ne chune the.',
  'What is coming. Milk is marked delivered on the round, where the day and the money are.':
      'Kya kya aa raha hai. Doodh round per delivered mark hota hai, jahan din aur paisa dono hain.',
  'Undo this delivery?': 'Ye delivery wapas karen?',
  '%s comes back out of the books, and the day goes back on the round. The entry stays in the log marked deleted.':
      '%s hisaab se wapas nikal jayega aur wo din dobara round per aa jayega. Entry record me mitayi hui likhi rahegi.',
  'Undo it': 'Wapas karen',
  'Undone': 'Wapas ho gaya',
  'Could not undo it. %s': 'Wapas nahi kar saka. %s',
  '#%s delivered': '#%s pohanch gaya',
  'Ready': 'Tayyar',
  'Nothing to collect': 'Kuch wasool nahi karna',
  'Collect %s': '%s wasool karen',
  'Goes on their khaata — billed at month end':
      'Un ke khaate me jayega — maheene ke aakhir me bill',
  'On their khaata.': 'Un ke khaate me.',
  '%s taken.': '%s le liya.',
  'The rider marks this delivered.': 'Ye rider delivered mark karega.',
  'Not yet': 'Abhi nahi',
  'No rate set': 'Rate nahi laga',
  'usually %s L': 'aam tor per %s L',
  'nothing to collect, billed at month end':
      'kuch wasool nahi karna, bill maheene ke aakhir me',
  'Set a rate in Khaata sign-ups before delivering, or this milk is billed at nothing.':
      'Delivery se pehle Naye khaate me rate laga den, warna ye doodh sifar per bill hoga.',
  'Set a rate for %s first, in Khaata sign-ups.':
      'Pehle %s ka rate lagayen, Naye khaate me.',
  'How many litres?': 'Kitne litre?',
  '%s cleared': '%s ka din saaf kar diya',
  'bill raised': 'bill ban gaya',
  'Update': 'Badlen',
  'by %s': '%s ne',

  // ---- Customer ----
  'The farm is not taking orders yet': 'Farm abhi order nahi le raha',
  'Char Yar Dairy Farm has not opened online ordering or monthly khaata accounts yet. You will be able to order here as soon as it does.':
      'Char Yar Dairy Farm ne abhi na online order shuru kiya hai na maheewar khaata. Jaise hi shuru hoga, aap yahin se order kar sakenge.',
  'Cancel order #%s?': 'Order #%s cancel karen?',
  'The farm will not prepare it.': 'Farm ise tayyar nahi karega.',
  'Cancel it': 'Cancel karen',
  'Order #%s cancelled': 'Order #%s cancel ho gaya',
  'Could not cancel it. %s': 'Cancel nahi kar saka. %s',
  'No orders yet. Your first one will show up here.':
      'Abhi koi order nahi. Pehla order yahin nazar aayega.',
  'Nothing on its way right now.': 'Abhi raste me kuch nahi.',
  'Nothing delivered yet.': 'Abhi kuch pohancha nahi.',

  // ---- Rider ----
  'No round today': 'Aaj koi round nahi',
  'The farm has deliveries switched off at the moment, so there is nothing to take out. This screen will fill up again as soon as the master switches them back on.':
      'Farm ne filhal delivery band ki hui hai, is liye le jane ko kuch nahi. Master ke dobara chalu karte hi ye safha phir bhar jayega.',
  'Particulars': 'Tafseel',
  'Showing': 'Dikha raha hai',
  'Show everything, paid or not': 'Sab kuch dikhayen, ada ho ya na ho',
  'Feed bought on credit, a buffalo that died, milk still owed for. The running total stops being the cash in the box and becomes the total of what is on the page.':
      'Udhaar per liya hua wanda, mari hui bhains, wo dodh jis ka paisa abhi aana hai. Neeche ka figure phir tijori ka cash nahi rehta — wo us sab ka jorr ban jata hai jo is safhe per hai.',
  // Reaches l.t() through StatementKind, so check_words cannot see it.
  'Every entry, paid or not': 'Har entry, ada ho ya na ho',
  // Reaches l.t() through StatementKind, so check_words cannot see it.
  'Extract': 'Khulasa',
  'Total shown': 'Jo dikhaya gaya, us ka kul',
  '%s still to decide': '%s ka faisla baqi hai',

  // ---- What the co-founders have in ----
  'Put in from their pockets': 'Apni jeb se lagaya',
  'Profit left in the farm': 'Profit jo farm me chhora',
  'Total investment': 'Kul investment',
  // These three reach l.t() through StatementKind, so check_words cannot see
  // them in the source. They are looked up by the same English text all the
  // same, and without them a whole page falls back to English.
  'Capital account': 'Hissa-daari ka khaata',
  'Their stake in the farm': 'Farm me un ka hissa',
  'Every period settled so far': 'Ab tak ke tamam settle shuda period',

  // ---- Writing a category out ----
  'Something else — write it out': 'Koi aur cheez — khud likhen',
  'What is it for?': 'Ye kis cheez ke liye hai?',
  'It will be filed under %s.': 'Ye %s me darj hogi.',
  'Write it out': 'Khud likhen',
  'Tubewell repair, trolley, mazdoori…':
      'Tubewell marammat, trolley, mazdoori…',
  'already there': 'pehle se maujood',
  'Use this': 'Yehi rakhen',
  '"%s" is already being used': '"%s" pehle se istemal ho raha hai',
  'It is on the %s tab. If that is where this belongs, go back and write it there — the summary keeps one word in one place. Make it here as well only if it is genuinely a different thing.':
      'Ye %s tab me hai. Agar is ka asal maqam wahi hai to wapas ja kar wahan likhen — summary ek lafz ko ek hi jagah rakhti hai. Yahan bhi tabhi banayen jab ye waqai alag cheez ho.',
  'Make it here anyway': 'Phir bhi yahan banayen',
  'Is "%s" something the farm keeps?': 'Kya "%s" farm ke paas rahegi?',
  'A buffalo, a machine, a trolley — the farm still owns it afterwards, so the money moved but the profit did not. Feed, wages, bijli and repairs are spent and gone, and they do come off the profit.':
      'Bhains, machine, trolley — baad me bhi farm ki milkiyat rehti hai, is liye paisa nikla magar profit kam nahi hua. Wanda, tankhwah, bijli aur marammat kharch ho kar khatam — ye profit se kat-ti hain.',
  'The farm keeps it': 'Farm ke paas rahegi',
  'Spent and gone': 'Kharch ho gaya',
  // ---- Settling up, version 2 ----
  'How much goes out?': 'Kitna bahar jayega?',
  'The same for all four. Whatever is left stays in the farm, in each of their names — it buys the next buffalo, and it is still theirs.':
      'Chaaron ke liye ek jaisa. Jo bache wo farm me rahega, har ek ke naam per — us se agli bhains aayegi, aur wo phir bhi un ki hai.',
  'Nothing out': 'Kuch bahar nahi',
  'Going out': 'Bahar ja raha hai',
  'Staying in the farm': 'Farm me reh raha hai',
  'What each of them gets': 'Har ek ko kya milta hai',
  'Frozen': 'Jam chuka',
  'Lost this period': 'Is period me nuqsan',
  'Their share of the loss': 'Nuqsan me un ka hissa',
  'This period lost money, so there is nothing going out. The loss is split the same way a profit would be and comes off what each of them has kept in the farm — a bad month belongs to all four, the same as a good one.':
      'Is period me nuqsan hua, is liye bahar kuch nahi ja raha. Nuqsan usi tarah baanta jata hai jaise munafa, aur har ek ne jo farm me rakha hai us me se katta hai — bura mahina bhi chaaron ka hai, achhe ki tarah.',
  'What goes out is entered as a payment, what stays in goes to each of their profit accounts, and the other three are shown the figures. This cannot be undone.':
      'Jo bahar jata hai wo payment ki entry banti hai, jo rehta hai wo har ek ke profit khaate me jata hai, aur baqi teeno ko figures dikha diye jate hain. Ye wapas nahi hoga.',
  'The loss is posted to all four accounts and the period is filed. This cannot be undone.':
      'Nuqsan chaaron ke khaaton me darj ho jayega aur period band ho jayega. Ye wapas nahi hoga.',
  'The loss of %s goes onto all four accounts, split the way a profit would be.\n\nThis cannot be undone from the app.':
      '%s ka nuqsan chaaron ke khaaton me jayega, usi tarah jaise munafa baantta hai.\n\nApp se ye wapas nahi hoga.',
  'Puts the figures back to being worked out. Only for a period sealed by mistake — nothing has been paid yet at this stage.':
      'Figures dobara nikalne ke liye khul jate hain. Sirf us period ke liye jo ghalti se jam gaya — abhi tak kisi ko kuch diya nahi gaya.',
  'The figures go back to being worked out. Nothing has been paid yet, so nothing is taken back.':
      'Figures dobara nikalne ke liye khul jate hain. Abhi tak kuch diya nahi gaya, is liye kuch wapas bhi nahi lena.',
  'Reopen it': 'Dobara kholen',

  // ---- What a co-founder is shown ----
  'See the figures': 'Figures dekhen',
  'Your share. All of it has stayed in the farm, in your name, and it does not change your share of the farm.':
      'Aap ka hissa. Poora farm me hi raha, aap ke naam per — aur is se farm me aap ka hissa nahi badalta.',
  'Your share. %s of it has been handed over and the rest has stayed in the farm, in your name.':
      'Aap ka hissa. Is me se %s de diya gaya, baqi farm me hi raha, aap ke naam per.',
  'Your share of what the farm lost this period. It has come off what you had kept in the farm.':
      'Is period me farm ko jo nuqsan hua, us me aap ka hissa. Aap ne jo farm me rakha tha us me se kat gaya.',
  'Your share of the loss': 'Nuqsan me aap ka hissa',
  'Your %s of what the farm made this period.':
      'Is period me farm ne jo kamaya, us ka aap ka %s.',
  'The period': 'Period',
  'What the farm made': 'Farm ne kya kamaya',
  'What the farm lost': 'Farm ko kya nuqsan hua',
  'Your share of the farm': 'Farm me aap ka hissa',
  'Handed out this period': 'Is period me diya gaya',
  'Taken off what you had kept': 'Aap ne jo rakha tha us me se kata',
  'Paid out to you': 'Aap ko diya gaya',
  'Kept in the farm, in your name': 'Farm me raha, aap ke naam per',
  'Kept in the farm': 'Farm me raha',
  'Whatever is kept in stays yours. It does not change your share of the farm — that comes from what you have put in out of your own pocket, and only moves when you put in more.':
      'Jo farm me rehta hai wo aap hi ka hai. Us se farm me aap ka hissa nahi badalta — wo us se banta hai jo aap ne apni jeb se lagaya, aur tabhi badalta hai jab aap aur lagayen.',
  'A month that loses money is shared the same way a month that makes it — your part of it comes off what you have kept in the farm. Nothing is hidden and nothing is carried quietly.':
      'Jis mahine nuqsan ho wo usi tarah baanta jata hai jis tarah kamai — aap ka hissa us me se katta hai jo aap ne farm me rakha hai. Kuch chhupaya nahi jata aur kuch chup chaap aage nahi le jaya jata.',
  'I have seen this': 'Maine ye dekh liya',
  'It changes nothing about the money. It puts your name and the date against these figures, so nobody has to remember later who was told what.':
      'Is se paison me kuch nahi badalta. Bas in figures ke saath aap ka naam aur tareekh likhi jati hai, taake baad me kisi ko yaad na rakhna pare ke kis ko kya bataya gaya tha.',
  'Noted — thank you.': 'Darj ho gaya — shukriya.',
  'Seen': 'Dekh liya',
  'New': 'Naya',
  'You saw this on %s.': 'Aap ne ye %s ko dekha tha.',
  'That period is no longer here.': 'Wo period ab yahan nahi hai.',
  '%s — your share': '%s — aap ka hissa',
  '%s — settling up': '%s — hisaab chukta',
  'A loss': 'Nuqsan',
  '%s is open again.': '%s dobara khul gaya.',
  '%s goes out to the co-founders and %s stays in the farm in their names.\n\nThis cannot be undone from the app.':
      '%s saathiyon ko ja raha hai aur %s farm me un ke naam per reh raha hai.\n\nApp se ye wapas nahi hoga.',
  // ---- What the cash is spoken for ----
  'Of that, the co-founders': 'Us me se saathiyon ka',
  'profit they have earned and left in the farm':
      'un ka kamaya hua profit jo farm me hi chhora',
  'Lent to co-founders': 'Saathiyon ko qarz diya',
  'out of the cash, and still owed to the farm':
      'cash me se nikla, aur abhi farm ko wapas aana hai',

  // ---- Qarz ----
  'Ask the farm for a loan': 'Farm se qarz maangen',
  'How much': 'Kitna',
  'Over how many months': 'Kitne mahinon me',
  '%s a month': '%s mahana',
  'over %s months · %s a month': '%s mahinon me · %s mahana',
  'Taken off your share when a period is settled. No interest — it is the farm\'s money and you pay back what you took, nothing more.':
      'Period band hone per aap ke hisse me se kat jayega. Koi sood nahi — ye farm ka paisa hai, jitna liya utna hi wapas, us se ek rupiya zyada nahi.',
  'Ask': 'Maangen',
  'Asked. The master will see it.': 'Maang li. Master ko dikh jayegi.',
  'Could not ask. %s': 'Maang nahi saka. %s',
  'Waiting for the master to hand it over.': 'Master ke dene ka intezaar hai.',
  'The cash leaves the farm when you hand it over. It is not a cost and it does not touch anybody\'s profit — it is the farm\'s money, in their pocket, until it comes back.':
      'Aap ke dete hi paisa farm se nikal jayega. Ye kharcha nahi hai aur is se kisi ka profit nahi hilta — ye farm ka hi paisa hai, un ki jeb me, jab tak wapas na aa jaye.',
  'Hand it over': 'De den',
  'Hand %s over?': '%s de den?',
  '%s leaves the farm now and comes back at %s a month out of what they are handed when a period is settled.\n\nIt is not a cost and nobody\'s profit changes.':
      '%s abhi farm se nikal jayega aur %s mahana wapas aayega — us me se jo un ko period band hone per milta hai.\n\nYe kharcha nahi hai aur kisi ka profit nahi badalta.',
  'Handed over.': 'De diya.',
  'Noted.': 'Darj ho gaya.',
  'Paid back': 'Wapas hua',
  'Still owed': 'Abhi baqi',
  'The instalment comes off what they are handed when a period is settled. In a month where nothing goes out there is nothing to take it from, so it waits — and they can pay it in themselves any time.':
      'Kist us me se katt-ti hai jo un ko period band hone per milta hai. Jis mahine kuch bahar hi na jaye, us mahine kaatne ko kuch nahi hota, to kist ruk jati hai — aur wo khud kabhi bhi jama kara sakte hain.',
  'They paid some in': 'Un hon ne kuch jama karaya',
  'How much did they pay in?': 'Kitna jama karaya?',
  'Taken in.': 'Le liya.',
  'Could not do it. %s': 'Ye nahi ho saka. %s',
  'Asked for': 'Maanga hua',
  'Running': 'Chal raha hai',
  'Paid off': 'Chukta ho gaya',
  'Not given': 'Nahi diya',
  // ---- Freezing the figures ----
  'Freeze the figures': 'Figures jama den',
  'The figures freeze here. Everything sold or spent after this belongs to the next period, whatever the date says. Nothing is handed out yet — that is the next step, where you say how much of it goes out and how much stays in the farm.':
      'Figures yahin jam jate hain. Is ke baad jo bhi becha ya kharch hua wo agle period ka hai, tareekh chahe jo kahe. Abhi kisi ko kuch diya nahi ja raha — wo agla qadam hai, jahan aap batate hain ke kitna bahar jayega aur kitna farm me rahega.',
  '%s is cut into %s shares and held there.\n\nFrom this moment the figures cannot change, and every new entry — even one dated today — belongs to the next period. Nothing is paid out until you close it.':
      '%s ko %s hisson me kaat kar rakh diya jayega.\n\nIs waqt ke baad figures nahi badal sakte, aur har nayi entry — chahe aaj ki tareekh ki ho — agle period ki hai. Jab tak aap band nahi karte, kisi ko kuch nahi diya jayega.',
  'There is nothing to share this time.\n\nFrom this moment the figures cannot change, and every new entry — even one dated today — belongs to the next period.':
      'Is bar baantne ko kuch nahi hai.\n\nIs waqt ke baad figures nahi badal sakte, aur har nayi entry — chahe aaj ki tareekh ki ho — agle period ki hai.',
};
