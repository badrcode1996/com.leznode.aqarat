import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/listing_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';

/// Create an Offer (`properties`) or a Demand (`requests`). Same fields for
/// both — [kind] only changes the title and target collection.
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key, required this.kind});

  final ListingKind kind;

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
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
      appBar: AppBar(
        title: Text(_isOffer ? 'خستنەڕووی نوێ' : 'داواکاری نوێ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _ownerName,
                decoration: const InputDecoration(labelText: 'ناوی خاوەن'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerMobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'مۆبایلی خاوەن'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _projectName,
                decoration: const InputDecoration(labelText: 'پڕۆژە / گەرەک'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PropertyType>(
                initialValue: _propertyType,
                decoration: const InputDecoration(labelText: 'جۆری موڵک'),
                items: PropertyType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setState(
                    () => _propertyType = v ?? PropertyType.apartment),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _area,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'ڕووبەر (م²)'),
                validator: _req,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('لە بازاڕی گشتیدا پیشان بدرێت'),
                subtitle: const Text(
                    'ناو و مۆبایلی خاوەن شاردراوە دەمێنێتەوە',
                    style: TextStyle(fontSize: 12)),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('دروستکردن'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'پێویستە' : null;
}
