import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../admin/admin_repository.dart';
import '../../auth/session.dart';
import '../../models/company_model.dart';
import '../../models/enums.dart';
import '../../models/plan_config_model.dart';
import '../../services/export/export_service.dart';
import 'plan_settings_screen.dart';
import 'template_editor_screen.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);
const Color inputFillColor = Color(0xFFF3F4F6);

// فەنکشنی هاوبەش بۆ دیزاینی بۆشاییەکان (TextFields)
InputDecoration modernInputDecoration({required String label, IconData? icon, String? helper}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: primaryDarkBlue) : null,
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

// فەنکشنی هاوبەش بۆ دیزاینی دوگمەکان
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

// فەنکشنی هاوبەش بۆ AppBar
AppBar modernAppBar(String title, {List<Widget>? actions}) {
  return AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    backgroundColor: primaryDarkBlue,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    actions: actions,
  );
}

/// Super Admin home
class SuperAdminPanel extends ConsumerWidget {
  const SuperAdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(companiesProvider);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(
        'بەڕێوەبەری گشتی',
        actions: [
          IconButton(
            tooltip: 'ڕێکخستنی پلانەکان',
            icon: const Icon(Icons.tune_rounded, color: accentYellow),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlanSettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'سوپەر ئەدمینەکان',
            icon: const Icon(Icons.shield_outlined, color: accentYellow),
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
        backgroundColor: accentYellow,
        foregroundColor: primaryDarkBlue,
        icon: const Icon(Icons.add_business, size: 24),
        label: const Text('کۆمپانیای نوێ', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _CreateCompanyScreen()),
        ),
      ),
      body: companies.when(
        loading: () => const Center(child: CircularProgressIndicator(color: primaryDarkBlue)),
        error: (e, _) => Center(child: Text('هەڵە: $e', style: const TextStyle(color: Colors.red))),
        data: (list) {
          if (list.isEmpty) {
            return _emptyState('هیچ کۆمپانیایەک نییە', Icons.business_center_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final c = list[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: inputFillColor,
                    child: Icon(Icons.business, color: primaryDarkBlue),
                  ),
                  title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(c.phone1, style: TextStyle(color: Colors.grey.shade600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryDarkBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(c.plan.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryDarkBlue)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_left, color: accentYellow),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => _CompanyUsersScreen(company: c)),
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

/// List + create other Super Admins
class _SuperAdminsScreen extends ConsumerWidget {
  const _SuperAdminsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admins = ref.watch(superAdminsProvider);
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar('سوپەر ئەدمینەکان'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentYellow,
        foregroundColor: primaryDarkBlue,
        icon: const Icon(Icons.add_moderator),
        label: const Text('سوپەر ئەدمینی نوێ', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _AddSuperAdminScreen()),
        ),
      ),
      body: admins.when(
        loading: () => const Center(child: CircularProgressIndicator(color: primaryDarkBlue)),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final a = list[i];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: primaryDarkBlue.withValues(alpha: 0.1),
                  child: const Icon(Icons.shield, color: primaryDarkBlue),
                ),
                title: Text(a.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(a.email),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AddSuperAdminScreen extends ConsumerStatefulWidget {
  const _AddSuperAdminScreen();

  @override
  ConsumerState<_AddSuperAdminScreen> createState() => _AddSuperAdminScreenState();
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
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar('سوپەر ئەدمینی نوێ'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                const Icon(Icons.shield_outlined, size: 64, color: accentYellow),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  decoration: modernInputDecoration(label: 'ناوی تەواو', icon: Icons.person_outline),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: modernInputDecoration(label: 'ئیمەیڵ', icon: Icons.email_outlined),
                  validator: (v) => (v == null || !v.contains('@')) ? 'ئیمەیڵی دروست بنووسە' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: modernInputDecoration(label: 'وشەی نهێنی', icon: Icons.lock_outline),
                  validator: (v) => (v == null || v.length < 6) ? 'لانیکەم ٦ پیت' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
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
}

/// Create a company + its Company Admin & User.
class _CreateCompanyScreen extends ConsumerStatefulWidget {
  const _CreateCompanyScreen();

  @override
  ConsumerState<_CreateCompanyScreen> createState() => _CreateCompanyScreenState();
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
  final _branches = TextEditingController(); // لقەکان بە کۆما جیادەکرێنەوە
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
  CompanyPlan _plan = CompanyPlan.bronze;
  bool _webOnly = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nameKu, _nameAr, _nameEn, _phone1, _phone2, _address, _branches, _adminName, _adminEmail, _adminPassword, _adminPhone, _userName, _userEmail, _userPassword, _userPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _logoContentType = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
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
        branches: _branches.text.split(','),
        plan: _plan,
        webOnly: _webOnly,
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
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar('کۆمپانیای نوێ'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormSection(
                title: 'زانیاری کۆمپانیا',
                icon: Icons.business,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _busy ? null : _pickLogo,
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: inputFillColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: accentYellow, width: 2),
                          image: _logoBytes != null ? DecorationImage(image: MemoryImage(_logoBytes!), fit: BoxFit.cover) : null,
                        ),
                        child: _logoBytes == null ? const Icon(Icons.add_a_photo, size: 32, color: primaryDarkBlue) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(child: Text('لۆگۆی کۆمپانیا', style: TextStyle(fontSize: 13, color: Colors.black54))),
                  const SizedBox(height: 24),
                  TextFormField(controller: _nameKu, decoration: modernInputDecoration(label: 'ناوی کۆمپانیا (کوردی)'), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _nameAr, decoration: modernInputDecoration(label: 'ناوی کۆمپانیا (عەرەبی)'), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _nameEn, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'ناوی کۆمپانیا (ئینگلیزی)', helper: 'وەک Document ID بەکاردێت'), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phone1, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'ژمارەی یەکەم', icon: Icons.phone), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phone2, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'ژمارەی دووەم', icon: Icons.phone), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _address, decoration: modernInputDecoration(label: 'ناونیشانی کۆمپانیا', icon: Icons.location_on_outlined), validator: _req),
                  const SizedBox(height: 16),
                  TextFormField(controller: _branches, decoration: modernInputDecoration(label: 'لقەکان (بە کۆما جیابکەرەوە)', icon: Icons.account_tree_outlined)),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('پلانی بەژداری', style: TextStyle(fontWeight: FontWeight.bold, color: primaryDarkBlue)),
                  ),
                  const SizedBox(height: 8),
                  _PlanSelector(
                    value: _plan,
                    onChanged: (p) => setState(() => _plan = p),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('دەستگەیشتن', style: TextStyle(fontWeight: FontWeight.bold, color: primaryDarkBlue)),
                  ),
                  const SizedBox(height: 8),
                  _AccessSelector(
                    webOnly: _webOnly,
                    onChanged: (v) => setState(() => _webOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildFormSection(
                title: 'ئەکاونتی ١ — بەڕێوەبەری کۆمپانیا',
                icon: Icons.admin_panel_settings,
                children: _accountFields(name: _adminName, email: _adminEmail, password: _adminPassword, phone: _adminPhone),
              ),
              const SizedBox(height: 20),

              _buildFormSection(
                title: 'ئەکاونتی ٢ — یوزەری کۆمپانیا',
                icon: Icons.person,
                children: _accountFields(name: _userName, email: _userEmail, password: _userPassword, phone: _userPhone),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                style: modernButtonStyle(),
                child: _busy
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('پاشەکەوتکردنی داتاکان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentYellow, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryDarkBlue))),
            ],
          ),
          const Divider(height: 30, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _accountFields({required TextEditingController name, required TextEditingController email, required TextEditingController password, required TextEditingController phone}) {
    return [
      TextFormField(controller: name, decoration: modernInputDecoration(label: 'ناوی تەواو', icon: Icons.person_outline), validator: _req),
      const SizedBox(height: 12),
      TextFormField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'ژمارەی مۆبایل (گشتی)', icon: Icons.phone_iphone), validator: _req),
      const SizedBox(height: 12),
      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'ئیمەیڵ', icon: Icons.email_outlined), validator: (v) => (v == null || !v.contains('@')) ? 'ئیمەیڵی دروست' : null),
      const SizedBox(height: 12),
      TextFormField(controller: password, obscureText: true, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'وشەی نهێنی', icon: Icons.lock_outline), validator: (v) => (v == null || v.length < 6) ? 'لانیکەم ٦ پیت' : null),
    ];
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'پێویستە' : null;
}

/// List + add users for a specific company
class _CompanyUsersScreen extends ConsumerWidget {
  const _CompanyUsersScreen({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(companyUsersProvider(company.id));
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(company.displayName, actions: [
        IconButton(
          tooltip: 'پلانی بەژداری',
          icon: const Icon(Icons.workspace_premium_outlined, color: accentYellow),
          onPressed: () => _changePlan(context, ref),
        ),
        IconButton(
          tooltip: 'دەستگەیشتن (ئەپ/وێب)',
          icon: const Icon(Icons.devices_outlined, color: accentYellow),
          onPressed: () => _changeAccess(context, ref),
        ),
        IconButton(
          tooltip: 'تایبەتمەندییەکان',
          icon: const Icon(Icons.toggle_on_outlined, color: accentYellow),
          onPressed: () => _editFeatures(context, ref),
        ),
        IconButton(
          tooltip: 'دەرهێنان (Export)',
          icon: const Icon(Icons.file_download_outlined, color: accentYellow),
          onPressed: () => _chooseExport(context, ref),
        ),
        IconButton(
          tooltip: 'تێمپلەیتی گرێبەست',
          icon: const Icon(Icons.description_outlined, color: accentYellow),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TemplateEditorScreen(company: company)),
          ),
        ),
        IconButton(
          tooltip: 'بەڕێوەبردنی لقەکان',
          icon: const Icon(Icons.account_tree_outlined, color: accentYellow),
          onPressed: () => _editBranches(context, ref),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentYellow,
        foregroundColor: primaryDarkBlue,
        icon: const Icon(Icons.person_add),
        label: const Text('بەکارهێنەری نوێ', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _AddUserScreen(company: company)),
        ),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator(color: primaryDarkBlue)),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (list) {
          if (list.isEmpty) {
            return _emptyState('هیچ بەکارهێنەرێک نییە', Icons.people_outline);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final u = list[i];
              final isAdmin = u.role == UserRole.companyAdmin;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isAdmin ? accentYellow.withValues(alpha: 0.2) : inputFillColor,
                    child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: isAdmin ? accentYellow : primaryDarkBlue),
                  ),
                  title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(u.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdmin ? accentYellow.withValues(alpha: 0.1) : primaryDarkBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(isAdmin ? 'ئەدمین' : 'کارمەند', style: TextStyle(color: isAdmin ? accentYellow : primaryDarkBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'گۆڕینی وشەی نهێنی',
                        icon: const Icon(Icons.key_outlined, color: Colors.grey),
                        onPressed: () => _changePassword(context, ref, u.uid, u.displayName),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Bottom sheet to pick the export format.
  void _chooseExport(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('دەرهێنانی داتای کۆمپانیا',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryDarkBlue)),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0x1A10B981),
                  child: Icon(Icons.grid_on, color: Color(0xFF10B981))),
              title: const Text('Excel (xlsx)'),
              subtitle: const Text('گرێبەست + پسولە لە دوو شیت'),
              onTap: () {
                Navigator.pop(context);
                _runExport(context, ref, excel: true);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.picture_as_pdf, color: Colors.red.shade700)),
              title: const Text('PDF'),
              subtitle: const Text('ڕاپۆرتی خشتەیی'),
              onTap: () {
                Navigator.pop(context);
                _runExport(context, ref, excel: false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Fetches the company's data and hands the generated file to the share sheet.
  Future<void> _runExport(BuildContext context, WidgetRef ref,
      {required bool excel}) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: primaryDarkBlue)),
    );
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (excel) {
        // Excel is built on-device from one-shot fetches.
        final repo = ref.read(adminRepositoryProvider);
        final contracts = await repo.fetchCompanyContracts(company.id);
        final receipts = await repo.fetchCompanyReceipts(company.id);
        await ExportService.shareExcel(company,
            contracts: contracts, receipts: receipts);
      } else {
        // PDF is rendered server-side (the function fetches the data).
        await ExportService.sharePdfRemote(company);
      }
      nav.pop(); // close the loading dialog
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(SnackBar(
          content: Text('هەڵە لە دەرهێنان: $e'),
          backgroundColor: Colors.red.shade700));
    }
  }

  Future<void> _changePlan(BuildContext context, WidgetRef ref) async {
    var selected = company.plan;
    final result = await showDialog<CompanyPlan>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('پلانی بەژداری',
              style: TextStyle(
                  color: primaryDarkBlue, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanSelector(
                value: selected,
                onChanged: (p) => setDialog(() => selected = p),
              ),
              const SizedBox(height: 12),
              Text(
                'کۆمپانیا تەنها ئەو تایبەتمەندییانە دەبینێت کە پلانەکەی ڕێگەی پێدەدات.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('پاشگەزبوونەوە',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, selected),
              child:
                  const Text('پاشەکەوت', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (result != null && result != company.plan) {
      try {
        await ref.read(adminRepositoryProvider).setPlan(company.id, result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('پلان گۆڕدرا بۆ ${result.label}'),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('هەڵە: $e'),
              backgroundColor: Colors.red.shade700));
        }
      }
    }
  }

  static const _featureLabels = {
    'sale': 'گرێبەستی فرۆشتن',
    'overdue': 'ئاگاداری کرێی دواکەوتوو',
    'market': 'بازاڕی گشتی',
    'offers': 'خستنەڕووی موڵک',
    'requests': 'داواکاری موشتەری',
    'lawyers': 'پارێزەران',
    'guarantees': 'کۆی دڵنیایی',
  };

  Future<void> _editFeatures(BuildContext context, WidgetRef ref) async {
    // 0 = inherit (وەک پلان), 1 = on, 2 = off
    final state = <String, int>{};
    for (final k in PlanFeatures.overridableKeys) {
      final ov = company.featureOverrides[k];
      state[k] = ov == null ? 0 : (ov ? 1 : 2);
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تایبەتمەندییەکانی کۆمپانیا',
              style: TextStyle(
                  color: primaryDarkBlue, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سەرپێچی لەسەر پلانەکە. «وەک پلان» = بنەڕەتی پلانەکە.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  for (final k in PlanFeatures.overridableKeys)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_featureLabels[k] ?? k,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                backgroundColor: Colors.white,
                                selectedForegroundColor: Colors.white,
                                selectedBackgroundColor: primaryDarkBlue,
                                visualDensity: VisualDensity.compact,
                              ),
                              segments: const [
                                ButtonSegment(
                                    value: 0, label: Text('وەک پلان')),
                                ButtonSegment(value: 1, label: Text('چالاک')),
                                ButtonSegment(
                                    value: 2, label: Text('ناچالاک')),
                              ],
                              selected: {state[k]!},
                              onSelectionChanged: (s) =>
                                  setDialog(() => state[k] = s.first),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('پاشگەزبوونەوە',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('پاشەکەوت', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final overrides = <String, bool>{};
    state.forEach((k, v) {
      if (v != 0) overrides[k] = v == 1;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .setFeatureOverrides(company.id, overrides);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تایبەتمەندییەکان نوێکرانەوە'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _changeAccess(BuildContext context, WidgetRef ref) async {
    var webOnly = company.webOnly;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('دەستگەیشتن',
              style: TextStyle(
                  color: primaryDarkBlue, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AccessSelector(
                webOnly: webOnly,
                onChanged: (v) => setDialog(() => webOnly = v),
              ),
              const SizedBox(height: 12),
              Text(
                'ئەگەر «تەنها وێب» هەڵبژێردرا، یوزەرەکانی ئەم کۆمپانیایە ناتوانن لە ئەپی مۆبایل بچنە ژوورەوە — تەنها لە وێب.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('پاشگەزبوونەوە',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, webOnly),
              child:
                  const Text('پاشەکەوت', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (result != null && result != company.webOnly) {
      try {
        await ref.read(adminRepositoryProvider).setWebOnly(company.id, result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result
                  ? 'گۆڕدرا بۆ: تەنها وێب'
                  : 'گۆڕدرا بۆ: ئەپ و وێب'),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('هەڵە: $e'),
              backgroundColor: Colors.red.shade700));
        }
      }
    }
  }

  Future<void> _editBranches(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: company.branches.join('، '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('لقەکان',
            style: TextStyle(
                color: primaryDarkBlue, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration:
              modernInputDecoration(label: 'لقەکان بە کۆما جیابکەرەوە'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDarkBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('پاشەکەوت',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        await ref
            .read(adminRepositoryProvider)
            .setBranches(company.id, result.split('،').expand((p) => p.split(',')).toList());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لقەکان نوێکرانەوە')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
        }
      }
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref, String uid, String name) async {
    final controller = TextEditingController();
    bool busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('وشەی نهێنی نوێ', style: TextStyle(fontWeight: FontWeight.bold, color: primaryDarkBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: modernInputDecoration(label: 'وشەی نهێنی نوێ', icon: Icons.lock_outline),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accentYellow, foregroundColor: primaryDarkBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                  await ref.read(adminRepositoryProvider).setUserPassword(uid, controller.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وشەی نهێنی گۆڕا'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  setDialog(() {
                    busy = false;
                    error = '$e';
                  });
                }
              },
              child: busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryDarkBlue)) : const Text('گۆڕین', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add an agent/admin to a company.
class _AddUserScreen extends ConsumerStatefulWidget {
  const _AddUserScreen({required this.company});
  final Company company;

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
  String? _branch;
  bool _branchAdmin = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _branch = widget.company.branches.isNotEmpty
        ? widget.company.branches.first
        : null;
  }

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
        companyId: widget.company.id,
        name: _name.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        role: _role,
        branch: _branch ?? '',
        branchAdmin: _branchAdmin,
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
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar('بەکارهێنەری نوێ'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<UserRole>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.white,
                    selectedForegroundColor: Colors.white,
                    selectedBackgroundColor: primaryDarkBlue,
                  ),
                  segments: const [
                    ButtonSegment(value: UserRole.agent, label: Text('کارمەند'), icon: Icon(Icons.person)),
                    ButtonSegment(value: UserRole.companyAdmin, label: Text('ئەدمین'), icon: Icon(Icons.admin_panel_settings)),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                if (_role == UserRole.companyAdmin) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white,
                        selectedForegroundColor: Colors.white,
                        selectedBackgroundColor: accentYellow),
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text('ئادمینی گشتی'),
                          icon: Icon(Icons.public)),
                      ButtonSegment(
                          value: true,
                          label: Text('ئادمینی لق'),
                          icon: Icon(Icons.account_tree_outlined)),
                    ],
                    selected: {_branchAdmin},
                    onSelectionChanged: (s) =>
                        setState(() => _branchAdmin = s.first),
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.company.branches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _branch,
                      decoration: modernInputDecoration(
                          label: 'لق', icon: Icons.account_tree_outlined),
                      items: widget.company.branches
                          .map((b) =>
                              DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setState(() => _branch = v),
                    ),
                  ),
                TextFormField(controller: _name, decoration: modernInputDecoration(label: 'ناوی تەواو', icon: Icons.badge_outlined), validator: (v) => (v == null || v.trim().isEmpty) ? 'پێویستە' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'ژمارەی مۆبایل (گشتی)', icon: Icons.phone_iphone), validator: (v) => (v == null || v.trim().isEmpty) ? 'پێویستە' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'ئیمەیڵ', icon: Icons.email_outlined), validator: (v) => (v == null || !v.contains('@')) ? 'ئیمەیڵی دروست' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _password, obscureText: true, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: 'وشەی نهێنی', icon: Icons.lock_outline), validator: (v) => (v == null || v.length < 6) ? 'لانیکەم ٦ پیت' : null),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text(_error!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center)),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: modernButtonStyle(),
                  child: _busy ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('زیادکردن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented Bronze / Silver / Gold plan picker reused by the create form and
/// the change-plan dialog.
class _PlanSelector extends StatelessWidget {
  const _PlanSelector({required this.value, required this.onChanged});

  final CompanyPlan value;
  final ValueChanged<CompanyPlan> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CompanyPlan>(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: primaryDarkBlue,
      ),
      segments: const [
        ButtonSegment(
            value: CompanyPlan.bronze,
            label: Text('بڕۆنز'),
            icon: Icon(Icons.workspace_premium, color: Color(0xFFCD7F32))),
        ButtonSegment(
            value: CompanyPlan.silver,
            label: Text('سیلڤەر'),
            icon: Icon(Icons.workspace_premium, color: Color(0xFF9CA3AF))),
        ButtonSegment(
            value: CompanyPlan.gold,
            label: Text('گۆڵد'),
            icon: Icon(Icons.workspace_premium, color: accentYellow)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Two-way access picker: both (app + web) or web-only. Reused by the create
/// form and the change-access dialog.
class _AccessSelector extends StatelessWidget {
  const _AccessSelector({required this.webOnly, required this.onChanged});

  final bool webOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: primaryDarkBlue,
      ),
      segments: const [
        ButtonSegment(
            value: false,
            label: Text('ئەپ و وێب'),
            icon: Icon(Icons.devices)),
        ButtonSegment(
            value: true, label: Text('تەنها وێب'), icon: Icon(Icons.public)),
      ],
      selected: {webOnly},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// Helper widget for empty states
Widget _emptyState(String text, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(text, style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}