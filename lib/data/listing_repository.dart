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
          {required String city, required List<String> imageUrls}) =>
      {
        'company_id': l.companyId,
        'listing_kind': l.kind.wire,
        'deal_kind': l.deal.wire,
        'property_type': l.propertyType.wire,
        'project_name': l.projectName,
        'area': l.area,
        'price': l.price,
        'currency': l.currency.wire,
        'rooms': l.rooms,
        'bathrooms': l.bathrooms,
        'floors': l.floors,
        'agent_name': l.agentName,
        'agent_phone': l.agentPhone,
        'city': city,
        'image_urls': imageUrls,
        // Cover kept under the old key too, for clients still on the
        // single-image build. See PropertyListing.toJson.
        'image_url': imageUrls.isEmpty ? '' : imageUrls.first,
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
      await _deleteMarketDoc(id);
    } else {
      final snap = await _col(kind).doc(id).get();
      if (!snap.exists) return;
      final l = PropertyListing.fromJson(snap.id, snap.data()!);
      if (l.isPublic) {
        await _market
            .doc(id)
            .set(_marketData(l, city: l.city.wire, imageUrls: l.imageUrls));
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

  /// Brings the stored gallery in line with what the form now holds: uploads
  /// every fresh pick, keeps the already-stored ones in the order given, and
  /// deletes the objects that were dropped. Returns the new URL list, cover
  /// first.
  ///
  /// Object names carry a timestamp rather than the photo's position, so
  /// re-ordering or replacing a photo can never overwrite an object another
  /// entry in the same gallery still points at.
  ///
  /// The flat `<listingId>_<millis>_<n>` shape is deliberate: the Storage rule
  /// for `property_images/{companyId}/{fileName}` matches exactly one path
  /// segment, so a nested folder per listing would fall through to the
  /// deny-all rule.
  Future<List<String>> _syncImages(
    String listingId,
    List<ListingImage> images,
    List<String> previous,
  ) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final urls = <String>[];
    var i = 0;

    for (final image in images.take(kMaxListingImages)) {
      if (!image.isNew) {
        urls.add(image.url);
        continue;
      }
      final ref = FirebaseStorage.instance
          .ref('property_images/${_user.companyId}/${listingId}_${stamp}_${i++}');
      await ref.putData(
        image.bytes!,
        SettableMetadata(contentType: image.contentType),
      );
      urls.add(await ref.getDownloadURL());
    }

    for (final old in previous) {
      if (!urls.contains(old)) await _deleteObject(old);
    }
    return urls;
  }

  /// Best-effort delete of one stored image. A listing may reference an object
  /// that is already gone (a failed upload, a manual cleanup), and that must
  /// never fail the edit or delete that triggered it.
  Future<void> _deleteObject(String url) async {
    if (url.isEmpty) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {
      // Already gone, or not a Storage URL we own.
    }
  }

  /// Applies an edit to an existing listing.
  ///
  /// Only the fields the form owns are written — `company_id`, `branch`,
  /// `agent_id` and `created_at` stay as first saved, both because the rules
  /// pin the first two and because re-stamping the creator would misattribute
  /// the listing to whoever edited it.
  ///
  /// [images] is the gallery exactly as the form left it — already-stored
  /// photos and fresh picks in display order. Anything the user removed is
  /// deleted from Storage. The public `market` projection is rewritten to
  /// match, or dropped if the listing stopped being public.
  Future<void> update(
    PropertyListing listing, {
    List<ListingImage> images = const [],
    required List<String> previousImageUrls,
  }) async {
    final imageUrls =
        await _syncImages(listing.id, images, previousImageUrls);
    await _col(listing.kind).doc(listing.id).update({
      'deal_kind': listing.deal.wire,
      'owner_name': listing.ownerName,
      'owner_mobile': listing.ownerMobile,
      'project_name': listing.projectName,
      'property_type': listing.propertyType.wire,
      'area': listing.area,
      'price': listing.price,
      'currency': listing.currency.wire,
      'rooms': listing.rooms,
      'bathrooms': listing.bathrooms,
      'floors': listing.floors,
      'is_public': listing.isPublic,
      'image_urls': imageUrls,
      'image_url': imageUrls.isEmpty ? '' : imageUrls.first,
    });
    // Archived listings are absent from the market by design; re-publishing one
    // here would resurrect it behind the archive filter.
    if (listing.isPublic && !listing.isArchived) {
      await _market.doc(listing.id).set(
          _marketData(listing, city: _user.city.wire, imageUrls: imageUrls));
    } else {
      await _deleteMarketDoc(listing.id);
    }
  }

  /// Deletes a listing's market projection, tolerating its absence.
  ///
  /// A private listing has no market doc, and the delete rule reads
  /// `resource.data.company_id` — which errors on a missing document and
  /// surfaces as permission-denied. That must never fail the edit or delete
  /// that called this, so the error is swallowed.
  Future<void> _deleteMarketDoc(String id) async {
    try {
      await _market.doc(id).delete();
    } catch (_) {
      // No market doc for this listing (it was never public).
    }
  }

  /// Removes a listing, its market projection and every photo in its gallery.
  ///
  /// The document is read first so the objects to remove come from what was
  /// actually stored, rather than from a caller's possibly stale copy. Image
  /// deletes are best-effort — a missing object must not block the delete.
  Future<void> delete(ListingKind kind, String id) async {
    final snap = await _col(kind).doc(id).get();
    final data = snap.data();
    final urls = data == null
        ? const <String>[]
        : PropertyListing.imagesFrom(data);

    await _col(kind).doc(id).delete();
    await _deleteMarketDoc(id);
    for (final url in urls) {
      await _deleteObject(url);
    }
  }

  /// Creates a listing with its photo gallery (uploaded first so the document
  /// already carries its `image_urls`).
  Future<String> create(
    PropertyListing listing, {
    List<ListingImage> images = const [],
  }) async {
    final ref = _col(listing.kind).doc();
    final imageUrls = await _syncImages(ref.id, images, const []);
    final data = listing.toJson()
      ..['image_urls'] = imageUrls
      ..['image_url'] = imageUrls.isEmpty ? '' : imageUrls.first
      ..['city'] = _user.city.wire; // denormalize the company's city
    await ref.set(data);
    // Publish an owner-free projection to the public market (only when public).
    if (listing.isPublic) {
      await _market.doc(ref.id).set(
          _marketData(listing, city: _user.city.wire, imageUrls: imageUrls));
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
