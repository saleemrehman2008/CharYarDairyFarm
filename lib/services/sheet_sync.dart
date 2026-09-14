import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../util/money.dart';
import 'auth_service.dart';
import 'db.dart';

/// The farm's books, mirrored into its Google Sheet as they change.
///
/// Written from the phone with the partner's own Google account rather than
/// from a server, because a server here means Cloud Functions, and those need
/// a card on the Firebase project. This needs nothing but the sheet's link and
/// one extra permission at sign-in.
///
/// Not a button. Every change the app makes lands in the Sheet a few seconds
/// later, so the Sheet is a live second copy of the books — which is also the
/// farm's backup, and the surface it builds its own tables and charts on.
///
/// Each tab is rewritten whole rather than appended to. The farm's books are a
/// few hundred rows; working out which rows changed would cost more than
/// writing all of them, and a full rewrite is the only way a corrected or
/// deleted entry ever leaves the Sheet. Tabs the app does not own are never
/// touched, so anything built alongside them survives.
class SheetSync {
  SheetSync._();

  /// Writing to a spreadsheet the person can already open. Sensitive enough
  /// that Google asks about it once, and no more than is needed: the app can
  /// reach no other file in the account.
  static const scope = 'https://www.googleapis.com/auth/spreadsheets';

  static const _api = 'https://sheets.googleapis.com/v4/spreadsheets';

  /// How long to wait for the changes to stop before writing.
  ///
  /// A round of deliveries fires a dozen updates in a few seconds; without
  /// this the Sheet would be rewritten a dozen times for one round.
  static const _settle = Duration(seconds: 6);

  /// The soonest one phone will write after another one did.
  ///
  /// Every partner's app mirrors, so that the Sheet keeps up even when the
  /// master's phone is in his pocket. They would otherwise all write the same
  /// rows at the same moment.
  static const _cooldown = Duration(seconds: 45);

  static Timer? _timer;
  static bool _writing = false;
  static String? _lastError;

  /// What went wrong last time, for the screen that shows the Sheet's state.
  static String? get lastError => _lastError;

  /// Whether the account has already granted the permission, without asking.
  static Future<bool> get authorised async =>
      (await _token(prompt: false)) != null;

  /// Asks for the permission. Only from a button the person pressed.
  static Future<bool> requestAccess() async {
    final token = await _token(prompt: true);
    return token != null;
  }

