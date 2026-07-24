import 'package:flutter/material.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _fill = Color(0xFFF3F4F6);

/// Cover image for a property/house card.
///
/// Listing photos are stored as tokenised Storage download URLs and shown with
/// `Image.network`. That is a plain, credential-free GET — the same request the
/// company logo makes — so it paints on web without the CORS preflight that an
/// authenticated `getData()` fetch would need. Renders nothing when [url] is
/// empty, a spinner while loading, and a placeholder if the image fails.
class HouseCoverImage extends StatelessWidget {
  const HouseCoverImage({super.key, required this.url, this.height = 160});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) => progress == null
              ? child
              : _box(const CircularProgressIndicator(
                  color: _primaryDarkBlue, strokeWidth: 2)),
          errorBuilder: (_, __, ___) => _box(Icon(Icons.broken_image_outlined,
              color: Colors.grey.shade400, size: 40)),
        ),
      ),
    );
  }

  Widget _box(Widget child) => Container(
        height: height,
        width: double.infinity,
        color: _fill,
        alignment: Alignment.center,
        child: child,
      );
}

/// A fixed-size square house thumbnail. Shows [placeholder] while loading and on
/// failure, so the caller controls the empty look. Returns [placeholder]
/// directly when [url] is empty.
class HouseThumb extends StatelessWidget {
  const HouseThumb({
    super.key,
    required this.url,
    required this.size,
    required this.placeholder,
  });

  final String url;
  final double size;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (ctx, child, prog) => prog == null ? child : placeholder,
      ),
    );
  }
}
