import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../admin/admin_repository.dart';
import '../../auth/session.dart';
import '../../models/company_model.dart';
import '../../models/enums.dart';

/// Super Admin home: list companies, create a company + its admin, and manage
/// each company's users.
class SuperAdminPanel extends ConsumerWidget {
  const SuperAdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(companiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بەڕێوەبەری گشتی'),
        actions: [
          IconButton(
            tooltip: 'سوپەر ئەدمینەکان',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _SuperAdminsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'دەرچوون',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business),
        label: const Text('کۆمپانیای نوێ'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _CreateCompanyScreen()),
        ),
      ),
      body: companies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('هیچ کۆمپانیایەک نییە'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = list[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(c.displayName),
                  subtitle: Text(c.phone1),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _CompanyUsersScreen(company: c)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// List + create other Super Admins (document-based, up to as many as needed).
class _SuperAdminsScreen extends ConsumerWidget {
  const _SuperAdminsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admins = ref.watch(superAdminsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('سوپەر ئەدمینەکان')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_moderator),
        label: const Text('سوپەر ئەدمینی نوێ'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _AddSuperAdminScreen()),
        ),
      ),
      body: admins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (list) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final a in list)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.shield),
                  title: Text(a.displayName),
                  subtitle: Text(a.email),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddSuperAdminScreen extends ConsumerStatefulWidget {
  const _AddSuperAdminScreen();

  @override
  ConsumerState<_AddSuperAdminScreen> createState() =>
      _AddSuperAdminScreenState();
}

