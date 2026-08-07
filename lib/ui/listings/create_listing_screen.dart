import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/listing_repository.dart';
import '../../data/plan_config_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';
import '../widgets/house_gallery_picker.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get appBackgroundColor => AppColors.current.pageBg;
Color get inputFillColor => AppColors.current.inputFill;

// فەنکشن بۆ دیزاینی فۆڕمەکان
InputDecoration modernInputDecoration({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppColors.current.textMuted, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.current.textStrong, size: 22) : null,
    filled: true,
    fillColor: inputFillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.current.divider, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accentYellow, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.current.danger, width: 1),
    ),
  );
}

// فەنکشن بۆ دیزاینی دوگمە سەرەکییەکان
ButtonStyle modernButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: primaryDarkBlue,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 2,
  );
}

/// Create — or, when [existing] is passed, edit — an Offer (`properties`) or a
/// Demand (`requests`).
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key, required this.kind, this.existing});

  final ListingKind kind;

  /// The listing being edited, or null when creating a new one.
  final PropertyListing? existing;

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerName = TextEditingController();
  final _ownerMobile = TextEditingController();
  final _projectName = TextEditingController();
  final _area = TextEditingController();
  final _price = TextEditingController();
  final _rooms = TextEditingController();
  final _bathrooms = TextEditingController();
  final _floors = TextEditingController();

  PropertyType _propertyType = PropertyType.house;
  DealKind _deal = DealKind.sale;
  Currency _currency = Currency.usd;

  /// Once the user picks a currency themselves, switching فرۆشتن/کرێ stops
  /// overriding it — otherwise their choice would silently revert.
  bool _currencyTouched = false;

  /// Opt-in publication to the cross-company Global Market. Off by default:
  /// a listing is the company's own until someone decides to share it.
  ///
  /// What actually leaves the company is the owner-free projection in
  /// `_marketData` — property details, price, photos and the AGENT's name and
  /// phone. The owner's name and mobile never go, and the security rules
  /// reject a market document that carries them.
  bool _isPublic = false;
  bool _busy = false;
  String? _error;

  /// The gallery as the form holds it — stored photos and fresh picks mixed,
  /// in display order. Seeded from the listing being edited.
  late List<ListingImage> _images =
      (widget.existing?.imageUrls ?? const <String>[])
          .map(ListingImage.stored)
          .toList();

  bool get _isOffer => widget.kind == ListingKind.offer;
  bool get _isEdit => widget.existing != null;

  /// Land has no rooms, bathrooms or storeys to count, and asking for them
  /// invites junk data.
  bool get _hasBuilding => _propertyType != PropertyType.land;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _currency = _defaultCurrency(_deal);
      return;
    }
    _ownerName.text = e.ownerName;
    _ownerMobile.text = e.ownerMobile;
    _projectName.text = e.projectName;
    _area.text = '${e.area}';
    if (e.price > 0) _price.text = '${e.price}';
    if (e.rooms > 0) _rooms.text = '${e.rooms}';
    if (e.bathrooms > 0) _bathrooms.text = '${e.bathrooms}';
    if (e.floors > 0) _floors.text = '${e.floors}';
    _propertyType = e.propertyType;
    _deal = e.deal;
    _isPublic = e.isPublic;
    _currency = e.currency;
    // A saved listing already carries a deliberate currency; never overwrite it.
    _currencyTouched = true;
  }

  /// Sale prices are quoted in dollars here and rents in dinars, so the field
  /// opens on whichever the agent is about to type.
  Currency _defaultCurrency(DealKind deal) =>
      deal == DealKind.rent ? Currency.iqd : Currency.usd;

  @override
  void dispose() {
    _ownerName.dispose();
    _ownerMobile.dispose();
    _projectName.dispose();
    _area.dispose();
    _price.dispose();
    _rooms.dispose();
    _bathrooms.dispose();
    _floors.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final user = ref.read(currentUserProvider);
    final old = widget.existing;
    final listing = PropertyListing(
      id: old?.id ?? '',
      companyId: old?.companyId ?? user.companyId,
      // On an edit these stay as first saved: the creator owns the listing, and
      // the branch is pinned by the security rules anyway.
      agentId: old?.agentId ?? user.agentId,
      kind: widget.kind,
      deal: _deal,
      ownerName: _ownerName.text.trim(),
      ownerMobile: _ownerMobile.text.trim(),
      projectName: _projectName.text.trim(),
      propertyType: _propertyType,
      area: num.tryParse(_area.text.trim()) ?? 0,
      isPublic: _isPublic,
      isArchived: old?.isArchived ?? false,
      // Denormalized creator contact for the Global Market.
      agentName: old?.agentName ?? user.displayName,
      agentPhone: old?.agentPhone ?? user.phone,
      createdAt: old?.createdAt ?? DateTime.now(),
      branch: old?.branch ?? user.branch,
      // The repository owns the gallery: it uploads the picks, deletes what was
      // removed and writes the resulting URLs itself.
      imageUrls: old?.imageUrls ?? const [],
      city: old?.city ?? user.city,
      price: num.tryParse(_price.text.trim()) ?? 0,
      currency: _currency,
      rooms: _hasBuilding ? (int.tryParse(_rooms.text.trim()) ?? 0) : 0,
      bathrooms: _hasBuilding ? (int.tryParse(_bathrooms.text.trim()) ?? 0) : 0,
      floors: _hasBuilding ? (int.tryParse(_floors.text.trim()) ?? 0) : 0,
    );
    try {
      final repo = ref.read(listingRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          listing,
          images: _images,
          previousImageUrls: old!.imageUrls,
        );
      } else {
        await repo.create(listing, images: _images);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEdit
              ? (_isOffer ? S.editOfferTitle : S.editDemandTitle)
              : (_isOffer ? S.newOffer : S.newDemand),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.current.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.current.shadow,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // گەلەری وێنەکان (ئارەزوومەندانە) — لە کامێرا یان گەلەری.
                // تەنها بۆ خستنەڕوو: داواکارییەکی موشتەر موڵکێکی دیاریکراوی
                // نییە کە وێنەی هەبێت.
                if (_isOffer) ...[
                  HouseGalleryPicker(
                    initial: widget.existing?.imageUrls ?? const [],
                    onChanged: (images) => _images = images,
                  ),
                  const SizedBox(height: 28),
                ],

                // فرۆشتن یان کرێ — سەرەتای فۆڕمەکە، چونکە هەموو شتەکانی تری
                // خوارەوە بەپێی ئەم هەڵبژاردنە لێکدەدرێنەوە.
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<DealKind>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: inputFillColor,
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: primaryDarkBlue,
                      side: BorderSide(color: AppColors.current.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    segments: [
                      ButtonSegment(
                        value: DealKind.sale,
                        label: Text(DealKind.sale.labelFor(widget.kind),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        icon: const Icon(Icons.sell_outlined),
                      ),
                      ButtonSegment(
                        value: DealKind.rent,
                        label: Text(DealKind.rent.labelFor(widget.kind),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        icon: const Icon(Icons.vpn_key_outlined),
                      ),
                    ],
                    selected: {_deal},
                    onSelectionChanged: (s) => setState(() {
                      _deal = s.first;
                      if (!_currencyTouched) _currency = _defaultCurrency(_deal);
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                _text(_ownerName, S.ownerName, icon: Icons.person_outline),
                _text(_ownerMobile, S.ownerMobile, keyboard: TextInputType.phone, icon: Icons.phone_iphone),

                const Divider(height: 32),

                _text(_projectName, S.projectOrNeighborhood, icon: Icons.location_city_outlined),

                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<PropertyType>(
                    isExpanded: true,
                    initialValue: _propertyType,
                    decoration: modernInputDecoration(label: S.propertyTypeLabel, icon: Icons.home_work_outlined),
                    items: PropertyType.values
                        .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _propertyType = v ?? PropertyType.house),
                  ),
                ),

                _text(_area, S.areaLabel, keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.square_foot),

                // نرخ + دراو — نرخ ئارەزوومەندانەیە، چونکە هەندێک خاوەن
                // لەسەرەتادا نرخ ناڵێن. لەگەڵ ژوور و حەمام تەنها بۆ
                // خستنەڕوون؛ بۆ داواکاری دەبنە بودجە و پێداویستی، کە
                // بەشێکی جیاوازە.
                if (_isOffer) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _text(
                          _price,
                          _deal == DealKind.rent ? S.monthlyRentField : S.priceField,
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true),
                          icon: Icons.payments_outlined,
                          optional: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<Currency>(
                            isExpanded: true,
                            initialValue: _currency,
                            decoration: modernInputDecoration(label: S.currencyField),
                            items: Currency.values
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.symbol,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _currency = v ?? _currency;
                              _currencyTouched = true;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ژوور، حەمام و قات — بۆ زەوی مانایان نییە، بۆیە
                  // دەشاردرێنەوە. ناونیشانەکان کورتن چونکە سێکیان لە یەک
                  // ڕیزدان؛ ئایکۆنەکان مانایان ڕوون دەکەنەوە.
                  if (_hasBuilding)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _text(_rooms, S.roomsField,
                              keyboard: TextInputType.number,
                              icon: Icons.bed_outlined,
                              optional: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _text(_bathrooms, S.bathroomsField,
                              keyboard: TextInputType.number,
                              icon: Icons.bathtub_outlined,
                              optional: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _text(_floors, S.floorsField,
                              keyboard: TextInputType.number,
                              icon: Icons.layers_outlined,
                              optional: true),
                        ),
                      ],
                    ),
                ],

                // بڵاوکردنەوە لە بازاڕی گشتی — تەنها بۆ پلانەکانی کە
                // بازاڕیان هەیە (سیلڤەر بەرەوژوور).
                if (ref.watch(currentPlanFeaturesProvider).market)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: inputFillColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _isPublic
                              ? accentYellow
                              : AppColors.current.divider,
                          width: _isPublic ? 2 : 1),
                    ),
                    child: SwitchListTile(
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      activeThumbColor: AppColors.current.textStrong,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      secondary:
                          Icon(Icons.public, color: AppColors.current.textStrong),
                      title: Text(S.publishToMarket,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        '${S.publishVisibleIn(ref.watch(currentUserProvider).city.uiLabel)}\n'
                        '${S.publishPrivacyNote}',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.current.textMuted),
                      ),
                    ),
                  ),

                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.current.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppColors.current.danger, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: modernButtonStyle(),
                  child: _busy
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(_isEdit ? S.save : S.create,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    IconData? icon,
    bool optional = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: c,
          keyboardType: keyboard,
          decoration: modernInputDecoration(label: label, icon: icon),
          validator: optional ? null : _req,
        ),
      );

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? S.requiredField : null;
}