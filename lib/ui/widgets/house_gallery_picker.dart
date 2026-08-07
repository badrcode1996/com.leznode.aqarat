import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/property_model.dart';
import 'house_cover_image.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _accentYellow => AppColors.current.accent;
Color get _fill => AppColors.current.inputFill;

/// Photo gallery control for the listing form.
///
/// Holds a mixed list of already-stored photos and fresh picks, and reports it
/// back on every change. The parent keeps that list and hands it to the
/// repository, which works out what to upload and what to delete — so removing
/// a photo here is not destructive until the form is saved.
///
/// The first photo is the cover (it is what every card and the market show), so
/// promoting a photo is an explicit action rather than hidden drag-to-reorder.
class HouseGalleryPicker extends StatefulWidget {
  const HouseGalleryPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.label,
  });

  /// Photos already stored on the listing (empty when creating).
  final List<String> initial;

  final ValueChanged<List<ListingImage>> onChanged;

  /// Null means the standard heading — resolved at build time, because a
  /// translated string can't be a `const` default.
  final String? label;

  @override
  State<HouseGalleryPicker> createState() => _HouseGalleryPickerState();
}

class _HouseGalleryPickerState extends State<HouseGalleryPicker> {
  late final List<ListingImage> _images =
      widget.initial.map(ListingImage.stored).toList();

  bool get _isFull => _images.length >= kMaxListingImages;

  /// A copy goes out, so the parent's list is a snapshot rather than a live
  /// alias of the one this widget keeps mutating.
  void _emit() {
    setState(() {});
    widget.onChanged(List.of(_images));
  }

  Future<void> _addFrom(ImageSource source) async {
    final picker = ImagePicker();
    // Optimize on capture: cap width at 1200px (aspect ratio kept) + 85%
    // quality. Larger than the old single-photo cap because these are now
    // opened full-screen, but still small enough that ten of them upload on a
    // phone connection.
    const width = 1200.0;
    const quality = 85;

    final picked = <XFile>[];
    if (source == ImageSource.camera) {
      final one = await picker.pickImage(
          source: ImageSource.camera, maxWidth: width, imageQuality: quality);
      if (one != null) picked.add(one);
    } else {
      picked.addAll(await picker.pickMultiImage(
          maxWidth: width, imageQuality: quality));
    }
    if (picked.isEmpty) return;

    final room = kMaxListingImages - _images.length;
    for (final file in picked.take(room)) {
      final bytes = await file.readAsBytes();
      final contentType = file.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      _images.add(ListingImage.picked(bytes, contentType));
    }
    if (!mounted) return;
    if (picked.length > room) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.maxPhotos(kMaxListingImages)),
        backgroundColor: _primaryDarkBlue,
      ));
    }
    _emit();
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.current.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: AppColors.current.textStrong),
              title: Text(S.camera),
              onTap: () {
                Navigator.pop(context);
                _addFrom(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.current.textStrong),
              title: Text(S.gallery),
              subtitle: Text(S.galleryMultiHint,
                  style: const TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _addFrom(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openItemSheet(int index) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.current.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index != 0)
              ListTile(
                leading: Icon(Icons.star_outline_rounded,
                    color: _accentYellow),
                title: Text(S.makeCover),
                onTap: () {
                  Navigator.pop(context);
                  _images.insert(0, _images.removeAt(index));
                  _emit();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.current.danger),
              title:
                  Text(S.delete, style: TextStyle(color: AppColors.current.danger)),
              onTap: () {
                Navigator.pop(context);
                _images.removeAt(index);
                _emit();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label ?? S.propertyPhotos,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.current.textStrong)),
            const SizedBox(width: 6),
            Text('(${_images.length}/$kMaxListingImages)',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 12, color: AppColors.current.textMuted)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length + (_isFull ? 0 : 1),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) =>
                i == _images.length ? _addTile() : _imageTile(i),
          ),
        ),
        if (_images.isEmpty) ...[
          const SizedBox(height: 8),
          Text(S.firstIsCover,
              style: TextStyle(fontSize: 11.5, color: AppColors.current.textMuted)),
        ],
      ],
    );
  }

  Widget _addTile() => GestureDetector(
        onTap: _openAddSheet,
        child: const DottedAddBox(size: 100),
      );

  Widget _imageTile(int index) {
    final image = _images[index];
    return GestureDetector(
      onTap: () => _openItemSheet(index),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 100,
              height: 100,
              child: image.isNew
                  ? Image.memory(image.bytes!, fit: BoxFit.cover)
                  : HouseThumb(
                      url: image.url,
                      size: 100,
                      placeholder: Container(color: _fill),
                    ),
            ),
          ),
          // The cover badge is the only thing distinguishing photo 1, and it is
          // the one the cards and the market actually show.
          if (index == 0)
            PositionedDirectional(
              start: 4,
              top: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _accentYellow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(S.coverBadge,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.current.onAccent)),
              ),
            ),
          PositionedDirectional(
            end: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_horiz_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed "add a photo" tile at the end of the strip.
class DottedAddBox extends StatelessWidget {
  const DottedAddBox({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.current.divider, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 26, color: AppColors.current.textStrong),
            const SizedBox(height: 4),
            Text(S.addPhoto,
                style: TextStyle(fontSize: 11, color: AppColors.current.textMuted)),
          ],
        ),
      );
}
