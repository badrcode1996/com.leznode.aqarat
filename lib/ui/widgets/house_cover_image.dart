import 'package:flutter/material.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _fill = Color(0xFFF3F4F6);

/// Cover image for a property/house card. Renders nothing when [url] is empty,
/// shows a spinner while loading and a placeholder if the image fails.
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
              : Container(
                  height: height,
                  color: _fill,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                      color: _primaryDarkBlue, strokeWidth: 2),
                ),
          errorBuilder: (_, __, ___) => Container(
            height: height,
            color: _fill,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined,
                color: Colors.grey.shade400, size: 40),
          ),
        ),
      ),
    );
  }
}
