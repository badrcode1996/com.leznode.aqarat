import '../../../theme/app_colors.dart';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';


/// Holds the attachment state for a contract form: already-uploaded URLs
/// (edit mode), newly picked-but-not-yet-uploaded images, and the
/// print-with-contract toggle. The stepper owns one instance and calls
/// [uploadPending] on submit.
class ContractDocsController {
  ContractDocsController({
    List<String>? urls,
    this.printDocs = true,
  })  : urls = List.of(urls ?? const []),
        pending = [];

  /// Storage object paths already saved on the contract. Older contracts hold
  /// a full https download URL here instead — [attachmentBytes] reads both.
  final List<String> urls;

  /// Picked in this session — uploaded on submit.
  final List<XFile> pending;

  /// Whether the documents are appended to the printed PDF.
  bool printDocs;

  /// Uploads the pending images under the company's private folder and
  /// returns the full reference list (existing + new).
  ///
  /// Stores the object *path*, never `getDownloadURL()`. A download URL
  /// carries a token that grants permanent unauthenticated access to the
  /// object, bypassing the company scoping in storage.rules — so one leaked
  /// link would expose an ID or deed to anyone. Paths are meaningless without
  /// credentials.
  Future<List<String>> uploadPending(String companyId) async {
    var seq = 0;
    while (pending.isNotEmpty) {
      final bytes = await pending.first.readAsBytes();
      final name = '${DateTime.now().millisecondsSinceEpoch}_${seq++}.jpg';
      final path = 'contract_docs/$companyId/$name';
      await FirebaseStorage.instance
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(path);
      pending.removeAt(0);
    }
    return urls;
  }
}

/// Attachment bytes, keyed by the stored reference. Storage reads are
/// authenticated round-trips, so hold the result for the session rather than
/// re-fetching on every rebuild.
final Map<String, Uint8List> _attachmentCache = {};

/// Reads an attachment through the Storage SDK, so the caller's credentials
/// are checked against storage.rules on every fetch.
///
/// [ref] is an object path for anything uploaded since attachments stopped
/// using download URLs, or a legacy https URL on older contracts — both
/// resolve to a Reference and neither is fetched anonymously.
Future<Uint8List> attachmentBytes(String ref) async {
  final cached = _attachmentCache[ref];
  if (cached != null) return cached;
  final storage = FirebaseStorage.instance;
  final r = ref.startsWith('http')
      ? storage.refFromURL(ref)
      : storage.ref(ref);
  final bytes = await r.getData(6 * 1024 * 1024) ?? Uint8List(0);
  _attachmentCache[ref] = bytes;
  return bytes;
}

/// An attachment rendered from authenticated bytes — the replacement for
/// `Image.network`, which would need a publicly fetchable URL.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage({
    super.key,
    required this.reference,
    this.fit = BoxFit.cover,
    this.loadingHeight = 120,
  });

  final String reference;
  final BoxFit fit;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: attachmentBytes(reference),
      builder: (_, snap) {
        if (snap.hasError) {
          return SizedBox(
            height: loadingHeight,
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.current.textFaint),
            ),
          );
        }
        if (!snap.hasData) {
          return SizedBox(
            height: loadingHeight,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Image.memory(snap.data!, fit: fit);
      },
    );
  }
}

/// "بەڵگەکان" section for the contract steppers: camera/gallery capture of
/// document photos, thumbnails with delete, and the print toggle.
class ContractDocsField extends StatefulWidget {
  const ContractDocsField({super.key, required this.controller});

  final ContractDocsController controller;

  @override
  State<ContractDocsField> createState() => _ContractDocsFieldState();
}

class _ContractDocsFieldState extends State<ContractDocsField> {
  final _picker = ImagePicker();

  ContractDocsController get _c => widget.controller;
  int get _count => _c.urls.length + _c.pending.length;

