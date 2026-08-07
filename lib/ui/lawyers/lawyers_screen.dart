import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/session.dart';
import '../../data/lawyer_repository.dart';
import '../../models/lawyer_model.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _accentYellow => AppColors.current.accent;
Color get _appBg => AppColors.current.pageBg;

/// Company admin screen to manage lawyers (پارێزەران): name, photo, phone.
/// The list feeds the sale-contract lawyer picker.
class LawyersScreen extends ConsumerWidget {
  const LawyersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lawyersStreamProvider);
    // Agents read the directory to pick a lawyer on a sale contract; only a
    // company admin curates it. Mirrored in firestore.rules, so this is a
    // convenience, not the enforcement.
    final isAdmin = ref.watch(currentUserProvider).isAdmin;
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: Text(S.lawyers,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: _accentYellow,
              foregroundColor: AppColors.current.textStrong,
              icon: const Icon(Icons.add),
              label: Text(S.newLawyer,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _openForm(context),
            )
          : null,
      body: async.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.current.textStrong)),
        error: (e, _) => Center(child: Text(S.error(e))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gavel_rounded, size: 56, color: AppColors.current.textMuted),
                    const SizedBox(height: 12),
                    Text(S.noLawyers,
                        style: TextStyle(
                            color: AppColors.current.textMuted, fontWeight: FontWeight.bold)),
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
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.current.shadow,
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
              ? Icon(Icons.gavel_rounded, color: AppColors.current.textStrong)
              : null,
        ),
        title: Text(lawyer.name,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
        subtitle: Text(lawyer.phone.isEmpty ? S.emptyValue : lawyer.phone),
        trailing: !ref.watch(currentUserProvider).isAdmin
            ? null
            : PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.current.textMuted),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') {
                    _openForm(context, existing: lawyer);
                  } else if (v == 'delete') {
                    _confirmDelete(context, ref, lawyer);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined,
                          color: AppColors.current.textStrong, size: 20),
                      const SizedBox(width: 12),
                      Text(S.edit),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          color: AppColors.current.danger, size: 20),
                      const SizedBox(width: 12),
                      Text(S.delete),
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
      title: Text(S.deleteLawyer,
          style:
              TextStyle(color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
      content: Text(S.deleteLawyerConfirm(lawyer.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child:
              Text(S.cancel, style: TextStyle(color: AppColors.current.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.current.danger,
              foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(S.delete),
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
        SnackBar(
            content: Text(S.error(e)), backgroundColor: AppColors.current.danger),
      );
    }
  }
}

/// Opens the add/edit lawyer form in a bottom sheet.
void _openForm(BuildContext context, {Lawyer? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.current.card,
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
      _photoContentType = picked.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
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
              content: Text(S.error(e)), backgroundColor: AppColors.current.danger),
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
            Text(_isEdit ? S.editLawyer : S.newLawyer,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.current.textStrong)),
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
                          ? Icon(Icons.add_a_photo_outlined,
                              color: AppColors.current.textStrong, size: 28)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: _accentYellow, shape: BoxShape.circle),
                        child: Icon(Icons.edit,
                            size: 16, color: AppColors.current.onAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: S.lawyerName,
                  prefixIcon: const Icon(Icons.person_outline)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? S.requiredField : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: S.mobileNumber,
                  prefixIcon: const Icon(Icons.phone_iphone)),
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
                  : Text(_isEdit ? S.save : S.add,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
