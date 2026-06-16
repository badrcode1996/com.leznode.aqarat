import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentYellow = Color(0xFFF8B115);

/// A single "profile photo"–style picker for a house image. Tapping it opens a
/// sheet to choose Camera or Gallery, previews the pick, and reports the bytes
/// (+ content type) to the parent via [onChanged]. Pass [initialImageUrl] to
/// show an already-saved image (edit mode).
class HouseImagePicker extends StatefulWidget {
  const HouseImagePicker({
    super.key,
    required this.onChanged,
    this.initialImageUrl = '',
    this.label = 'وێنەی خانوو',
  });

  /// Called with the picked bytes + content type (e.g. 'image/jpeg').
  final void Function(Uint8List bytes, String contentType) onChanged;
  final String initialImageUrl;
  final String label;

  @override
  State<HouseImagePicker> createState() => _HouseImagePickerState();
}

class _HouseImagePickerState extends State<HouseImagePicker> {
  Uint8List? _bytes;

  Future<void> _pick(ImageSource source) async {
    // Optimize on capture: cap width at 800px (aspect ratio kept) + 85% quality
    // so uploads stay light on Storage.
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final contentType =
        picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    setState(() => _bytes = bytes);
    widget.onChanged(bytes, contentType);
  }

  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: _primaryDarkBlue),
              title: const Text('کامێرا'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: _primaryDarkBlue),
              title: const Text('گەلەری'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNetwork = _bytes == null && widget.initialImageUrl.isNotEmpty;
    final ImageProvider? image = _bytes != null
        ? MemoryImage(_bytes!)
        : (hasNetwork ? NetworkImage(widget.initialImageUrl) : null);
    return Column(
      children: [
        GestureDetector(
          onTap: _openSheet,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xFFF3F4F6),
                backgroundImage: image,
                child: image == null
                    ? const Icon(Icons.add_a_photo_outlined,
                        size: 30, color: _primaryDarkBlue)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: _accentYellow, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt,
                      size: 16, color: _primaryDarkBlue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }
}
