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

/// What came of trying to write the Sheet.
enum SyncResult {
  /// The Sheet now matches the app.
  written,

  /// Another phone had just written, or one write was already running. The
  /// change is still only in the app, so this is tried again.
  skipped,

  /// It was attempted and did not work — no signal, or Google said no.
  failed,

  /// No sheet linked, or the permission has never been granted. Nothing to
  /// retry: somebody has to do something first.
  notReady,
}

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
  /// Declared where the sign-in is, because that is where it is now asked
  /// for — a second copy of the string is a second thing to get wrong.
  static const scope = AuthService.sheetsScope;

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
  static Timer? _retry;
  static bool _writing = false;
  static String? _lastError;

  /// The last token Google gave us, and when it stops working.
  ///
  /// Kept because asking Google again is not free: on a phone with more than
  /// one Google account the ask can put the account picker on the screen, and
  /// the Sheet is written every time anything changes. Four taps to sign in
  /// once was the farm's experience of that. A token lasts about an hour;
  /// this throws it away early so a write never fails on a stale one.
  static String? _cached;
  static DateTime? _cachedUntil;

  /// Whether the plugin has been woken up this run.
  ///
  /// After a restart Firebase still knows who is signed in and the Google
  /// plugin does not, so it has to be asked once. Asked more than once, on a
  /// phone carrying several Google accounts, it stops being able to pick
  /// silently and shows the picker — which is what was happening on every
  /// single write.
  static bool _woken = false;

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
  ///
  /// A write that does not happen is tried again. Without that, a change made
  /// inside another phone's cooldown — or while the signal was gone — would
  /// never reach the Sheet at all, and the two would stay apart until somebody
  /// happened to change something else.
  static void nudge(Future<SheetBooks> Function() read) {
    _timer?.cancel();
    _timer = Timer(_settle, () => _attempt(read));
  }

  /// Writes now, whatever another phone has just done.
  ///
  /// Used when an app opens: whatever happened while every partner's phone was
  /// shut — a rider's round, a customer's order — is in the books and not in
  /// the Sheet, and the first partner to open the app puts that right.
  static void catchUp(Future<SheetBooks> Function() read) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(seconds: 2),
      () => _attempt(read, force: true),
    );
  }

  static Future<void> _attempt(
    Future<SheetBooks> Function() read, {
    bool force = false,
  }) async {
    _retry?.cancel();
    _retry = null;
    try {
      final result = await push(await read(), force: force);
      // Anything but a write leaves the change in the app and not in the
      // Sheet, so come back to it rather than waiting for the farm to type
      // something else.
      //
      // `notReady` is in here for a reason that cost three days of a stale
      // Sheet. On a cold start the Google plugin has not restored the account
      // yet, so the permission check comes back empty and this gives up — and
      // because the catch-up only runs once per launch, nothing tried again.
      // The screen meanwhile asked the same question a few seconds later, got
      // a token, and quite correctly hid the button offering to fix it. The
      // farm was left looking at a permission error it did not have, on a
      // Sheet that would not move.
      if (result != SyncResult.written) {
        _retry = Timer(_cooldown, () => _attempt(read, force: force));
      }
    } catch (e) {
      _lastError = '$e';
      _retry = Timer(_cooldown, () => _attempt(read));
    }
  }

  static void stop() {
    _timer?.cancel();
    _retry?.cancel();
    _timer = null;
    _retry = null;
    // Somebody else may sign in next. Their Sheet is not this one's.
    _cached = null;
    _cachedUntil = null;
    _woken = false;
  }

  /// Writes the books into the Sheet.
  ///
  /// Says which of the four things happened, because the caller has to know
  /// whether to come back to it: a skipped or failed write leaves the Sheet
  /// behind the app, and that is the one state this is meant to prevent.
  static Future<SyncResult> push(SheetBooks books, {bool force = false}) async {
    if (books.sheetId.isEmpty) return SyncResult.notReady;
    if (_writing) return SyncResult.skipped;

    if (!force && books.lastSyncAt != null) {
      final since = DateTime.now().difference(books.lastSyncAt!);
      if (since < _cooldown) return SyncResult.skipped;
    }

    _writing = true;
    try {
      final token = await _token(prompt: false);
      if (token == null) {
        // Not recorded as a failure. On a cold start this is usually the
        // Google plugin not being awake yet rather than a permission the farm
        // has not given, and writing it down puts a red line on the settings
        // screen that stays there long after it stopped being true — next to
        // a button that has correctly disappeared, because by the time the
        // screen asked, the answer was yes.
        _lastError = 'Not allowed to write to the sheet yet.';
        return SyncResult.notReady;
      }

      final tabs = books.tabs;
      await _ensureTabs(books.sheetId, token, tabs.keys.toList());
      await _clear(books.sheetId, token, tabs.keys.toList());
      await _write(books.sheetId, token, tabs);

      _lastError = null;
      await _record(ok: true);
      return SyncResult.written;
    } catch (e) {
      _lastError = '$e';
      debugPrint('Sheet sync failed: $e');
      await _record(ok: false);
      return SyncResult.failed;
    } finally {
      _writing = false;
    }
  }

  // ---- Google ----

  static Future<String?> _token({required bool prompt}) async {
    final held = _cached;
    final until = _cachedUntil;
    if (held != null && until != null && DateTime.now().isBefore(until)) {
      return held;
    }

    try {
      await AuthService.ensureGoogleReady();
      final google = GoogleSignIn.instance;
      final client = google.authorizationClient;

      // Ask for the token first. If the account has already granted the
      // permission and the plugin knows who it is, this needs no waking and
      // shows nothing.
      var granted = await client.authorizationForScopes([scope]);

      // Only if that came back empty is the plugin worth waking — and only
      // once, because waking it again is what puts the picker on screen.
      if (granted == null && (!_woken || prompt)) {
        _woken = true;
        await google.attemptLightweightAuthentication();
        granted = await client.authorizationForScopes([scope]);
      }

      if (granted == null) {
        if (!prompt) return null;
        granted = await client.authorizeScopes([scope]);
      }
      return _keep(granted.accessToken);
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  /// Holds on to a token for a while, and hands it back.
  ///
  /// Fifty minutes against Google's hour, so a write that starts just inside
  /// the window does not finish just outside it.
  static String _keep(String token) {
    _cached = token;
    _cachedUntil = DateTime.now().add(const Duration(minutes: 50));
    return token;
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

  /// Every tab, every time — even the empty ones.
  ///
  /// They used to be left out when the farm had nothing in them, which read
  /// as tidy and was wrong: a tab is only emptied if it is in this list, so
  /// the day the last animal was removed its tab stopped being rewritten and
  /// kept showing the animals that were no longer there. An empty tab with a
  /// header row on it is honest; a stale one is not.
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
        'Entered by',
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
          t.createdByName,
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
          _n(p.profitHeld),
          _n(p.inTheFarm),
          ((ratios[p.id] ?? 0) * 100).toStringAsFixed(1),
          _n(p.withdrawn),
        ],
    ],

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
