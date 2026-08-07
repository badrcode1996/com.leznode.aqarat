import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_colors.dart';

Color get _fill => AppColors.current.inputFill;

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

/// Swipeable photo gallery for a listing card. Falls back to nothing when the
/// listing has no photos, so a card can drop it in unconditionally.
///
/// Only the visible page is fetched — [PageView] builds lazily and
/// [houseImageBytes] caches — so a ten-photo listing costs one download until
/// the user actually swipes.
class HouseGallery extends StatefulWidget {
  const HouseGallery({super.key, required this.urls, this.height = 180});

  final List<String> urls;
  final double height;

  @override
  State<HouseGallery> createState() => _HouseGalleryState();
}

class _HouseGalleryState extends State<HouseGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullScreen() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _FullScreenGallery(urls: widget.urls, initial: _page),
    ));
  }

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    if (widget.urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              // The pager is laid out LTR: swiping through photos is a spatial
              // gesture, and mirroring it would put photo 2 to the left of
              // photo 1 while the counter still counts up.
              Directionality(
                textDirection: TextDirection.ltr,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.urls.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: _openFullScreen,
                    child: _GalleryPage(url: widget.urls[i], fit: BoxFit.cover),
                  ),
                ),
              ),
              if (widget.urls.length > 1) ...[
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_page + 1}/${widget.urls.length}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.urls.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: i == _page ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One photo, fetched over plain HTTP like everything else here.
class _GalleryPage extends StatelessWidget {
  const _GalleryPage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    return FutureBuilder<Uint8List>(
      future: houseImageBytes(url),
      builder: (_, snap) {
        if (snap.hasError) {
          return Container(
            color: _fill,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined,
                color: AppColors.current.textFaint, size: 40),
          );
        }
        if (!snap.hasData) {
          return Container(
            color: _fill,
            alignment: Alignment.center,
            child: CircularProgressIndicator(
                color: AppColors.current.textStrong, strokeWidth: 2),
          );
        }
        return Image.memory(snap.data!,
            width: double.infinity, height: double.infinity, fit: fit);
      },
    );
  }
}

/// Full-screen, pinch-zoomable view of the gallery.
class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.urls, required this.initial});

  final List<String> urls;
  final int initial;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller =
      PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('${_page + 1} / ${widget.urls.length}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 15)),
          centerTitle: true,
        ),
        body: Directionality(
          textDirection: TextDirection.ltr,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: _GalleryPage(url: widget.urls[i], fit: BoxFit.contain),
            ),
          ),
        ),
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
    watchAppShell(context);
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
