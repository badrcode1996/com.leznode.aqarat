import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/lawyer_repository.dart';
import '../../models/lawyer_model.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentYellow = Color(0xFFF8B115);
const Color _appBg = Color(0xFFF5F7FA);

/// Company admin screen to manage lawyers (پارێزەران): name, photo, phone.
/// The list feeds the sale-contract lawyer picker.
class LawyersScreen extends ConsumerWidget {
  const LawyersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lawyersStreamProvider);
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: const Text('پارێزەران',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentYellow,
        foregroundColor: _primaryDarkBlue,
        icon: const Icon(Icons.add),
        label: const Text('پارێزەری نوێ',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openForm(context),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _primaryDarkBlue)),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gavel_rounded, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('هیچ پارێزەرێک زیاد نەکراوە',
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _LawyerCard(lawyer: list[i]),
          );
        },
      ),
    );
  }
}

class _LawyerCard extends ConsumerWidget {
  const _LawyerCard({required this.lawyer});
  final Lawyer lawyer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: _primaryDarkBlue.withValues(alpha: 0.1),
          backgroundImage:
              lawyer.photoUrl.isNotEmpty ? NetworkImage(lawyer.photoUrl) : null,
          child: lawyer.photoUrl.isEmpty
              ? const Icon(Icons.gavel_rounded, color: _primaryDarkBlue)
              : null,
        ),
        title: Text(lawyer.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _primaryDarkBlue)),
        subtitle: Text(lawyer.phone.isEmpty ? '—' : lawyer.phone),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'edit') {
              _openForm(context, existing: lawyer);
            } else if (v == 'delete') {
              _confirmDelete(context, ref, lawyer);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, color: _primaryDarkBlue, size: 20),
                SizedBox(width: 12),
                Text('دەستکاری'),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 12),
                const Text('سڕینەوە'),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, Lawyer lawyer) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('سڕینەوەی پارێزەر',
          style:
              TextStyle(color: _primaryDarkBlue, fontWeight: FontWeight.bold)),
      content: Text('دڵنیایت لە سڕینەوەی «${lawyer.name}»؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child:
              const Text('پاشگەزبوونەوە', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('سڕینەوە'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(lawyerRepositoryProvider).deleteLawyer(lawyer);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }
}

/// Opens the add/edit lawyer form in a bottom sheet.
void _openForm(BuildContext context, {Lawyer? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _LawyerForm(existing: existing),
  );
}

class _LawyerForm extends ConsumerStatefulWidget {
  const _LawyerForm({this.existing});
  final Lawyer? existing;

  @override
  ConsumerState<_LawyerForm> createState() => _LawyerFormState();
}

class _LawyerFormState extends ConsumerState<_LawyerForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');

  Uint8List? _photoBytes;
  String _photoContentType = 'image/jpeg';
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoContentType =
          picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(lawyerRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateLawyer(
          widget.existing!,
          name: _name.text,
          phone: _phone.text,
          photoBytes: _photoBytes,
          photoContentType: _photoContentType,
        );
      } else {
        await repo.addLawyer(
          name: _name.text,
          phone: _phone.text,
          photoBytes: _photoBytes,
          photoContentType: _photoContentType,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('هەڵە: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingPhoto = widget.existing?.photoUrl ?? '';
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'دەستکاری پارێزەر' : 'پارێزەری نوێ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryDarkBlue)),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: _primaryDarkBlue.withValues(alpha: 0.1),
                      backgroundImage: _photoBytes != null
                          ? MemoryImage(_photoBytes!)
                          : (existingPhoto.isNotEmpty
                              ? NetworkImage(existingPhoto)
                              : null) as ImageProvider?,
                      child: (_photoBytes == null && existingPhoto.isEmpty)
                          ? const Icon(Icons.add_a_photo_outlined,
                              color: _primaryDarkBlue, size: 28)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: _accentYellow, shape: BoxShape.circle),
                        child: const Icon(Icons.edit,
                            size: 16, color: _primaryDarkBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'ناوی پارێزەر',
                  prefixIcon: Icon(Icons.person_outline)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'ژمارەی مۆبایل',
                  prefixIcon: Icon(Icons.phone_iphone)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDarkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_isEdit ? 'پاشەکەوتکردن' : 'زیادکردن',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
