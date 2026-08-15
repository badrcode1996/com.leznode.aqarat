import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../admin/admin_repository.dart';
import '../../auth/session.dart';
import '../../models/app_user_model.dart';
import '../../models/company_model.dart';
import '../../models/enums.dart';
import '../../models/plan_config_model.dart';
import '../../services/export/export_service.dart';
import 'plan_settings_screen.dart';
import 'template_editor_screen.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get appBackgroundColor => AppColors.current.pageBg;
Color get inputFillColor => AppColors.current.inputFill;

// فەنکشنی هاوبەش بۆ دیزاینی بۆشاییەکان (TextFields)
InputDecoration modernInputDecoration({required String label, IconData? icon, String? helper}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    labelStyle: TextStyle(color: AppColors.current.textMuted, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.current.textStrong) : null,
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
    watchAppShell(context);
    final companies = ref.watch(companiesProvider);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(
        S.roleSuperAdmin,
        actions: [
          IconButton(
            tooltip: S.planSettings,
            icon: Icon(Icons.tune_rounded, color: accentYellow),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlanSettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: S.superAdmins,
            icon: Icon(Icons.shield_outlined, color: accentYellow),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _SuperAdminsScreen()),
            ),
          ),
          IconButton(
            tooltip: S.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentYellow,
        foregroundColor: AppColors.current.textStrong,
        icon: const Icon(Icons.add_business, size: 24),
        label: Text(S.newCompany, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _CreateCompanyScreen()),
        ),
      ),
      body: companies.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
        error: (e, _) => Center(child: Text(S.error(e), style: TextStyle(color: AppColors.current.danger))),
        data: (list) {
          if (list.isEmpty) {
            return _emptyState(S.noCompanies, Icons.business_center_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final c = list[i];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.current.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.current.shadow,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: inputFillColor,
                    child: Icon(Icons.business, color: AppColors.current.textStrong),
                  ),
                  title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text('${c.phone1}  ·  ${c.city.uiLabel}', style: TextStyle(color: AppColors.current.textMuted)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryDarkBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(c.plan.uiLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_left, color: accentYellow),
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
    watchAppShell(context);
    final admins = ref.watch(superAdminsProvider);
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(S.superAdmins),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentYellow,
        foregroundColor: AppColors.current.textStrong,
        icon: const Icon(Icons.add_moderator),
        label: Text(S.newSuperAdmin, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _AddSuperAdminScreen()),
        ),
      ),
      body: admins.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
        error: (e, _) => Center(child: Text(S.error(e))),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final a = list[i];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.current.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.current.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: primaryDarkBlue.withValues(alpha: 0.1),
                  child: Icon(Icons.shield, color: AppColors.current.textStrong),
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
    watchAppShell(context);
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(S.newSuperAdmin),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                Icon(Icons.shield_outlined, size: 64, color: accentYellow),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  decoration: modernInputDecoration(label: S.fullName, icon: Icons.person_outline),
                  validator: (v) => (v == null || v.trim().isEmpty) ? S.requiredField : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: modernInputDecoration(label: S.email, icon: Icons.email_outlined),
                  validator: (v) => (v == null || !v.contains('@')) ? S.emailInvalid : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: modernInputDecoration(label: S.password, icon: Icons.lock_outline),
                  validator: (v) => (v == null || v.length < 6) ? S.minSixChars : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.current.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: TextStyle(color: AppColors.current.danger), textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: modernButtonStyle(),
                  child: _busy
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(S.create, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
  CompanyCity _city = CompanyCity.erbil;
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
      setState(() => _error = S.logoRequired);
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
        city: _city,
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
    watchAppShell(context);
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(S.newCompany),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormSection(
                title: S.companyInfo,
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
                        child: _logoBytes == null ? Icon(Icons.add_a_photo, size: 32, color: AppColors.current.textStrong) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: Text(S.companyLogo, style: TextStyle(fontSize: 13, color: AppColors.current.textBody))),
                  const SizedBox(height: 24),
                  TextFormField(controller: _nameKu, decoration: modernInputDecoration(label: S.companyNameKu), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _nameAr, decoration: modernInputDecoration(label: S.companyNameAr), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _nameEn, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.companyNameEn, helper: S.usedAsDocumentId), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phone1, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.phone1, icon: Icons.phone), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phone2, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.phone2, icon: Icons.phone), validator: _req),
                  const SizedBox(height: 12),
                  TextFormField(controller: _address, decoration: modernInputDecoration(label: S.companyAddress, icon: Icons.location_on_outlined), validator: _req),
                  const SizedBox(height: 16),
                  TextFormField(controller: _branches, decoration: modernInputDecoration(label: S.branchesCommaLabel, icon: Icons.account_tree_outlined)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CompanyCity>(
                    isExpanded: true,
                    initialValue: _city,
                    decoration: modernInputDecoration(label: S.city, icon: Icons.location_city_outlined),
                    items: CompanyCity.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _city = v ?? CompanyCity.erbil),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(S.planSubscription, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
                  ),
                  const SizedBox(height: 8),
                  _PlanSelector(
                    value: _plan,
                    onChanged: (p) => setState(() => _plan = p),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(S.access, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
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
                title: S.account1,
                icon: Icons.admin_panel_settings,
                children: _accountFields(name: _adminName, email: _adminEmail, password: _adminPassword, phone: _adminPhone),
              ),
              const SizedBox(height: 20),

              _buildFormSection(
                title: S.account2,
                icon: Icons.person,
                children: _accountFields(name: _userName, email: _userEmail, password: _userPassword, phone: _userPhone),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.current.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: AppColors.current.danger), textAlign: TextAlign.center),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                style: modernButtonStyle(),
                child: _busy
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(S.backupData, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.current.shadow, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentYellow, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.current.textStrong))),
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
      TextFormField(controller: name, decoration: modernInputDecoration(label: S.fullName, icon: Icons.person_outline), validator: _req),
      const SizedBox(height: 12),
      TextFormField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.publicMobile, icon: Icons.phone_iphone), validator: _req),
      const SizedBox(height: 12),
      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.email, icon: Icons.email_outlined), validator: (v) => (v == null || !v.contains('@')) ? S.emailValidShort : null),
      const SizedBox(height: 12),
      TextFormField(controller: password, obscureText: true, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.password, icon: Icons.lock_outline), validator: (v) => (v == null || v.length < 6) ? S.minSixChars : null),
    ];
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? S.requiredField : null;
}

