import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/tokens.dart';
import 'helpers.dart';

enum Role {
  master,
  investor,

  /// Money in the farm and no hand in running it.
  ///
  /// He has put capital in and takes his share of the profit like the
  /// rest of them, and he wants to be able to look: what came in this
  /// month, what went out, what the cattle are doing, where his own
  /// account stands. He enters nothing, corrects nothing and approves
  /// nothing — the master and whoever keeps the cash do all of it for
  /// him, in his name.
  ///
  /// Reading everything and writing nothing is not a courtesy here, it
  /// is the point: the books are open to the people whose money is in
  /// them, and a man who cannot change a figure can never be suspected
  /// of having changed one. The rules enforce it rather than the
  /// buttons — see canSee() against isPartner() in firestore.rules.
  silent,

  staff,
  customer;

  static Role parse(Object? v) => switch (s(v)) {
    'master' => Role.master,
    'investor' => Role.investor,
    'silent' => Role.silent,
    'staff' => Role.staff,
    _ => Role.customer,
  };

  String get label => switch (this) {
    Role.master => 'Master',
    Role.investor => 'Co-founder',
    Role.silent => 'Silent investor',
    Role.staff => 'Delivery staff',
    Role.customer => 'Customer',
  };

  /// What this person may do, in one line, for the screen that grants it.
  String get what => switch (this) {
    Role.master => 'Everything, including the figures nobody else may touch',
    Role.investor => 'The books, and the day to day running of the farm',
    Role.silent => 'Looks at everything. Changes nothing.',
    Role.staff => 'The round: milk dropped off and money taken at the door',
    Role.customer => 'Their own orders and their own khaata',
  };

  /// The partners — they hold capital and see the farm's books.
  bool get isPartner => this == Role.master || this == Role.investor;

  /// Everyone whose money is in the farm, and who may therefore read it.
  bool get seesTheBooks => isPartner || this == Role.silent;

  /// Whether this person may change anything at all.
  bool get readOnly => this == Role.silent;

  /// Everyone who goes out on the round: the partners and the delivery staff.
  /// Staff can record milk and take money, and see nothing of the books.
  bool get canDeliver => isPartner || this == Role.staff;
}

enum UserStatus {
  pending,
  active,
  blocked;

  static UserStatus parse(Object? v) => switch (s(v)) {
    'active' => UserStatus.active,
    'blocked' => UserStatus.blocked,
    _ => UserStatus.pending,
  };

  String get label => switch (this) {
    UserStatus.pending => 'Pending',
    UserStatus.active => 'Active',
    UserStatus.blocked => 'Blocked',
  };
}

/// The two ways the app can be read.
///
/// Both are written in the same alphabet — Roman Urdu is Urdu spelled with
/// English letters, the way the farm already writes on WhatsApp. That keeps
/// one font, one direction and one set of numerals, so switching costs the
/// app nothing.
enum Lang {
  en('en', 'English'),
  ur('ur', 'Roman Urdu');

  const Lang(this.id, this.label);

  final String id;
  final String label;

  static Lang parse(Object? v) => s(v) == 'ur' ? Lang.ur : Lang.en;
}

class AppUser {
  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.role,
    required this.status,
    required this.address,
    required this.mobile,
    this.partnerId,
    required this.lang,
    required this.skin,
    required this.chatSeenAt,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final Role role;
  final UserStatus status;

  /// Where to deliver, and the number to ring at the gate. Asked once at the
  /// first order and reused after that.
  final String address;
  final String mobile;

  final String? partnerId;

  /// Each person reads the app in their own language; it is their setting,
  /// not the farm's.
  final Lang lang;

  /// Which of the three skins this person's phone wears. Theirs alone, the
  /// same as the language — the man who does the four o'clock round wants
  /// black, the man who does the books at noon may not.
  final Skin skin;

  /// The last time this person had the farm's room open. Everything said
  /// after it is what the dot on the tab is counting.
  final DateTime? chatSeenAt;

  final DateTime createdAt;

  bool get canOrder => status == UserStatus.active;

  /// True once the farm knows where this customer lives.
  bool get hasDeliveryDetails =>
      address.trim().isNotEmpty && mobile.trim().isNotEmpty;
  bool get isBlocked => status == UserStatus.blocked;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: s(m['name']).isEmpty
          ? s(m['email']).split('@').first
          : s(m['name']),
      email: s(m['email']),
      photoUrl: s(m['photoUrl']),
      role: Role.parse(m['role']),
      status: UserStatus.parse(m['status']),
      address: s(m['address']),
      mobile: s(m['mobile']),
      partnerId: m['partnerId'] == null ? null : s(m['partnerId']),
      lang: Lang.parse(m['lang']),
      skin: Skin.byName(m['skin'] as String?),
      chatSeenAt: m['chatSeenAt'] == null ? null : dtOr(m['chatSeenAt']),
      createdAt: dtOr(m['createdAt']),
    );
  }
}
