import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../models/enums.dart';
import '../models/property_model.dart';

/// Repository for the `properties` (Offers) and `requests` (Demands)
/// collections. Both share [PropertyListing]; [ListingKind] picks the
/// collection name.
class ListingRepository {
  ListingRepository(this._db, this._user);

  final FirebaseFirestore _db;
  final SessionUser _user;

  String _collectionFor(ListingKind kind) =>
      kind == ListingKind.offer ? 'properties' : 'requests';

  CollectionReference<Map<String, dynamic>> _col(ListingKind kind) =>
      _db.collection(_collectionFor(kind));

  /// The public, owner-free market projection (one doc per published listing).
  /// Stored separately so private owner name/phone is NEVER readable
  /// cross-company.
  CollectionReference<Map<String, dynamic>> get _market =>
      _db.collection('market');

  Map<String, dynamic> _marketData(PropertyListing l,
          {required String city, required String imageUrl}) =>
      {
        'company_id': l.companyId,
        'listing_kind': l.kind.wire,
        'property_type': l.propertyType.wire,
        'project_name': l.projectName,
        'area': l.area,
        'agent_name': l.agentName,
        'agent_phone': l.agentPhone,
        'city': city,
        'image_url': imageUrl,
        'created_at': Timestamp.fromDate(l.createdAt),
      };

  /// The current tenant's listings (private — full owner data visible),
  /// filtered by archived state. Everyone except company-wide admins is scoped
  /// to their own branch — enforced here (the `branch ==` clause) AND by a
  /// matching Firestore Security Rule. Archived filtering stays client-side to
  /// avoid an extra composite index.
  Stream<List<PropertyListing>> watchMyListings(
    ListingKind kind, {
    bool archived = false,
  }) {
    var query = _col(kind).where('company_id', isEqualTo: _user.companyId);
    if (!_user.isCompanyWide) {
      query = query.where('branch', isEqualTo: _user.branch);
    }
    return query
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PropertyListing.fromJson(d.id, d.data()))
            .where((l) => l.isArchived == archived)
            .toList());
  }

  /// Marks a listing completed (archived) or restores it to active. The public
  /// market doc is removed while archived and re-published on restore.
  Future<void> setArchived(ListingKind kind, String id, bool archived) async {
    await _col(kind).doc(id).update({'is_archived': archived});
    if (archived) {
      await _market.doc(id).delete();
    } else {
      final snap = await _col(kind).doc(id).get();
      if (!snap.exists) return;
      final l = PropertyListing.fromJson(snap.id, snap.data()!);
      if (l.isPublic) {
        await _market
            .doc(id)
            .set(_marketData(l, city: l.city.wire, imageUrl: l.imageUrl));
      }
    }
  }

  /// GLOBAL MARKET: public listings from ALL companies.
  ///
  /// Returns [PublicListingView] only — owner name/mobile are stripped at the
  /// model boundary so they can never reach the cross-company UI. The query is
  /// intentionally NOT scoped by `company_id`; instead it filters `is_public`.
  ///
  /// Security-rule counterpart required:
  ///   allow read: if resource.data.is_public == true;
  Stream<List<PublicListingView>> watchGlobalMarket(ListingKind kind) {
    // Reads the owner-free `market` collection (cross-company), filtered to the
    // viewer's city. Sorted client-side to avoid a composite index.
    return _market
        .where('listing_kind', isEqualTo: kind.wire)
        .snapshots()
        .map((s) {
      final docs = s.docs
          .where((d) => (d.data()['city'] as String?) == _user.city.wire)
          .toList()
        ..sort((a, b) {
          final ta = a.data()['created_at'] as Timestamp?;
          final tb = b.data()['created_at'] as Timestamp?;
          if (ta == null || tb == null) return 0;
          return tb.compareTo(ta);
        });
      return docs
          .map((d) => PublicListingView.fromMarket(d.id, d.data()))
          .toList();
    });
  }

  /// Uploads a house image and returns its download URL.
  Future<String> _uploadImage(
    String id,
    Uint8List bytes,
    String contentType,
  ) async {
    final ref =
        FirebaseStorage.instance.ref('property_images/${_user.companyId}/$id');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// Creates a listing, optionally with a single house image (uploaded first so
  /// the document already carries its `image_url`).
  Future<String> create(
    PropertyListing listing, {
    Uint8List? imageBytes,
    String imageContentType = 'image/jpeg',
  }) async {
    final ref = _col(listing.kind).doc();
    final imageUrl = imageBytes == null
        ? ''
        : await _uploadImage(ref.id, imageBytes, imageContentType);
    final data = listing.toJson()
      ..['image_url'] = imageUrl
      ..['city'] = _user.city.wire; // denormalize the company's city
    await ref.set(data);
    // Publish an owner-free projection to the public market (only when public).
    if (listing.isPublic) {
      await _market
          .doc(ref.id)
          .set(_marketData(listing, city: _user.city.wire, imageUrl: imageUrl));
    }
    return ref.id;
  }
}

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);
  return ListingRepository(db, user);
});

/// Family by ListingKind so Offers and Demands have independent streams.
final globalMarketProvider =
    StreamProvider.family<List<PublicListingView>, ListingKind>((ref, kind) {
  return ref.watch(listingRepositoryProvider).watchGlobalMarket(kind);
});

final myListingsProvider =
    StreamProvider.family<List<PropertyListing>, ListingKind>((ref, kind) {
  return ref.watch(listingRepositoryProvider).watchMyListings(kind);
});

/// The current tenant's ARCHIVED (completed) listings.
final myArchivedListingsProvider =
    StreamProvider.family<List<PropertyListing>, ListingKind>((ref, kind) {
  return ref
      .watch(listingRepositoryProvider)
      .watchMyListings(kind, archived: true);
});