  /// Note that something changed. Writes once the changes stop.
  ///
  /// The books are gathered inside the timer rather than at the call, because
  /// a round of deliveries calls this a dozen times a second and gathering
  /// them means reading the ledger.
  static void nudge(Future<SheetBooks> Function() read) {
    _timer?.cancel();
    _timer = Timer(_settle, () async {
      try {
        await push(await read());
      } catch (e) {
        _lastError = '';
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Writes the books into the Sheet. Quiet about failure: a farm with no
  /// signal still has its books, and the next change tries again.
  static Future<bool> push(SheetBooks books, {bool force = false}) async {
    if (_writing) return false;
    if (books.sheetId.isEmpty) return false;

    if (!force && books.lastSyncAt != null) {
      final since = DateTime.now().difference(books.lastSyncAt!);
      if (since < _cooldown) return false;
    }

    _writing = true;
    try {
      final token = await _token(prompt: false);
      if (token == null) {
        _lastError = 'Not allowed to write to the sheet yet.';
        await _record(ok: false);
        return false;
      }

      final tabs = books.tabs;
      await _ensureTabs(books.sheetId, token, tabs.keys.toList());
      await _clear(books.sheetId, token, tabs.keys.toList());
      await _write(books.sheetId, token, tabs);

      _lastError = null;
      await _record(ok: true);
      return true;
    } catch (e) {
      _lastError = '$e';
      debugPrint('Sheet sync failed: $e');
      await _record(ok: false);
      return false;
    } finally {
      _writing = false;
    }
  }

  // ---- Google ----

  static Future<String?> _token({required bool prompt}) async {
    try {
      await AuthService.ensureGoogleReady();
      final google = GoogleSignIn.instance;

      // After a restart Firebase still knows who is signed in, but the Google
      // plugin does not until it is asked.
      await google.attemptLightweightAuthentication();

      final client = google.authorizationClient;
      final granted = await client.authorizationForScopes([scope]);
      if (granted != null) return granted.accessToken;
      if (!prompt) return null;
      return (await client.authorizeScopes([scope])).accessToken;
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  /// Adds any tab the Sheet does not have yet, and leaves every other tab —
  /// including whatever the farm has built for itself — alone.
  static Future<void> _ensureTabs(
    String id,
    String token,
    List<String> wanted,
  ) async {
    final res = await http.get(
      Uri.parse('$_api/$id?fields=sheets.properties.title'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) {
      throw Exception('Could not read the sheet (${res.statusCode})');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final have = ((body['sheets'] as List?) ?? const [])
        .map((s) => ((s as Map)['properties'] as Map)['title'] as String)
        .toSet();

    final missing = wanted.where((t) => !have.contains(t)).toList();
    if (missing.isEmpty) return;

    final add = await http.post(
      Uri.parse('$_api/$id:batchUpdate'),
      headers: _headers(token),
      body: jsonEncode({
        'requests': [
          for (final title in missing)
            {
              'addSheet': {
                'properties': {'title': title},
              },
            },
        ],
      }),
    );
    if (add.statusCode != 200) {
      throw Exception('Could not add the tabs (${add.statusCode})');
    }
  }

  /// Empties the app's own tabs before writing, so a deleted entry actually
  /// disappears instead of being left behind under the new rows.
  static Future<void> _clear(String id, String token, List<String> tabs) async {
    final res = await http.post(
      Uri.parse('$_api/$id/values:batchClear'),
      headers: _headers(token),
      body: jsonEncode({
        'ranges': [for (final t in tabs) "'$t'!A1:Z10000"],
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Could not clear the tabs (${res.statusCode})');
    }
  }

  static Future<void> _write(
    String id,
    String token,
    Map<String, List<List<String>>> tabs,
  ) async {
    final res = await http.post(
      Uri.parse('$_api/$id/values:batchUpdate'),
      headers: _headers(token),
      body: jsonEncode({
        // The Sheet reads dates as dates and rupees as numbers this way, which
        // is what lets the farm chart them without touching anything.
        'valueInputOption': 'USER_ENTERED',
        'data': [
          for (final tab in tabs.entries)
            {
              'range': "'${tab.key}'!A1",
              'majorDimension': 'ROWS',
              'values': tab.value,
            },
        ],
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Could not write the rows (${res.statusCode})');
    }
  }

  static Future<void> _record({required bool ok}) async {
    try {
      await Db.farmSettings.set({
        'lastSyncAt': FieldValue.serverTimestamp(),
        'syncOk': ok,
        if (!ok && _lastError != null) 'syncError': _lastError,
        if (ok) 'syncError': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {
      // The Sheet is written either way; this is only the status light.
    }
  }
}

/// Everything the Sheet shows, gathered once so the writer has no opinions
/// about where any of it came from.
///
/// Each tab is a header row and then the rows themselves — nothing merged,
/// nothing formatted, one thing per column. That is what lets the farm build
/// its own tables and charts on top without fighting the layout.
class SheetBooks {
  const SheetBooks({
    required this.sheetId,
    required this.lastSyncAt,
    required this.txns,
    required this.periods,
    required this.partners,
    required this.ratios,
    required this.khaata,
    required this.deliveries,
    required this.animals,
    required this.summary,
  });

  final String sheetId;
  final DateTime? lastSyncAt;

  final List<Txn> txns;
  final List<FarmMonth> periods;
  final List<Partner> partners;
  final Map<String, double> ratios;
  final List<UdhaarAccount> khaata;
  final List<Delivery> deliveries;
  final List<Animal> animals;
  final List<(String, num)> summary;

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _n(num? v) => v == null ? '' : v.toString();

  Map<String, List<List<String>>> get tabs => {
    'Summary': [
      ['What', 'Rupees'],
      for (final (label, value) in summary) [label, _n(value)],
    ],

    'Entries': [
      [
        'Date',
        'Period',
        'Type',
        'In or out',
        'Party',
        'Category',
        'Quantity',
        'Unit',
        'Rate',
        'Amount',
        'Paid',
        'How',
        'Handled by',
        'Note',
      ],
      for (final t in txns)
        [
          _date(t.date),
          t.monthId,
          t.type.label,
          t.type.isIncoming ? 'In' : 'Out',
          t.party,
          t.category,
          _n(t.qty),
          t.unit ?? '',
          _n(t.rate),
          _n(t.amount),
          t.paid ? 'Yes' : 'No',
          t.paid ? t.payVia.label : '',
          t.handledBy,
          t.note,
        ],
    ],

    'Periods': [
      [
        'Period',
        'From',
        'To',
        'State',
        'Sales',
        'Running costs',
        'Cattle & equipment',
        'Profit',
        'Shared out',
        'Closed on',
      ],
      for (final p in periods)
        [
          periodLabel(p),
          p.from == null ? '' : _date(p.from!),
          p.to == null ? '' : _date(p.to!),
          p.status,
          _n(p.sales),
          _n((p.purchases ?? 0) + (p.expenses ?? 0) - (p.assets ?? 0)),
          _n(p.assets),
          _n(p.profit),
          _n(p.profitShared),
          p.closedAt == null ? '' : _date(p.closedAt!),
        ],
    ],

    'Co-founders': [
      [
        'Name',
        'Email',
        'Put in',
        'Left in from profit',
        'Capital',
        'Share %',
        'Taken out',
      ],
      for (final p in partners)
        [
          p.name,
          p.email,
          _n(p.invested),
          _n(p.reinvested),
          _n(p.capital),
          ((ratios[p.id] ?? 0) * 100).toStringAsFixed(1),
          _n(p.withdrawn),
        ],
    ],

    if (khaata.isNotEmpty)
      'Khaata': [
        [
          'Customer',
          'Mobile',
          'Litres a day',
          'Round',
          'Rate',
          'Balance',
          'State',
        ],
        for (final k in khaata)
          [
            k.name,
            k.mobile,
            _n(k.litresPerDay),
            k.slot,
            _n(k.rate),
            _n(k.balance),
            k.status.label,
          ],
      ],

    if (deliveries.isNotEmpty)
      'Deliveries': [
        [
          'Date',
          'Customer',
          'Litres',
          'Rate',
          'Amount',
          'Round',
          'Marked by',
          'Billed',
        ],
        for (final d in deliveries)
          [
            _date(d.date),
            d.customerName,
            _n(d.litres),
            _n(d.rate),
            _n(d.amount),
            d.slot,
            d.deliveredByName,
            d.billed ? 'Yes' : 'No',
          ],
      ],

    if (animals.isNotEmpty)
      'Cattle': [
        [
          'Tag',
          'Name',
          'Kind',
          'State',
          'Litres a day',
          'Bought for',
          'Bought on',
        ],
        for (final a in animals)
          [
            a.tag,
            a.name,
            a.species.label,
            a.status.name,
            _n(a.dailyLitres),
            _n(a.price),
            a.boughtOn == null ? '' : _date(a.boughtOn!),
          ],
      ],
  };
}
