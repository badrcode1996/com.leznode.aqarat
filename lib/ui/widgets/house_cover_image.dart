import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _fill = Color(0xFFF3F4F6);

/// Fetched image bytes, keyed by the stored reference.
final _bytesCache = <String, Uint8List>{};

/// A tokenless download URL for a stored image reference. `property_images` is
/// public-read, so the object is fetched with a plain HTTP GET — no auth, no
/// Storage SDK. A stored value is a full download URL (keep host and encoded
/// path, drop the query's dead token) or a bare object path (build the URL).
String publicImageUrl(String ref) {
  if (ref.isEmpty) return ref;
  if (!ref.startsWith('http')) {
    const bucket = 'aqarat-49fc2.firebasestorage.app';
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket'
        '/o/${Uri.encodeComponent(ref)}?alt=media';
  }
  // Plain string cut so the already-encoded %2F path segment is preserved;
  // parsing would decode %2F to /, which GCS reads as a different object.
  final q = ref.indexOf('?');
  final base = q == -1 ? ref : ref.substring(0, q);
  return '$base?alt=media';
}

/// Fetches the image bytes over plain HTTP.
///
/// Image.network under the web CanvasKit renderer fails to paint cross-origin
/// Storage images even when the object is public and CORS is open; fetching the
/// bytes ourselves and handing them to Image.memory avoids that path entirely.
Future<Uint8List> houseImageBytes(String ref) async {
  final cached = _bytesCache[ref];
  if (cached != null) return cached;
  final res = await http.get(Uri.parse(publicImageUrl(ref)));
  if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
    throw Exception('image ${res.statusCode}');
  }
  _bytesCache[ref] = res.bodyBytes;
  return res.bodyBytes;
}

/// Cover image for a property/house card. Renders nothing when [url] is empty,
/// a spinner while loading, and a placeholder if the image fails.
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
          future: houseImageBytes(url),
          builder: (_, snap) {
            if (snap.hasError) {
              return _box(Icon(Icons.broken_image_outlined,
                  color: Colors.grey.shade400, size: 40));
            }
            if (!snap.hasData) {
              return _box(const CircularProgressIndicator(
                  color: _primaryDarkBlue, strokeWidth: 2));
            }
            return Image.memory(snap.data!,
                height: height, width: double.infinity, fit: BoxFit.cover);
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

/// A fixed-size square house thumbnail. Shows [placeholder] while loading and on
/// failure. Returns [placeholder] directly when [url] is empty.
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
        future: houseImageBytes(url),
        builder: (_, snap) {
          if (snap.hasError || !snap.hasData) return placeholder;
          return Image.memory(snap.data!,
              width: size, height: size, fit: BoxFit.cover);
        },
      ),
    );
  }
}
