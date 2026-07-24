import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _fill = Color(0xFFF3F4F6);

/// Fetched house-image bytes, keyed by URL. Image.network refetched on every
/// rebuild anyway; this keeps the SDK read to once per image per session.
final _coverCache = <String, Uint8List>{};

/// Reads a house image through the Storage SDK rather than `Image.network`.
///
/// On Flutter web a tokenised download URL rendered with `Image.network` fails
/// to paint under CanvasKit; fetching the bytes with the SDK and drawing them
/// as `Image.memory` is the same approach the contract attachments use, and it
/// works on every platform. Accepts either a download URL (older listings) or a
/// Storage object path.
Future<Uint8List> _coverBytes(String ref) async {
  final cached = _coverCache[ref];
  if (cached != null) return cached;
  final storage = FirebaseStorage.instance;
  final r = ref.startsWith('http') ? storage.refFromURL(ref) : storage.ref(ref);
  final bytes = await r.getData(10 * 1024 * 1024) ?? Uint8List(0);
  _coverCache[ref] = bytes;
  return bytes;
}

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
        child: FutureBuilder<Uint8List>(
          future: _coverBytes(url),
          builder: (_, snap) {
            if (snap.hasError ||
                (snap.hasData && snap.data!.isEmpty)) {
              return _box(Icon(Icons.broken_image_outlined,
                  color: Colors.grey.shade400, size: 40));
            }
            if (!snap.hasData) {
              return _box(const CircularProgressIndicator(
                  color: _primaryDarkBlue, strokeWidth: 2));
            }
            return Image.memory(
              snap.data!,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
            );
          },
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

/// A fixed-size square house thumbnail, loaded the same SDK way as
/// [HouseCoverImage]. Shows [placeholder] while loading and on failure, so the
/// caller controls the empty look. Returns [placeholder] directly when [url] is
/// empty.
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
      child: FutureBuilder<Uint8List>(
        future: _coverBytes(url),
        builder: (_, snap) {
          if (snap.hasError || (snap.hasData && snap.data!.isEmpty)) {
            return placeholder;
          }
          if (!snap.hasData) return placeholder;
          return Image.memory(snap.data!,
              width: size, height: size, fit: BoxFit.cover);
        },
      ),
    );
  }
}
