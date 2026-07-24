import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/listing_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';
import '../widgets/house_image_picker.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);
const Color inputFillColor = Color(0xFFF3F4F6);

// فەنکشن بۆ دیزاینی فۆڕمەکان
InputDecoration modernInputDecoration({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: primaryDarkBlue, size: 22) : null,
    filled: true,
    fillColor: inputFillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: accentYellow, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.red.shade300, width: 1),
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

  PropertyType _propertyType = PropertyType.house;
  DealKind _deal = DealKind.sale;
  // The Global Market is held back for now, so nothing publishes to it — the
  // listing is always private and the public toggle is gone from the form.
  final bool _isPublic = false;
  bool _busy = false;
  String? _error;

  Uint8List? _imageBytes;
  String _imageContentType = 'image/jpeg';

  bool get _isOffer => widget.kind == ListingKind.offer;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    _ownerName.text = e.ownerName;
    _ownerMobile.text = e.ownerMobile;
    _projectName.text = e.projectName;
    _area.text = '${e.area}';
    _propertyType = e.propertyType;
    _deal = e.deal;
  }

  @override
  void dispose() {
    _ownerName.dispose();
    _ownerMobile.dispose();
    _projectName.dispose();
    _area.dispose();
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
      imageUrl: old?.imageUrl ?? '',
      city: old?.city ?? user.city,
    );
    try {
      final repo = ref.read(listingRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          listing,
          imageBytes: _imageBytes,
          imageContentType: _imageContentType,
        );
      } else {
        await repo.create(
          listing,
          imageBytes: _imageBytes,
          imageContentType: _imageContentType,
        );
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
              ? (_isOffer ? 'دەستکاری خستنەڕوو' : 'دەستکاری داواکاری')
              : (_isOffer ? 'خستنەڕووی نوێ' : 'داواکاری نوێ'),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                // وێنەی خانوو (ئارەزوومەندانە) — لە کامێرا یان گەلەری
                Center(
                  child: HouseImagePicker(
                    initialImageUrl: widget.existing?.imageUrl ?? '',
                    onChanged: (bytes, contentType) => setState(() {
                      _imageBytes = bytes;
                      _imageContentType = contentType;
                    }),
                  ),
                ),
                const SizedBox(height: 32),

                // فرۆشتن یان کرێ — سەرەتای فۆڕمەکە، چونکە هەموو شتەکانی تری
                // خوارەوە بەپێی ئەم هەڵبژاردنە لێکدەدرێنەوە.
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<DealKind>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: inputFillColor,
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: primaryDarkBlue,
                      side: BorderSide(color: Colors.grey.shade200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: DealKind.sale,
                        label: Text('فرۆشتن',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        icon: Icon(Icons.sell_outlined),
                      ),
                      ButtonSegment(
                        value: DealKind.rent,
                        label: Text('کرێ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        icon: Icon(Icons.vpn_key_outlined),
                      ),
                    ],
                    selected: {_deal},
                    onSelectionChanged: (s) => setState(() => _deal = s.first),
                  ),
                ),

                const SizedBox(height: 24),

                _text(_ownerName, 'ناوی خاوەن', icon: Icons.person_outline),
                _text(_ownerMobile, 'مۆبایلی خاوەن', keyboard: TextInputType.phone, icon: Icons.phone_iphone),

                const Divider(height: 32),

                _text(_projectName, 'پڕۆژە / گەڕەک', icon: Icons.location_city_outlined),

                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<PropertyType>(
                    isExpanded: true,
                    initialValue: _propertyType,
                    decoration: modernInputDecoration(label: 'جۆری موڵک', icon: Icons.home_work_outlined),
                    items: PropertyType.values
                        .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _propertyType = v ?? PropertyType.house),
                  ),
                ),

                _text(_area, 'ڕووبەر (م²)', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.square_foot),

                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
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
                      : Text(_isEdit ? 'پاشەکەوتکردن' : 'دروستکردن',
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

  Widget _text(TextEditingController c, String label, {TextInputType? keyboard, IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: c,
          keyboardType: keyboard,
          decoration: modernInputDecoration(label: label, icon: icon),
          validator: _req,
        ),
      );

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'پێویستە' : null;
}