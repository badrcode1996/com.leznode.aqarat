import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_colors.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _fill => AppColors.current.inputFill;

/// Erbil city centre — where the map opens when nothing is pinned yet. A map
/// centred on the Atlantic would make every agent pan across a continent
/// before they could work.
const LatLng _kFallbackCentre = LatLng(36.1911, 44.0092);

/// Map control for the listing form: pins where the property stands.
///
/// Two ways in, because both happen. An agent standing at the property taps
/// "my location" and is done; one typing the listing up at the office drags
/// the pin onto the street they know. Either way the parent is handed the
/// point, and holds it until the form is saved — nothing here writes.
///
/// A listing with no pin is normal and stays possible: the control starts
/// empty, and [onChanged] is given null when the pin is cleared. A wrong pin
/// on a legal listing is worse than no pin, so it is never guessed.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.lat,
    required this.lng,
    required this.onChanged,
  });

  final double? lat;
  final double? lng;

  /// Both halves, or both null. See PropertyListing.hasLocation.
  final void Function(double? lat, double? lng) onChanged;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _map;
  bool _locating = false;

  LatLng? get _pin => (widget.lat != null && widget.lng != null)
      ? LatLng(widget.lat!, widget.lng!)
      : null;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  void _setPin(LatLng p) {
    widget.onChanged(p.latitude, p.longitude);
    _map?.animateCamera(CameraUpdate.newLatLng(p));
  }

  /// Moves the pin to where the device is.
  ///
  /// Permission is requested only when the button is pressed, never on open:
  /// an agent listing a property from the office has no reason to be asked for
  /// their whereabouts, and a prompt they did not ask for is the one they deny
  /// permanently.
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _complain(S.locationServiceOff);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _complain(S.locationDenied);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      if (!mounted) return;
      _setPin(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      _complain(S.locationFailed);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _complain(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), backgroundColor: AppColors.current.danger));
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(S.propertyLocation,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.current.textStrong)),
            const Spacer(),
            if (pin != null)
              TextButton.icon(
                onPressed: () => widget.onChanged(null, null),
                icon: const Icon(Icons.close_rounded, size: 18),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.current.danger),
                label: Text(S.clearLocation),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: pin ?? _kFallbackCentre, zoom: pin == null ? 12 : 17),
                  onMapCreated: (c) => _map = c,
                  // Tapping the map IS the placement gesture — no long-press to
                  // discover, and no separate "confirm" step to forget.
                  onTap: _setPin,
                  markers: pin == null
                      ? const {}
                      : {
                          Marker(
                            markerId: const MarkerId('property'),
                            position: pin,
                            draggable: true,
                            onDragEnd: (p) =>
                                widget.onChanged(p.latitude, p.longitude),
                          ),
                        },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                if (pin == null)
                  IgnorePointer(
                    child: Container(
                      alignment: Alignment.center,
                      color: Colors.black.withValues(alpha: 0.25),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          S.tapMapToPin,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded, size: 18),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryDarkBlue,
                    backgroundColor: _fill,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                label: Text(S.useMyLocation),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
