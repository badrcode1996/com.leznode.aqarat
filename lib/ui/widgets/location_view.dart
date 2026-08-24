import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'location_picker.dart' show kMapGestures;
import '../../l10n/app_strings.dart';
import '../../theme/app_colors.dart';

/// Read-only map showing where one property stands, opened from a listing.
///
/// A sheet rather than a page: it is a glance at a pin, and the listing behind
/// it stays where the agent left it. The Google Maps button hands the point to
/// the real Maps app, which is what actually gives directions — this map is for
/// recognising the street, not for driving to it.
class LocationView extends StatelessWidget {
  const LocationView({
    super.key,
    required this.lat,
    required this.lng,
    required this.title,
  });

  final double lat;
  final double lng;

  /// What the pin is — the project/district name off the listing.
  final String title;

  static Future<void> show(
    BuildContext context, {
    required double lat,
    required double lng,
    required String title,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.current.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => LocationView(lat: lat, lng: lng, title: title),
      );

  Future<void> _openInMaps() async {
    // The geo: scheme opens the installed Maps app on a phone but means nothing
    // to a browser, so the https URL is used everywhere — on a phone it hands
    // over to the Maps app just the same.
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    color: AppColors.current.brand, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title.isEmpty ? S.propertyLocation : title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.current.textStrong),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 300,
                child: GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: point, zoom: 17),
                  markers: {
                    Marker(markerId: const MarkerId('property'), position: point)
                  },
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  // Without this the sheet's drag-to-dismiss eats the pan and
                  // the map cannot be moved off the pin — see kMapGestures.
                  gestureRecognizers: kMapGestures,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openInMaps,
              icon: const Icon(Icons.directions_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.current.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              label: Text(S.openInMaps,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
