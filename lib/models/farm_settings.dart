import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

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
