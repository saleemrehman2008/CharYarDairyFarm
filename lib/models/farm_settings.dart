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
    required this.lastSyncAt,
    required this.syncOk,
  });

  final String name;
  final num milkPriceCache;
  final String bankAccount;
  final String jazzcashNumber;
  final String sheetId;
  final List<String> whatsappNumbers;
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
      whatsappNumbers: ((m['whatsappNumbers'] as List?) ?? const [])
          .map((e) => s(e))
          .where((e) => e.isNotEmpty)
          .toList(),
      lastSyncAt: dt(m['lastSyncAt']),
      syncOk: m['syncOk'] == null ? true : b(m['syncOk']),
    );
  }
}
