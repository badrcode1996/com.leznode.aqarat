import 'package:cloud_firestore/cloud_firestore.dart';

/// A lawyer (پارێزەر) belonging to a company. Managed by the company admin and
/// offered as quick-pick suggestions on the sale contract form. (collection:
/// `lawyers`)
class Lawyer {
  const Lawyer({
    required this.id,
    required this.companyId,
    required this.name,
    required this.phone,
    required this.photoUrl,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String phone;
  final String photoUrl; // '' when no photo uploaded
  final DateTime createdAt;

  factory Lawyer.fromJson(String id, Map<String, dynamic> json) => Lawyer(
        id: id,
        companyId: json['company_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        photoUrl: json['photo_url'] as String? ?? '',
        createdAt:
            (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'name': name,
        'phone': phone,
        'photo_url': photoUrl,
        'created_at': Timestamp.fromDate(createdAt),
      };
}