class _AddSuperAdminScreenState extends ConsumerState<_AddSuperAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).createSuperAdmin(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
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
      appBar: AppBar(title: const Text('سوپەر ئەدمینی نوێ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'ناوی تەواو'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'ئیمەیڵ'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'ئیمەیڵی دروست' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'وشەی نهێنی'),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'لانیکەم ٦ پیت' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
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
}

/// Create a company + its Company Admin.
class _CreateCompanyScreen extends ConsumerStatefulWidget {
  const _CreateCompanyScreen();

  @override
  ConsumerState<_CreateCompanyScreen> createState() =>
      _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<_CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  // Company
  final _nameKu = TextEditingController();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _phone1 = TextEditingController();
  final _phone2 = TextEditingController();
  final _address = TextEditingController();
  // Admin account
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPassword = TextEditingController();
  final _adminPhone = TextEditingController();
  // User account
  final _userName = TextEditingController();
  final _userEmail = TextEditingController();
  final _userPassword = TextEditingController();
  final _userPhone = TextEditingController();

  Uint8List? _logoBytes;
  String _logoContentType = 'image/jpeg';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _nameKu,
      _nameAr,
      _nameEn,
      _phone1,
      _phone2,
      _address,
      _adminName,
      _adminEmail,
      _adminPassword,
      _adminPhone,
      _userName,
      _userEmail,
      _userPassword,
      _userPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _logoContentType =
          picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_logoBytes == null) {
      setState(() => _error = 'لۆگۆ پێویستە — تکایە وێنەیەک هەڵبژێرە');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).createCompanyWithAccounts(
            companyNameKu: _nameKu.text,
            companyNameAr: _nameAr.text,
            companyNameEn: _nameEn.text,
            companyPhone1: _phone1.text,
            companyPhone2: _phone2.text,
            companyAddress: _address.text,
            logoBytes: _logoBytes!,
            logoContentType: _logoContentType,
            adminName: _adminName.text,
            adminEmail: _adminEmail.text,
            adminPassword: _adminPassword.text,
            adminPhone: _adminPhone.text,
            userName: _userName.text,
            userEmail: _userEmail.text,
            userPassword: _userPassword.text,
            userPhone: _userPhone.text,
          );
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
      appBar: AppBar(title: const Text('کۆمپانیای نوێ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section('کۆمپانیا'),
              // Logo picker.
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : _pickLogo,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        _logoBytes != null ? MemoryImage(_logoBytes!) : null,
                    child: _logoBytes == null
                        ? const Icon(Icons.add_a_photo, size: 28)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text('لۆگۆی کۆمپانیا (پێویست)',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameKu,
                decoration:
                    const InputDecoration(labelText: 'ناوی کۆمپانیا (کوردی)'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameAr,
                decoration:
                    const InputDecoration(labelText: 'ناوی کۆمپانیا (عەرەبی)'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameEn,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'ناوی کۆمپانیا (ئینگلیزی)',
                  helperText: 'وەک Document ID بەکاردێت — تەنها پیتی ئینگلیزی',
                ),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone1,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'ژمارەی یەکەم'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone2,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'ژمارەی دووەم'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration:
                    const InputDecoration(labelText: 'ناونیشانی کۆمپانیا'),
                validator: _req,
              ),
              const Divider(height: 32),
              _section('ئەکاونتی ١ — بەڕێوەبەری کۆمپانیا (ئەدمین)'),
              ..._accountFields(
                name: _adminName,
                email: _adminEmail,
                password: _adminPassword,
                phone: _adminPhone,
              ),
              const Divider(height: 32),
              _section('ئەکاونتی ٢ — یوزەری کۆمپانیا'),
              ..._accountFields(
                name: _userName,
                email: _userEmail,
                password: _userPassword,
                phone: _userPhone,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('دروستکردنی کۆمپانیا + ٢ ئەکاونت'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  List<Widget> _accountFields({
    required TextEditingController name,
    required TextEditingController email,
    required TextEditingController password,
    required TextEditingController phone,
  }) =>
      [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(labelText: 'ناوی تەواو'),
          validator: _req,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'ژمارەی مۆبایل (لە بازاڕی گشتی پیشان دەدرێت)',
          ),
          validator: _req,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'ئیمەیڵ'),
          validator: (v) =>
              (v == null || !v.contains('@')) ? 'ئیمەیڵی دروست' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'وشەی نهێنی'),
          validator: (v) =>
              (v == null || v.length < 6) ? 'لانیکەم ٦ پیت' : null,
        ),
      ];

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'پێویستە' : null;
}

/// List + add users for a specific company.
class _CompanyUsersScreen extends ConsumerWidget {
  const _CompanyUsersScreen({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(companyUsersProvider(company.id));
    return Scaffold(
      appBar: AppBar(title: Text(company.displayName)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('بەکارهێنەری نوێ'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _AddUserScreen(companyId: company.id)),
        ),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('هیچ بەکارهێنەرێک نییە'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final u in list)
                Card(
                  child: ListTile(
                    leading: Icon(u.role == UserRole.companyAdmin
                        ? Icons.admin_panel_settings
                        : Icons.person),
                    title: Text(u.displayName),
                    subtitle: Text(u.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(u.role == UserRole.companyAdmin
                            ? 'ئەدمین'
                            : 'گوماشتە'),
                        IconButton(
                          tooltip: 'گۆڕینی وشەی نهێنی',
                          icon: const Icon(Icons.key_outlined),
                          onPressed: () =>
                              _changePassword(context, ref, u.uid, u.displayName),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changePassword(
      BuildContext context, WidgetRef ref, String uid, String name) async {
    final controller = TextEditingController();
    bool busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('وشەی نهێنی نوێ — $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'وشەی نهێنی نوێ',
                  hintText: 'لانیکەم ٦ پیت',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('پاشگەزبوونەوە')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (controller.text.length < 6) {
                        setDialog(() => error = 'لانیکەم ٦ پیت');
                        return;
                      }
                      setDialog(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(adminRepositoryProvider)
                            .setUserPassword(uid, controller.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('وشەی نهێنی گۆڕا')));
                        }
                      } catch (e) {
                        setDialog(() {
                          busy = false;
                          error = '$e';
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('گۆڕین'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add an agent/admin to a company.
class _AddUserScreen extends ConsumerStatefulWidget {
  const _AddUserScreen({required this.companyId});
  final String companyId;

  @override
  ConsumerState<_AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<_AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  UserRole _role = UserRole.agent;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).addUserToCompany(
            companyId: widget.companyId,
            name: _name.text,
            email: _email.text,
            password: _password.text,
            phone: _phone.text,
            role: _role,
          );
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
      appBar: AppBar(title: const Text('بەکارهێنەری نوێ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'ناوی تەواو'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'ژمارەی مۆبایل (لە بازاڕ پیشان دەدرێت)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'ئیمەیڵ'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'ئیمەیڵی دروست' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'وشەی نهێنی'),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'لانیکەم ٦ پیت' : null,
              ),
              const SizedBox(height: 12),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(
                      value: UserRole.agent, label: Text('گوماشتە')),
                  ButtonSegment(
                      value: UserRole.companyAdmin, label: Text('ئەدمین')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('زیادکردن'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
