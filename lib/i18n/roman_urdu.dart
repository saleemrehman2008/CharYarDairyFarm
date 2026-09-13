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
};
