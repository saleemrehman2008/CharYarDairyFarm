import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../util/money.dart';
import 'db.dart';
import 'log_service.dart';

/// Builds the farm's books as CSV files and hands them to the phone's share
/// sheet, so they can go straight into Google Sheets, Drive or WhatsApp.
///
/// This is the manual stand-in for the Cloud Functions mirror, which needs the
/// Blaze plan. The columns are deliberately identical, so when the automatic
/// sync is switched on the two line up and nothing has to be re-learned.
class ExportService {
  ExportService._();

  /// One CSV per tab of the Google Sheet.
  static Future<List<File>> buildFiles() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final out = <File>[];

    Future<void> write(String name, List<List<Object?>> rows) async {
      // A single-row file is just the header — nothing worth sharing.
      if (rows.length < 2) return;
      final file = File('${dir.path}/$name-$stamp.csv');
      await file.writeAsString(rows.map(_csvRow).join('\r\n'));
      out.add(file);
    }

    await write('transactions', await _transactions());
    await write('orders', await _orders());
    await write('partners', await _partners());
    await write('month-close', await _months());
    await write('udhaar', await _udhaar());
    await write('users', await _users());
    await write('activity-log', await _logs());

    return out;
  }

  /// Writes the files and opens the share sheet. Returns how many were shared.
  static Future<int> share(Actor actor) async {
    final files = await buildFiles();
    if (files.isEmpty) return 0;

    await SharePlus.instance.share(
      ShareParams(
        files: files.map((f) => XFile(f.path)).toList(),
        subject:
            'Char Yar Dairy Farm — books to ${fmtDateFull(DateTime.now())}',
        text:
            'Farm books exported from the app. Open each file in Google Sheets '
            'to keep a copy.',
      ),
    );

    await Log.write(
      actor,
      LogKind.transaction,
      'exported the books (${files.length} files)',
    );
    return files.length;
  }

  // ---- One builder per tab, columns matching the Sheets mirror ----

  static Future<List<List<Object?>>> _transactions() async {
    final snap = await Db.transactions.get();
    final txns = snap.docs.map(Txn.fromDoc).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return [
      [
        'id',
        'date',
        'month',
        'type',
        'party',
        'category',
        'qty',
        'unit',
        'rate',
        'amount',
        'paid',
        'paidAt',
        'note',
        'orderId',
        'asset',
        'payVia',
        'handledBy',
        'createdBy',
        'createdAt',
        'deleted',
      ],
      for (final t in txns)
        [
          t.id,
          fmtDateFull(t.date),
          t.monthId,
          t.type.name,
          t.party,
          t.category,
          t.qty,
          t.unit,
          t.rate,
          t.amount,
          t.paid,
          t.paidAt == null ? '' : fmtDateFull(t.paidAt!),
          t.note,
          t.orderId,
          t.isCapitalAsset ? 'asset' : '',
          t.payVia.label,
          t.handledBy,
          t.createdBy,
          fmtDateFull(t.createdAt),
          t.isDeleted ? 'deleted' : '',
        ],
    ];
  }

  static Future<List<List<Object?>>> _orders() async {
    final snap = await Db.orders.get();
    final orders = snap.docs.map(FarmOrder.fromDoc).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return [
      [
        'id',
        'number',
        'date',
        'customer',
        'items',
        'total',
        'mode',
        'slot',
        'repeat',
        'payment',
        'status',
        'approvedBy',
        'deliveredAt',
      ],
      for (final o in orders)
        [
          o.id,
          o.number,
          fmtDateFull(o.createdAt),
          o.customerName,
          o.itemsText,
          o.total,
          o.mode,
          o.slot,
          o.repeat,
          o.pay.name,
          o.status.key,
          o.approvedByName ?? '',
          o.deliveredAt == null ? '' : fmtDateFull(o.deliveredAt!),
        ],
    ];
  }

  static Future<List<List<Object?>>> _partners() async {
    final snap = await Db.partners.get();
    final partners = snap.docs.map(Partner.fromDoc).toList();
    final ratios = ratiosOf(partners);

    return [
      ['id', 'name', 'invested', 'reinvested', 'withdrawn', 'ratio%'],
      for (final p in partners)
        [
          p.id,
          p.name,
          p.invested,
          p.reinvested,
          p.withdrawn,
          ((ratios[p.id] ?? 0) * 1000).round() / 10,
        ],
    ];
  }

  static Future<List<List<Object?>>> _months() async {
    final snap = await Db.months.get();
    final months = snap.docs.map(FarmMonth.fromDoc).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    String slot(FarmMonth m, int i, bool choice) {
      if (i >= m.shares.length) return '';
      return choice ? m.shares[i].choice : '${m.shares[i].share}';
    }

    return [
      [
        'month',
        'status',
        'sales',
        'purchases',
        'expenses',
        'AR',
        'arIncluded',
        'profitShared',
        'partner1 share',
        'partner2 share',
        'partner3 share',
        'partner4 share',
        'partner1 choice',
        'partner2 choice',
        'partner3 choice',
        'partner4 choice',
        'closedAt',
      ],
      for (final m in months)
        [
          m.id,
          m.status,
          m.sales,
          m.purchases,
          m.expenses,
          m.receivables,
          m.arIncluded,
          m.profit,
          for (var i = 0; i < 4; i++) slot(m, i, false),
          for (var i = 0; i < 4; i++) slot(m, i, true),
          m.closedAt == null ? '' : fmtDateFull(m.closedAt!),
        ],
    ];
  }

  static Future<List<List<Object?>>> _udhaar() async {
    final snap = await Db.udhaarAccounts.get();
    final accounts = snap.docs.map(UdhaarAccount.fromDoc).toList();

    return [
      [
        'uid',
        'name',
        'mobile',
        'address',
        'slot',
        'litres',
        'rate',
        'a month',
        'balance',
        'status',
        'approvedBy',
      ],
      for (final a in accounts)
        [
          a.uid,
          a.name,
          a.mobile,
          a.address,
          a.slot,
          a.litresPerDay,
          a.rate,
          a.monthlyEstimate,
          a.balance,
          a.status.name,
          a.approvedByName ?? '',
        ],
    ];
  }

  static Future<List<List<Object?>>> _users() async {
    final snap = await Db.users.get();
    final users = snap.docs.map(AppUser.fromDoc).toList();

    return [
      ['uid', 'name', 'email', 'role', 'status', 'createdAt'],
      for (final u in users)
        [
          u.uid,
          u.name,
          u.email,
          u.role.name,
          u.status.name,
          fmtDateFull(u.createdAt),
        ],
    ];
  }

  static Future<List<List<Object?>>> _logs() async {
    final snap = await Db.logs
        .orderBy('at', descending: true)
        .limit(2000)
        .get();
    final entries = snap.docs.map(LogEntry.fromDoc).toList();

    return [
      ['at', 'who', 'kind', 'what'],
      for (final e in entries) [fmtStamp(e.at), e.who, e.kind.name, e.what],
    ];
  }

  /// Quotes anything a farm might actually type — a comma in an address, a
  /// quote in a note, a line break in either.
  static String _csvRow(List<Object?> cells) => cells.map(_csvCell).join(',');

  static String _csvCell(Object? value) {
    if (value == null) return '';
    final text = '$value';
    if (!text.contains(RegExp('[",\n\r]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
