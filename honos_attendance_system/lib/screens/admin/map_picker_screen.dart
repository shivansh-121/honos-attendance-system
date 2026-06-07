import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialCenter;
  const MapPickerScreen({super.key, this.initialCenter});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<dynamic> _suggestions = [];

  LatLng _center = const LatLng(28.6139, 77.2090); // Default to New Delhi
  bool _isSearching = false;
  bool _isLoadingLoc = false;
  String _address = "Move pin to select location";

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCenter != null) {
      _center = widget.initialCenter!;
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLoc = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final newCenter = LatLng(pos.latitude, pos.longitude);

      setState(() => _center = newCenter);
      _mapController.move(newCenter, 16.0);
      _reverseGeocode(newCenter);
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLoc = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 500), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lat=${_center.latitude}&lon=${_center.longitude}&limit=5');
      final response =
          await http.get(url, headers: {'User-Agent': 'HonosApp/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _suggestions = data['features'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSuggestionTapped(dynamic suggestion) {
    final coords = suggestion['geometry']['coordinates']; // [lon, lat]
    final props = suggestion['properties'];
    final name = props['name'] ?? '';
    final street = props['street'] ?? '';
    final city = props['city'] ?? props['state'] ?? '';

    List<String> addressParts = [];
    if (name.isNotEmpty) addressParts.add(name);
    if (street.isNotEmpty) addressParts.add(street);
    if (city.isNotEmpty) addressParts.add(city);

    final displayName = addressParts.join(', ');
    final newCenter = LatLng(coords[1], coords[0]);

    _searchCtrl.text = name.isNotEmpty ? name : displayName;
    _searchFocus.unfocus();

    setState(() {
      _suggestions = [];
      _center = newCenter;
      _address = displayName;
    });

    _mapController.move(newCenter, 16.0);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json');
      final response =
          await http.get(url, headers: {'User-Agent': 'HonosApp/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _address = data['display_name'] ?? "Unknown location";
          });
        }
      }
    } catch (e) {
      // Fail silently for reverse geocoding to not interrupt UX
      debugPrint("Reverse geocode error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgSurface,
      appBar: AppBar(
        title: const Text('Pin Location'),
        backgroundColor: context.colors.bgSurface,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && pos.center != null) {
                  setState(() {
                    _center = pos.center!;
                    _address = "Pin dropped...";
                  });
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _reverseGeocode(_center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.honos.attendance',
              ),
            ],
          ),

          // Center Crosshair Pin
          Center(
            child: Padding(
              padding: const EdgeInsets.only(
                  bottom: 40.0), // Offset to put point of pin at center
              child:
                  Icon(Icons.location_pin, color: context.colors.red, size: 40),
            ),
          ),

          // Search Bar Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.colors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8)
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          onChanged: _onSearchChanged,
                          style: TextStyle(color: context.colors.txtPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Search for building, street...',
                            border: InputBorder.none,
                          ),
                          onSubmitted: _onSearchChanged,
                        ),
                      ),
                      _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search, color: Colors.white70),
                    ],
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: context.colors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8)
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final s = _suggestions[index]['properties'];
                        final name = s['name'] ?? '';
                        final street = s['street'] ?? '';
                        final city = s['city'] ?? s['state'] ?? '';
                        final subtitle = [street, city]
                            .where((e) => e.isNotEmpty)
                            .join(', ');

                        return ListTile(
                          leading: Icon(Icons.location_on,
                              color: context.colors.primary),
                          title: Text(name.isNotEmpty ? name : subtitle,
                              style:
                                  TextStyle(color: context.colors.txtPrimary)),
                          subtitle: name.isNotEmpty && subtitle.isNotEmpty
                              ? Text(subtitle,
                                  style: TextStyle(
                                      color: context.colors.txtSec,
                                      fontSize: 12))
                              : null,
                          onTap: () => _onSuggestionTapped(_suggestions[index]),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Current Location FAB
          Positioned(
            bottom: 150,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'gps_fab',
              backgroundColor: context.colors.primary,
              onPressed: _getCurrentLocation,
              child: _isLoadingLoc
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.my_location),
            ),
          ),

          // Bottom Confirmation Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.bgSurface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.colors.txtPrimary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                      'Lat: ${_center.latitude.toStringAsFixed(5)} | Lng: ${_center.longitude.toStringAsFixed(5)}',
                      style: TextStyle(
                          color: context.colors.txtSec, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        foregroundColor: context.colors.bgBase,
                        backgroundColor: context.colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () {
                      Navigator.pop(context, {
                        'lat': _center.latitude,
                        'lng': _center.longitude,
                        'address': _address,
                      });
                    },
                    child: const Text('Confirm Location',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
