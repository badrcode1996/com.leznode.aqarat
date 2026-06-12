import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// A user profile. (collection: `users`, doc id == Firebase Auth uid)
///
/// This is the document the security rules read to learn a user's `company_id`
/// and `role`. It is the bridge between Firebase Auth and the tenant model.
class AppUser {
  const AppUser({
    required this.uid,
    required this.companyId,
    required this.role,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.createdAt,
  });

  final String uid;
  final String companyId;
  final UserRole role;
  final String displayName;
  final String email;

  /// The user's OWN phone — shown in the Global Market for listings they post,
  /// and used as the click-to-call contact.
  final String phone;
  final DateTime createdAt;

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) => AppUser(
        uid: uid,
        companyId: json['company_id'] as String? ?? '',
        role: UserRole.fromWire(json['role'] as String?),
        displayName: json['display_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        createdAt:
            (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'role': role.wire,
        'display_name': displayName,
        'email': email,
        'phone': phone,
        'created_at': Timestamp.fromDate(createdAt),
      };
}
