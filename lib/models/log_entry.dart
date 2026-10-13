import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

/// Kinds shown as tags on the activity log.
enum LogKind {
  login,
  order,
  transaction,

  /// An entry changed after it was written, and an entry taken out.
  ///
  /// Apart from [transaction], which is an entry being made, because these
  /// two are the ones the four of them will want to read on their own: who
  /// has gone back over the books, how often, and what they moved. Writing
  /// an entry is the ordinary work of the farm; changing one that was
  /// already written is the thing that has to be answerable.
  correction,
  entryDeleted,

  monthClose,
  investment,
  user,
  udhaar,
  products,
  cattle,
  settings;

  static LogKind parse(Object? v) => switch (s(v)) {
    'login' => LogKind.login,
    'order' => LogKind.order,
    'correction' => LogKind.correction,
    'entryDeleted' => LogKind.entryDeleted,
    'monthClose' => LogKind.monthClose,
    'investment' => LogKind.investment,
    'user' => LogKind.user,
    'udhaar' => LogKind.udhaar,
    'products' => LogKind.products,
    'cattle' => LogKind.cattle,
    'settings' => LogKind.settings,
    _ => LogKind.transaction,
  };

  String get label => switch (this) {
    LogKind.login => 'Login',
    LogKind.order => 'Order',
    LogKind.correction => 'Correction',
    LogKind.entryDeleted => 'Entry deleted',
    LogKind.transaction => 'Transaction',
    LogKind.monthClose => 'Month close',
    LogKind.investment => 'Investment',
    LogKind.user => 'User',
    LogKind.udhaar => 'Udhaar',
    LogKind.products => 'Products',
    LogKind.cattle => 'Cattle',
    LogKind.settings => 'Settings',
  };

  /// Whether this line is something done to an entry that already existed.
  bool get changedAnEntry =>
      this == LogKind.correction || this == LogKind.entryDeleted;
}

class LogEntry {
  LogEntry({
    required this.id,
    required this.at,
    required this.uid,
    required this.who,
    required this.kind,
    required this.what,
    this.refType,
    this.refId,
  });

  final String id;
  final DateTime at;
  final String uid;
  final String who;
  final LogKind kind;
  final String what;
  final String? refType;
  final String? refId;

  factory LogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return LogEntry(
      id: doc.id,
      at: dtOr(m['at']),
      uid: s(m['uid']),
      who: s(m['who']),
      kind: LogKind.parse(m['kind']),
      what: s(m['what']),
      refType: m['refType'] == null ? null : s(m['refType']),
      refId: m['refId'] == null ? null : s(m['refId']),
    );
  }
}
