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
      lastSyncAt: dt(m['lastSyncAt']),
      syncOk: m['syncOk'] == null ? true : b(m['syncOk']),
    );
  }
}

/// Firestore arrays arrive loosely typed and sometimes with blanks in them.
List<String> _strings(Object? value) => ((value as List?) ?? const [])
    .map((e) => s(e).trim())
    .where((e) => e.isNotEmpty)
    .toList();
