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

  /// The current tenant's own listings (private — full owner data visible),
  /// filtered by archived state. Archived filtering is client-side to avoid an
  /// extra composite index.
  Stream<List<PropertyListing>> watchMyListings(
    ListingKind kind, {
    bool archived = false,
  }) {
    return _col(kind)
        .where('company_id', isEqualTo: _user.companyId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PropertyListing.fromJson(d.id, d.data()))
            .where((l) => l.isArchived == archived)
            .where((l) => !_user.isBranchAdmin || l.branch == _user.branch)
            .toList());
  }

  /// Marks a listing completed (archived) or restores it to active.
  Future<void> setArchived(ListingKind kind, String id, bool archived) {
    return _col(kind).doc(id).update({'is_archived': archived});
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
    return _col(kind)
        .where('is_public', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PropertyListing.fromJson(d.id, d.data()))
            .where((l) => !l.isArchived) // archived listings leave the market
            .where((l) => l.city == _user.city) // same-city only — don't mix
            .map((l) => l.publicView)
            .toList());
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