/// List + add users for a specific company
/// Edits an existing company's identity + logo.
///
/// A full screen rather than a dialog: it carries the same six fields as the
/// creation form, which do not fit an AlertDialog on a phone.
class _EditCompanyScreen extends ConsumerStatefulWidget {
  const _EditCompanyScreen({required this.company});
  final Company company;

  @override
  ConsumerState<_EditCompanyScreen> createState() => _EditCompanyScreenState();
}

class _EditCompanyScreenState extends ConsumerState<_EditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameKu = TextEditingController(text: widget.company.nameKu);
  late final _nameAr = TextEditingController(text: widget.company.nameAr);
  late final _nameEn = TextEditingController(text: widget.company.nameEn);
  late final _phone1 = TextEditingController(text: widget.company.phone1);
  late final _phone2 = TextEditingController(text: widget.company.phone2);
  late final _address = TextEditingController(text: widget.company.address);

  Uint8List? _logoBytes;
  String _logoContentType = 'image/jpeg';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nameKu, _nameAr, _nameEn, _phone1, _phone2, _address]) {
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).updateCompany(
            widget.company.id,
            nameKu: _nameKu.text,
            nameAr: _nameAr.text,
            nameEn: _nameEn.text,
            phone1: _phone1.text,
            phone2: _phone2.text,
            address: _address.text,
            logoBytes: _logoBytes,
            logoContentType: _logoContentType,
          );
      if (mounted) {
        // Resolved before the pop: afterwards this context is defunct and the
        // lookup throws instead of showing anything.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.companyInfoUpdated),
            backgroundColor: AppColors.current.success));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    // The saved logo shows until a new one is picked, so the picker always
    // previews what will actually be stored.
    final DecorationImage? logo = _logoBytes != null
        ? DecorationImage(image: MemoryImage(_logoBytes!), fit: BoxFit.cover)
        : (widget.company.logoUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(widget.company.logoUrl), fit: BoxFit.cover)
            : null);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(S.companyInfo),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.current.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.current.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        image: logo,
                      ),
                      child: logo == null
                          ? Icon(Icons.add_a_photo,
                              size: 32, color: AppColors.current.textStrong)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                    child: Text(S.tapToChange,
                        style: TextStyle(fontSize: 13, color: AppColors.current.textBody))),
                const SizedBox(height: 24),
                TextFormField(
                    controller: _nameKu,
                    decoration:
                        modernInputDecoration(label: S.companyNameKu),
                    validator: _req),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _nameAr,
                    decoration:
                        modernInputDecoration(label: S.companyNameAr),
                    validator: _req),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _nameEn,
                    textDirection: TextDirection.ltr,
                    decoration: modernInputDecoration(
                        label: S.companyNameEn,
                        helper: S.companyIdFixed(widget.company.id)),
                    validator: _req),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phone1,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: modernInputDecoration(
                        label: S.phone1, icon: Icons.phone),
                    validator: _req),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phone2,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: modernInputDecoration(
                        label: S.phone2, icon: Icons.phone_outlined)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _address,
                    decoration: modernInputDecoration(
                        label: S.addressLabel, icon: Icons.location_on_outlined),
                    validator: _req),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.current.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!,
                        style: TextStyle(color: AppColors.current.danger),
                        textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: modernButtonStyle(),
                  child: _busy
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(S.save,
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

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? S.requiredField : null;
}

