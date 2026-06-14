import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/listing_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';

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

/// Create an Offer (`properties`) or a Demand (`requests`).
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key, required this.kind});

  final ListingKind kind;

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerName = TextEditingController();
  final _ownerMobile = TextEditingController();
  final _projectName = TextEditingController();
  final _area = TextEditingController();

  PropertyType _propertyType = PropertyType.apartment;
  bool _isPublic = true;
  bool _busy = false;
  String? _error;

  bool get _isOffer => widget.kind == ListingKind.offer;

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
    final listing = PropertyListing(
      id: '',
      companyId: user.companyId,
      agentId: user.agentId,
      kind: widget.kind,
      ownerName: _ownerName.text.trim(),
      ownerMobile: _ownerMobile.text.trim(),
      projectName: _projectName.text.trim(),
      propertyType: _propertyType,
      area: num.tryParse(_area.text.trim()) ?? 0,
      isPublic: _isPublic,
      // Denormalized creator contact for the Global Market.
      agentName: user.displayName,
      agentPhone: user.phone,
      createdAt: DateTime.now(),
      branch: user.branch,
    );
    try {
      await ref.read(listingRepositoryProvider).create(listing);
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
          _isOffer ? 'خستنەڕووی نوێ' : 'داواکاری نوێ',
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
                // ئایکۆنی سەرەوە
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentYellow.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isOffer ? Icons.maps_home_work_outlined : Icons.person_search_outlined,
                      size: 48,
                      color: accentYellow,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

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
                    onChanged: (v) => setState(() => _propertyType = v ?? PropertyType.apartment),
                  ),
                ),

                _text(_area, 'ڕووبەر (م²)', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.square_foot),

                const SizedBox(height: 8),

                // بەشی بازاڕی گشتی بە دیزاینێکی مۆدێرنتر
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isPublic ? primaryDarkBlue.withValues(alpha: 0.05) : inputFillColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPublic ? primaryDarkBlue.withValues(alpha: 0.2) : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'پیشاندان لە بازاڕی گشتی',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDarkBlue),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ناو و مۆبایلی خاوەن بە شاردراوەیی دەمێنێتەوە بۆ پاراستنی تایبەتمەندی.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: _isPublic,
                        activeThumbColor: Colors.white,
                        activeTrackColor: primaryDarkBlue,
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade200,
                        onChanged: (v) => setState(() => _isPublic = v),
                      ),
                    ],
                  ),
                ),

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
                      : const Text('دروستکردن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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