  Future<void> _pick(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final files = await _picker.pickMultiImage(
            imageQuality: 70, maxWidth: 1600);
        if (files.isNotEmpty) setState(() => _c.pending.addAll(files));
        return;
      }
      final file = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      if (file != null) setState(() => _c.pending.add(file));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('وێنە هەڵنەگیرا: $e'),
            backgroundColor: AppColors.current.danger));
      }
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: AppColors.current.textStrong),
              title: const Text('کامێرا'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.current.textStrong),
              title: const Text('گالەری'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(Widget image, VoidCallback onDelete) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 80, height: 80, child: image),
          ),
          Positioned(
            top: 2,
            left: 2,
            child: InkWell(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    color: AppColors.current.danger, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.current.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: AppColors.current.textStrong),
              const SizedBox(width: 8),
              Text('بەڵگەکان',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.current.textBody)),
              if (_count > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Text('($_count)',
                      style: TextStyle(color: AppColors.current.textMuted)),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: _chooseSource,
                style: TextButton.styleFrom(foregroundColor: AppColors.current.textStrong),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('زیادکردن'),
              ),
            ],
          ),
          if (_count > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final url in List.of(_c.urls))
                  _thumb(
                    AttachmentImage(reference: url, loadingHeight: 80),
                    () => setState(() => _c.urls.remove(url)),
                  ),
                for (final file in List.of(_c.pending))
                  _thumb(
                    FutureBuilder<Uint8List>(
                      future: file.readAsBytes(),
                      builder: (_, snap) => snap.hasData
                          ? Image.memory(snap.data!, fit: BoxFit.cover)
                          : Container(color: AppColors.current.divider),
                    ),
                    () => setState(() => _c.pending.remove(file)),
                  ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: AppColors.current.textStrong,
              title: const Text('چاپکردنی بەڵگەکان لەگەڵ گرێبەست',
                  style: TextStyle(fontSize: 13)),
              value: _c.printDocs,
              onChanged: (v) => setState(() => _c.printDocs = v),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen swipeable viewer for the attachment images, with share and
/// open-in-browser (download) actions for the page currently on screen.
class _DocsGallery extends StatefulWidget {
  const _DocsGallery({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_DocsGallery> createState() => _DocsGalleryState();
}

class _DocsGalleryState extends State<_DocsGallery> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), backgroundColor: AppColors.current.danger));
  }

  /// Shares the decoded image itself. Never the stored reference: when that
  /// is a legacy download URL it is a bearer token that would hand the
  /// recipient permanent, unauthenticated access to the original object.
  Future<void> _share() async {
    try {
      final bytes = await attachmentBytes(widget.urls[_index]);
      if (bytes.isEmpty) {
        _snack('بەڵگەکە دانەبەزێنرا');
        return;
      }
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          mimeType: 'image/jpeg',
          name: 'belge_${_index + 1}.jpg',
        ),
      ]);
    } catch (e) {
      _snack('هاوبەشکردن سەرکەوتوو نەبوو: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.urls.length}',
            style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: 'هاوبەشکردن / پاشەکەوتکردن',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _share,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: AttachmentImage(
              reference: widget.urls[i],
              fit: BoxFit.contain,
              loadingHeight: 200,
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only attachments viewer (e.g. on the rent contract's installment
/// screen). Thumbnails open a full-screen zoomable view.
class ContractDocsViewer extends StatelessWidget {
  const ContractDocsViewer({super.key, required this.urls});

  final List<String> urls;

  void _open(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _DocsGallery(urls: urls, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    // Cap the width so attachments don't stretch across a wide desktop
    // window — keep them a readable, page-like column, centred.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: _card(context),
      ),
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.current.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open_outlined, color: AppColors.current.textStrong),
              const SizedBox(width: 8),
              Text('بەڵگەکان',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
            ],
          ),
          const SizedBox(height: 12),
          // یەک بەڵگە لە هەر ڕیزێکدا، بە پانی تەواو
          for (var i = 0; i < urls.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Row(
              children: [
                Text('${i + 1} / ${urls.length}',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.current.textMuted)),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _open(context, i),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: AppColors.current.inputFill,
                  child: AttachmentImage(
                    reference: urls[i],
                    fit: BoxFit.contain,
                    loadingHeight: 200,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