class _CompanyUsersScreen extends ConsumerWidget {
  const _CompanyUsersScreen({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    final users = ref.watch(companyUsersProvider(company.id));
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(company.displayName, actions: [
        IconButton(
          tooltip: S.companyInfo,
          icon: Icon(Icons.business_outlined, color: accentYellow),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => _EditCompanyScreen(company: company)),
          ),
        ),
        IconButton(
          tooltip: S.planSubscription,
          icon: Icon(Icons.workspace_premium_outlined, color: accentYellow),
          onPressed: () => _changePlan(context, ref),
        ),
        IconButton(
          tooltip: S.accessAppWeb,
          icon: Icon(Icons.devices_outlined, color: accentYellow),
          onPressed: () => _changeAccess(context, ref),
        ),
        IconButton(
          tooltip: S.demo7Days,
          icon: Icon(Icons.timelapse_outlined,
              color: company.demo ? AppColors.current.danger : accentYellow),
          onPressed: () => _changeDemo(context, ref),
        ),
        IconButton(
          tooltip: S.features,
          icon: Icon(Icons.toggle_on_outlined, color: accentYellow),
          onPressed: () => _editFeatures(context, ref),
        ),
        IconButton(
          tooltip: S.city,
          icon: Icon(Icons.location_city_outlined, color: accentYellow),
          onPressed: () => _changeCity(context, ref),
        ),
        IconButton(
          tooltip: S.exportTitle,
          icon: Icon(Icons.file_download_outlined, color: accentYellow),
          onPressed: () => _chooseExport(context, ref),
        ),
        IconButton(
          tooltip: S.contractTemplate,
          icon: Icon(Icons.description_outlined, color: accentYellow),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TemplateEditorScreen(company: company)),
          ),
        ),
        IconButton(
          tooltip: S.manageBranches,
          icon: Icon(Icons.account_tree_outlined, color: accentYellow),
          onPressed: () => _editBranches(context, ref),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentYellow,
        foregroundColor: AppColors.current.textStrong,
        icon: const Icon(Icons.person_add),
        label: Text(S.newUser, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _AddUserScreen(company: company)),
        ),
      ),
      body: users.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
        error: (e, _) => Center(child: Text(S.error(e))),
        data: (list) {
          if (list.isEmpty) {
            return _emptyState(S.noUsers, Icons.people_outline);
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
                  color: AppColors.current.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.current.shadow, blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isAdmin ? accentYellow.withValues(alpha: 0.2) : inputFillColor,
                    child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: isAdmin ? accentYellow : AppColors.current.textStrong),
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
                        child: Text(isAdmin ? S.roleAdminShort : S.roleAgent, style: TextStyle(color: isAdmin ? accentYellow : AppColors.current.textStrong, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: S.editInfo,
                        icon: Icon(Icons.edit_outlined, color: AppColors.current.textMuted),
                        onPressed: () => _editUser(context, ref, u),
                      ),
                      IconButton(
                        tooltip: S.changePassword,
                        icon: Icon(Icons.key_outlined, color: AppColors.current.textMuted),
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

  /// Edits a user's profile: name, phone, role, branch.
  ///
  /// Email is shown read-only — it is the Auth login identity, not a profile
  /// field, so changing it needs an Admin SDK call rather than this write.
  Future<void> _editUser(
      BuildContext context, WidgetRef ref, AppUser user) async {
    final name = TextEditingController(text: user.displayName);
    final phone = TextEditingController(text: user.phone);
    var role = user.role;
    var branch = user.branch;
    var branchAdmin = user.branchAdmin;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(S.editUser,
              style: TextStyle(
                  color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(user.email,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.current.textMuted)),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  decoration:
                      modernInputDecoration(label: S.fullName, icon: Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: modernInputDecoration(
                      label: S.mobileNumber, icon: Icons.phone_iphone),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  isExpanded: true,
                  initialValue: role,
                  decoration: modernInputDecoration(
                      label: S.role, icon: Icons.badge_outlined),
                  // superAdmin is absent on purpose: it belongs to no company,
                  // so promoting someone here would orphan them.
                  items: [
                    DropdownMenuItem(
                        value: UserRole.companyAdmin, child: Text(S.roleAdminShort)),
                    DropdownMenuItem(
                        value: UserRole.agent, child: Text(S.roleAgent)),
                  ],
                  onChanged: (v) =>
                      setDialog(() => role = v ?? UserRole.agent),
                ),
                const SizedBox(height: 12),
                if (company.branches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue:
                        company.branches.contains(branch) ? branch : null,
                    decoration: modernInputDecoration(
                        label: S.branch, icon: Icons.account_tree_outlined),
                    items: company.branches
                        .map((b) =>
                            DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setDialog(() => branch = v ?? ''),
                  )
                else
                  const _NoBranchesNote(),
                if (role == UserRole.companyAdmin)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.adminBranchScoped,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(S.branchOnlyData,
                        style: const TextStyle(fontSize: 11)),
                    value: branchAdmin,
                    activeThumbColor: Colors.white,
                    activeTrackColor: primaryDarkBlue,
                    onChanged: (v) => setDialog(() => branchAdmin = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.cancel,
                    style: TextStyle(color: AppColors.current.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text(S.saveShort, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await ref.read(adminRepositoryProvider).updateUser(
            user.uid,
            displayName: name.text,
            phone: phone.text,
            role: role,
            branch: branch,
            branchAdmin: branchAdmin,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.infoUpdated),
            backgroundColor: AppColors.current.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.error(e)),
            backgroundColor: AppColors.current.danger));
      }
    }
  }

  /// Bottom sheet to pick the export format.
  void _chooseExport(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.current.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(S.exportCompanyData,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.current.textStrong)),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                  backgroundColor:
                      AppColors.current.success.withValues(alpha: 0.1),
                  child: Icon(Icons.grid_on, color: AppColors.current.success)),
              title: const Text('Excel (xlsx)'),
              subtitle: Text(S.excelTwoSheets),
              onTap: () {
                Navigator.pop(context);
                _runExport(context, ref, excel: true);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: AppColors.current.danger.withValues(alpha: 0.12),
                  child: Icon(Icons.picture_as_pdf, color: AppColors.current.danger)),
              title: const Text('PDF'),
              subtitle: Text(S.tabularReport),
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
      builder: (_) => Center(
          child: CircularProgressIndicator(color: AppColors.current.textStrong)),
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
          content: Text(S.exportFailed(e)),
          backgroundColor: AppColors.current.danger));
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
          title: Text(S.planSubscription,
              style: TextStyle(
                  color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanSelector(
                value: selected,
                onChanged: (p) => setDialog(() => selected = p),
              ),
              const SizedBox(height: 12),
              Text(
                S.featuresPlanNote,
                style: TextStyle(fontSize: 12, color: AppColors.current.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.cancel,
                    style: TextStyle(color: AppColors.current.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, selected),
              child:
                  Text(S.saveShort, style: const TextStyle(color: Colors.white)),
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
              content: Text(S.planChangedTo(result.uiLabel)),
              backgroundColor: AppColors.current.success));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(S.error(e)),
              backgroundColor: AppColors.current.danger));
        }
      }
    }
  }

  static Map<String, String> get _featureLabels => {
    'sale': S.saleContract,
    'overdue': S.featureOverdue,
    'market': S.filterMarket,
    'offers': S.listProperty,
    'requests': S.customerRequest,
    'lawyers': S.lawyers,
    'guarantees': S.featureGuarantees,
    'commission': S.featureCommission,
    'arabic_contracts': S.featureArabicContracts,
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
          title: Text(S.companyFeatures,
              style: TextStyle(
                  color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.overrideNote,
                    style:
                        TextStyle(fontSize: 12, color: AppColors.current.textMuted),
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
                                backgroundColor: AppColors.current.card,
                                selectedForegroundColor: Colors.white,
                                selectedBackgroundColor: primaryDarkBlue,
                                visualDensity: VisualDensity.compact,
                              ),
                              segments: [
                                ButtonSegment(
                                    value: 0, label: Text(S.asPlan)),
                                ButtonSegment(value: 1, label: Text(S.filterActive)),
                                ButtonSegment(
                                    value: 2, label: Text(S.inactive)),
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
                child: Text(S.cancel,
                    style: TextStyle(color: AppColors.current.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text(S.saveShort, style: const TextStyle(color: Colors.white)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.featuresUpdated),
            backgroundColor: AppColors.current.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.error(e)), backgroundColor: AppColors.current.danger));
      }
    }
  }

  Future<void> _changeCity(BuildContext context, WidgetRef ref) async {
    var selected = company.city;
    final result = await showDialog<CompanyCity>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(S.companyCity,
              style: TextStyle(
                  color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
          content: DropdownButtonFormField<CompanyCity>(
            isExpanded: true,
            initialValue: selected,
            decoration: modernInputDecoration(
                label: S.city, icon: Icons.location_city_outlined),
            items: CompanyCity.values
                .map((c) =>
                    DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (v) => setDialog(() => selected = v ?? selected),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.cancel,
                    style: TextStyle(color: AppColors.current.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, selected),
              child:
                  Text(S.saveShort, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (result != null && result != company.city) {
      try {
        await ref.read(adminRepositoryProvider).setCity(company.id, result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(S.cityChangedTo(result.uiLabel)),
              backgroundColor: AppColors.current.success));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(S.error(e)),
              backgroundColor: AppColors.current.danger));
        }
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
          title: Text(S.access,
              style: TextStyle(
                  color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AccessSelector(
                webOnly: webOnly,
                onChanged: (v) => setDialog(() => webOnly = v),
              ),
              const SizedBox(height: 12),
              Text(
                S.webOnlyNote,
                style: TextStyle(fontSize: 12, color: AppColors.current.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.cancel,
                    style: TextStyle(color: AppColors.current.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, webOnly),
              child:
                  Text(S.saveShort, style: const TextStyle(color: Colors.white)),
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
                  ? S.switchedToWebOnly
                  : S.switchedToAppWeb),
              backgroundColor: AppColors.current.success));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(S.error(e)),
              backgroundColor: AppColors.current.danger));
        }
      }
    }
  }

  /// Switches the company's 7-day trial on or off.
  ///
  /// Saving with the switch already ON re-stamps the deadline, which is the
  /// only way to extend a trial — so, unlike the other dialogs here, this one
  /// does not skip the write when the value is unchanged.
  Future<void> _changeDemo(BuildContext context, WidgetRef ref) async {
    var demo = company.demo;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(S.demoAccount,
              style: TextStyle(
                  color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(S.demoEnabled,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(S.sevenDaysFromNow,
                    style: const TextStyle(fontSize: 12)),
                value: demo,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.current.danger,
                onChanged: (v) => setDialog(() => demo = v),
              ),
              if (company.demo) ...[
                const Divider(height: 20),
                Text(
                  company.demoExpired
                      ? S.demoExpiredNote
                      : S.daysLeft(company.demoDaysLeft ?? 0),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: company.demoExpired
                        ? AppColors.current.danger
                        : AppColors.current.textStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  S.saveResetsDemo,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.current.textMuted),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                S.demoExpiryNote,
                style: TextStyle(fontSize: 12, color: AppColors.current.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.cancel,
                    style: TextStyle(color: AppColors.current.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, demo),
              child:
                  Text(S.saveShort, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await ref.read(adminRepositoryProvider).setDemo(company.id, result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result
                ? S.demoActivated
                : S.demoRemoved),
            backgroundColor: AppColors.current.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.error(e)),
            backgroundColor: AppColors.current.danger));
      }
    }
  }

  Future<void> _editBranches(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: company.branches.join(S.listSeparator));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.branches,
            style: TextStyle(
                color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration:
              modernInputDecoration(label: S.branchesCommaHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.cancel,
                  style: TextStyle(color: AppColors.current.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDarkBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(S.saveShort,
                style: const TextStyle(color: Colors.white)),
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
              SnackBar(content: Text(S.branchesUpdated)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.error(e)), backgroundColor: AppColors.current.danger));
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
          title: Text(S.newPassword, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: TextStyle(color: AppColors.current.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: modernInputDecoration(label: S.newPassword, icon: Icons.lock_outline),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: AppColors.current.danger)),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: Text(S.cancel, style: TextStyle(color: AppColors.current.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accentYellow, foregroundColor: AppColors.current.textStrong, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: busy
                  ? null
                  : () async {
                if (controller.text.length < 6) {
                  setDialog(() => error = S.minSixChars);
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.passwordChanged), backgroundColor: AppColors.current.success));
                  }
                } catch (e) {
                  setDialog(() {
                    busy = false;
                    error = '$e';
                  });
                }
              },
              child: busy ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.current.textStrong)) : Text(S.change, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the branch picker when the company has no branches on file.
///
/// The picker used to be hidden in that case, which is indistinguishable from
/// the app not supporting branch assignment at all — the branch list has to be
/// filled in from the company's own menu before anyone can be put in one, and
/// nothing said so.
class _NoBranchesNote extends StatelessWidget {
  const _NoBranchesNote();

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.current.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.current.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 18, color: AppColors.current.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.noBranchesYet,
              style: TextStyle(fontSize: 12, color: AppColors.current.textBody),
            ),
          ),
        ],
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
    watchAppShell(context);
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: modernAppBar(S.newUser),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.current.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.current.shadow, blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<UserRole>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.current.card,
                    selectedForegroundColor: Colors.white,
                    selectedBackgroundColor: primaryDarkBlue,
                  ),
                  segments: [
                    ButtonSegment(value: UserRole.agent, label: Text(S.roleAgent), icon: const Icon(Icons.person)),
                    ButtonSegment(value: UserRole.companyAdmin, label: Text(S.roleAdminShort), icon: const Icon(Icons.admin_panel_settings)),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                if (_role == UserRole.companyAdmin) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    style: SegmentedButton.styleFrom(
                        backgroundColor: AppColors.current.card,
                        selectedForegroundColor: Colors.white,
                        selectedBackgroundColor: accentYellow),
                    segments: [
                      ButtonSegment(
                          value: false,
                          label: Text(S.adminCompanyWide),
                          icon: const Icon(Icons.public)),
                      ButtonSegment(
                          value: true,
                          label: Text(S.adminBranchScoped),
                          icon: const Icon(Icons.account_tree_outlined)),
                    ],
                    selected: {_branchAdmin},
                    onSelectionChanged: (s) =>
                        setState(() => _branchAdmin = s.first),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: widget.company.branches.isNotEmpty
                      ? DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _branch,
                          decoration: modernInputDecoration(
                              label: S.branch,
                              icon: Icons.account_tree_outlined),
                          items: widget.company.branches
                              .map((b) =>
                                  DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: (v) => setState(() => _branch = v),
                        )
                      : const _NoBranchesNote(),
                ),
                TextFormField(controller: _name, decoration: modernInputDecoration(label: S.fullName, icon: Icons.badge_outlined), validator: (v) => (v == null || v.trim().isEmpty) ? S.requiredField : null),
                const SizedBox(height: 16),
                TextFormField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.publicMobile, icon: Icons.phone_iphone), validator: (v) => (v == null || v.trim().isEmpty) ? S.requiredField : null),
                const SizedBox(height: 16),
                TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.email, icon: Icons.email_outlined), validator: (v) => (v == null || !v.contains('@')) ? S.emailValidShort : null),
                const SizedBox(height: 16),
                TextFormField(controller: _password, obscureText: true, textDirection: TextDirection.ltr, decoration: modernInputDecoration(label: S.password, icon: Icons.lock_outline), validator: (v) => (v == null || v.length < 6) ? S.minSixChars : null),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.current.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text(_error!, style: TextStyle(color: AppColors.current.danger), textAlign: TextAlign.center)),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: modernButtonStyle(),
                  child: _busy ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Text(S.add, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    watchAppShell(context);
    return SegmentedButton<CompanyPlan>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.current.card,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: primaryDarkBlue,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      segments: [
        ButtonSegment(value: CompanyPlan.bronze, label: Text(S.planBronze)),
        ButtonSegment(value: CompanyPlan.silver, label: Text(S.planSilver)),
        ButtonSegment(value: CompanyPlan.gold, label: Text(S.planGold)),
        ButtonSegment(value: CompanyPlan.diamond, label: Text(S.planDiamond)),
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
    watchAppShell(context);
    return SegmentedButton<bool>(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.current.card,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: primaryDarkBlue,
      ),
      segments: [
        ButtonSegment(
            value: false,
            label: Text(S.accessAppAndWeb),
            icon: const Icon(Icons.devices)),
        ButtonSegment(
            value: true, label: Text(S.accessWebOnly), icon: const Icon(Icons.public)),
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
        Icon(icon, size: 80, color: AppColors.current.divider),
        const SizedBox(height: 16),
        Text(text, style: TextStyle(fontSize: 18, color: AppColors.current.textMuted, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}