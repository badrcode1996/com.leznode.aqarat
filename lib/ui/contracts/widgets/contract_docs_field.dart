import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);

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

  /// Storage download URLs already saved on the contract.
  final List<String> urls;

  /// Picked in this session — uploaded on submit.
  final List<XFile> pending;

  /// Whether the documents are appended to the printed PDF.
  bool printDocs;

  /// Uploads the pending images under the company's private folder and
  /// returns the full URL list (existing + new).
  Future<List<String>> uploadPending(String companyId) async {
    var seq = 0;
    while (pending.isNotEmpty) {
      final bytes = await pending.first.readAsBytes();
      final name = '${DateTime.now().millisecondsSinceEpoch}_${seq++}.jpg';
      final ref =
          FirebaseStorage.instance.ref('contract_docs/$companyId/$name');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
      pending.removeAt(0);
    }
    return urls;
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
            backgroundColor: Colors.red.shade700));
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
              leading: const Icon(Icons.photo_camera_outlined,
                  color: _primaryDarkBlue),
              title: const Text('کامێرا'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: _primaryDarkBlue),
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
                    color: Colors.red.shade700, shape: BoxShape.circle),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: _primaryDarkBlue),
              const SizedBox(width: 8),
              Text('بەڵگەکان',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800)),
              if (_count > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text('($_count)',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: _chooseSource,
                style: TextButton.styleFrom(foregroundColor: _primaryDarkBlue),
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
                    Image.network(url, fit: BoxFit.cover),
                    () => setState(() => _c.urls.remove(url)),
                  ),
                for (final file in List.of(_c.pending))
                  _thumb(
                    FutureBuilder<Uint8List>(
                      future: file.readAsBytes(),
                      builder: (_, snap) => snap.hasData
                          ? Image.memory(snap.data!, fit: BoxFit.cover)
                          : Container(color: Colors.grey.shade200),
                    ),
                    () => setState(() => _c.pending.remove(file)),
                  ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: _primaryDarkBlue,
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

/// Read-only attachments viewer (e.g. on the rent contract's installment
/// screen). Thumbnails open a full-screen zoomable view.
class ContractDocsViewer extends StatelessWidget {
  const ContractDocsViewer({super.key, required this.urls});

  final List<String> urls;

  void _open(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.network(
                  urls[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_open_outlined, color: _primaryDarkBlue),
              SizedBox(width: 8),
              Text('بەڵگەکان',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: _primaryDarkBlue)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < urls.length; i++)
                InkWell(
                  onTap: () => _open(context, i),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Image.network(urls[i], fit: BoxFit.cover),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
