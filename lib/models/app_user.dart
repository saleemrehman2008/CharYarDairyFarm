import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers.dart';

enum Role {
  master,
  investor,
  customer;

  static Role parse(Object? v) => switch (s(v)) {
    'master' => Role.master,
    'investor' => Role.investor,
    _ => Role.customer,
  };

  String get label => switch (this) {
    Role.master => 'Master',
    Role.investor => 'Co-founder',
    Role.customer => 'Customer',
  };

  /// Master and co-founders share the farm-side screens.
  bool get isStaff => this == Role.master || this == Role.investor;
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

class AppUser {
  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.role,
    required this.status,
    this.partnerId,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final Role role;
  final UserStatus status;
  final String? partnerId;
  final DateTime createdAt;

  bool get canOrder => status == UserStatus.active;
  bool get isBlocked => status == UserStatus.blocked;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: s(m['name']).isEmpty ? s(m['email']).split('@').first : s(m['name']),
      email: s(m['email']),
      photoUrl: s(m['photoUrl']),
      role: Role.parse(m['role']),
      status: UserStatus.parse(m['status']),
      partnerId: m['partnerId'] == null ? null : s(m['partnerId']),
      createdAt: dtOr(m['createdAt']),
    );
  }
}
