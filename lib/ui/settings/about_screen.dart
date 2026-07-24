import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentGold = Color(0xFFC9A227);
const Color _appBackground = Color(0xFFF5F7FA);

/// "دەربارەی ئێمە" — the app's identity plus Leznode's contact channels.
/// Every row here opens an external app (dialer, mail client, browser), so the
/// values live in one place rather than being scattered through the UI.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _phone = '07502752334';
  static const _email = 'info@leznode.com';
  static const _site = 'https://leznode.com';
  static const _city = 'هەولێر';

  /// wa.me wants the number in full international form with no leading zero,
  /// so the local `0750…` becomes `964750…`.
  static String get _waPhone => '964${_phone.replaceFirst(RegExp(r'^0+'), '')}';

  static const _socials = <_Social>[
    _Social('فەیسبووک', Icons.facebook_rounded,
        'https://www.facebook.com/leznode', Color(0xFF1877F2)),
    _Social('ئینستاگرام', Icons.camera_alt_rounded,
        'https://www.instagram.com/leznode', Color(0xFFE1306C)),
    _Social('تیکتۆک', Icons.music_note_rounded,
        'https://www.tiktok.com/@leznode', Color(0xFF010101)),
  ];

  /// A device with no dialer or mail client makes `launchUrl` throw rather than
  /// return false, so both outcomes end at the same snackbar.
  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('نەتوانرا بکرێتەوە'),
          backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackground,
      appBar: AppBar(
        title: const Text('دەربارەی ئێمە',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              const SizedBox(height: 24),
              _sectionLabel('پەیوەندی'),
              _card([
                _row(
                  icon: Icons.phone_rounded,
                  label: 'تەلەفۆن',
                  value: _phone,
                  onTap: () =>
                      _open(context, Uri(scheme: 'tel', path: _phone)),
                ),
                _row(
                  icon: Icons.chat_rounded,
                  label: 'واتساپ',
                  value: _phone,
                  iconColor: const Color(0xFF25D366),
                  onTap: () =>
                      _open(context, Uri.parse('https://wa.me/$_waPhone')),
                ),
                _row(
                  icon: Icons.email_rounded,
                  label: 'ئیمەیل',
                  value: _email,
                  onTap: () =>
                      _open(context, Uri(scheme: 'mailto', path: _email)),
                ),
                _row(
                  icon: Icons.language_rounded,
                  label: 'ماڵپەڕ',
                  value: 'leznode.com',
                  onTap: () => _open(context, Uri.parse(_site)),
                ),
                _row(
                  icon: Icons.location_on_rounded,
                  label: 'ناونیشان',
                  value: _city,
                  last: true,
                ),
              ]),
              const SizedBox(height: 20),
              _sectionLabel('سۆشیال میدیا'),
              _card([
                for (var i = 0; i < _socials.length; i++)
                  _row(
                    icon: _socials[i].icon,
                    label: _socials[i].name,
                    value: _socials[i].handle,
                    iconColor: _socials[i].color,
                    last: i == _socials.length - 1,
                    onTap: () => _open(context, Uri.parse(_socials[i].url)),
                  ),
              ]),
              const SizedBox(height: 28),
              _footer(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Image.asset('assets/images/app_logo.png', height: 120),
            const SizedBox(height: 12),
            const Text('گرێبەست',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryDarkBlue)),
            const SizedBox(height: 6),
            Text('سیستەمی بەڕێوەبردنی موڵک و گرێبەست',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 14),
            const _VersionBadge(),
          ],
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  Widget _card(List<Widget> children) => Container(
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
        child: Column(children: children),
      );

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Color iconColor = _primaryDarkBlue,
    bool last = false,
  }) =>
      Column(
        children: [
          ListTile(
            leading: Icon(icon, color: iconColor),
            title: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(value,
                style: const TextStyle(color: Colors.grey),
                textDirection: TextDirection.ltr),
            trailing: onTap == null
                ? null
                : const Icon(Icons.chevron_left_rounded, color: Colors.grey),
            onTap: onTap,
          ),
          if (!last) const Divider(indent: 60, height: 1),
        ],
      );

  Widget _footer() => Column(
        children: [
          Text('دروستکراوە لەلایەن',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 4),
          const Text('LEZNODE',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: _accentGold)),
          const SizedBox(height: 8),
          Text('© ${DateTime.now().year} — هەموو مافەکان پارێزراون',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      );
}

/// "v1.0.3 (3)" read from the bundle, so a release bump needs no code change.
/// The lookup is a platform channel; the badge holds its space and stays empty
/// for the frame or two before it answers.
class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  /// Resolved once per launch — the bundle's version cannot change under a
  /// running app, and a rebuilt FutureBuilder would otherwise ask again.
  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: _appBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: FutureBuilder<PackageInfo>(
          future: _info,
          builder: (context, snap) {
            final info = snap.data;
            return Text(
              info == null ? '' : 'v${info.version} (${info.buildNumber})',
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            );
          },
        ),
      );
}

class _Social {
  const _Social(this.name, this.icon, this.url, this.color);
  final String name;
  final IconData icon;
  final String url;
  final Color color;

  /// "@leznode" — the trailing path segment of the profile URL.
  String get handle {
    final segs = Uri.parse(url).pathSegments;
    if (segs.isEmpty) return '';
    final last = segs.last;
    return last.startsWith('@') ? last : '@$last';
  }
}
