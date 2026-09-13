import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// A part of the farm the master can switch off for everybody.
///
/// Switching one off is not a permission and not a delete: the screens vanish
/// from every phone, the notifications stop, and the records stay exactly
/// where they are, waiting for it to be switched back on.
enum Feature {
  orders('orders'),
  khaata('khaata'),

  /// Everything the rider does: the round, spot sales, the handover, and the
  /// cash he collects. It has no life of its own — with neither orders nor
  /// khaata running there is nothing to load onto a motorcycle — so the master
  /// cannot switch it on by itself. See [Features.riderPossible].
  rider('rider'),

  cattle('cattle'),

  /// Entries, the ledger, reports and closing a period. The farm's own books
  /// keep working whatever else is switched off, so this one is always on.
  books('books');

  const Feature(this.id);

  final String id;

  bool get alwaysOn => this == Feature.books;
}

/// Which parts of the farm are running.
class Features {
  const Features(this._on);

  final Set<Feature> _on;

  /// A farm that has never been configured runs the books and the cattle
  /// register. Orders and khaata are deliberately left off: they are switched
  /// on the day the farm starts selling, not the day the app is installed.
  static const initial = Features({Feature.books, Feature.cattle});

  /// Whether the rider's side can be run at all. With nothing to deliver it
  /// cannot, and the switch is shown but not usable.
  bool get riderPossible => _on.contains(Feature.orders) || _on.contains(Feature.khaata);

  bool has(Feature f) {
    if (f.alwaysOn) return true;
    if (f == Feature.rider) return riderPossible && _on.contains(f);
    return _on.contains(f);
  }

  bool get orders => has(Feature.orders);
  bool get khaata => has(Feature.khaata);
  bool get rider => has(Feature.rider);
  bool get cattle => has(Feature.cattle);

  /// Anything a customer can do at all. With both off, a customer's app has
  /// nothing in it, so they are told so rather than shown empty tabs.
  bool get anythingForCustomers => orders || khaata;

  Features with_(Feature f, bool on) {
    final next = Set<Feature>.from(_on);
    if (on) {
      next.add(f);
      // Turning delivery back on brings the rider with it, which is what the
      // master means by it — otherwise the round would be on with nobody
      // able to walk it.
      if (f == Feature.orders || f == Feature.khaata) next.add(Feature.rider);
    } else {
      next.remove(f);
    }
    return Features(next);
  }

  List<String> get ids => _on.map((f) => f.id).toList();

  static Features from(Object? value) {
    if (value == null) return initial;
    final ids = _strings(value).toSet();
    return Features(
      Feature.values.where((f) => ids.contains(f.id)).toSet()
        ..add(Feature.books),
    );
  }
}

class FarmSettings {
  const FarmSettings({
    required this.name,
    required this.milkPriceCache,
    required this.bankAccount,
    required this.jazzcashNumber,
    required this.sheetId,
    required this.whatsappNumbers,
    required this.cofounderEmails,
    required this.staffEmails,
    required this.founders,
    required this.bankQr,
    required this.lastSyncAt,
    required this.syncOk,
    required this.features,
  });

  final String name;
  final num milkPriceCache;
  final String bankAccount;
  final String jazzcashNumber;
  final String sheetId;
  final List<String> whatsappNumbers;

  /// Emails the master set aside, so those people arrive in the right place
  /// the first time they sign in.
  final List<String> cofounderEmails;
  final List<String> staffEmails;

  /// The co-founders, by name, so a rider knows who he can hand the day's
  /// cash to.
  ///
  /// Kept here rather than read from the users collection, which a rider's
  /// phone cannot see and should not. The master's app keeps it in step.
  final List<FarmPerson> founders;

  /// The bank or JazzCash QR, as a picture, so a customer paying online can
  /// scan instead of typing an account number wrong.
  final String bankQr;

  final DateTime? lastSyncAt;
  final bool syncOk;

  /// Which parts of the farm are switched on. Master only.
  final Features features;

  String get sheetUrl =>
      sheetId.isEmpty ? '' : 'https://docs.google.com/spreadsheets/d/$sheetId';

  static const fallback = FarmSettings(
    name: 'Char Yar Dairy Farm',
    milkPriceCache: 200,
    bankAccount: '',
    jazzcashNumber: '',
    sheetId: '',
    whatsappNumbers: [],
    cofounderEmails: [],
    staffEmails: [],
    founders: [],
    bankQr: '',
    lastSyncAt: null,
    syncOk: true,
    features: Features.initial,
  );

  factory FarmSettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    if (m == null) return fallback;
    return FarmSettings(
      name: s(m['name']).isEmpty ? fallback.name : s(m['name']),
      milkPriceCache: m['milkPriceCache'] == null
          ? fallback.milkPriceCache
          : n(m['milkPriceCache']),
      bankAccount: s(m['bankAccount']),
      jazzcashNumber: s(m['jazzcashNumber']),
      sheetId: s(m['sheetId']),
      whatsappNumbers: _strings(m['whatsappNumbers']),
      cofounderEmails: _strings(m['autoCofounderEmails']),
      staffEmails: _strings(m['staffEmails']),
      founders: FarmPerson.listFrom(m['founders']),
      bankQr: s(m['bankQr']),
      lastSyncAt: dt(m['lastSyncAt']),
      syncOk: m['syncOk'] == null ? true : b(m['syncOk']),
      features: Features.from(m['features']),
    );
  }
}

/// Somebody the app has to name without being able to read the users list.
class FarmPerson {
  const FarmPerson({required this.uid, required this.name});

  final String uid;
  final String name;

  Map<String, dynamic> toMap() => {'uid': uid, 'name': name};

  static List<FarmPerson> listFrom(Object? value) =>
      ((value as List?) ?? const [])
          .map((e) => (e as Map?)?.cast<String, dynamic>() ?? const {})
          .map((m) => FarmPerson(uid: s(m['uid']), name: s(m['name'])))
          .where((p) => p.uid.isNotEmpty)
          .toList();
}

/// Firestore arrays arrive loosely typed and sometimes with blanks in them.
List<String> _strings(Object? value) => ((value as List?) ?? const [])
    .map((e) => s(e).trim())
    .where((e) => e.isNotEmpty)
    .toList();
