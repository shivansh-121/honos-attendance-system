import 'dart:convert';
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
  
  LatLng _center = const LatLng(28.6139, 77.2090); // Default to New Delhi
  bool _isSearching = false;
  bool _isLoadingLoc = false;
  String _address = "Move pin to select location";

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
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'HonosApp/1.0'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newCenter = LatLng(lat, lon);
          
          setState(() {
            _center = newCenter;
            _address = data[0]['display_name'];
          });
          _mapController.move(newCenter, 16.0);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address not found')));
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json');
      final response = await http.get(url, headers: {'User-Agent': 'HonosApp/1.0'});
      
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
      backgroundColor: AppTheme.bgSurface,
      appBar: AppBar(
        title: const Text('Pin Location'),
        backgroundColor: AppTheme.bgSurface,
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
                urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.honos.attendance',
              ),
            ],
          ),
          
          // Center Crosshair Pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0), // Offset to put point of pin at center
              child: Icon(Icons.location_pin, color: AppTheme.red, size: 40),
            ),
          ),
          
          // Search Bar Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search for building, street...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: _searchAddress,
                    ),
                  ),
                  _isSearching 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.search, color: Colors.white70),
                          onPressed: () => _searchAddress(_searchCtrl.text),
                        ),
                ],
              ),
            ),
          ),
          
          // Current Location FAB
          Positioned(
            bottom: 150,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'gps_fab',
              backgroundColor: AppTheme.primary,
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
              decoration: const BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Lat: ${_center.latitude.toStringAsFixed(5)} | Lng: ${_center.longitude.toStringAsFixed(5)}', style: const TextStyle(color: AppTheme.txtSec, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () {
                      Navigator.pop(context, {
                        'lat': _center.latitude,
                        'lng': _center.longitude,
                        'address': _address,
                      });
                    },
                    child: const Text('Confirm Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
