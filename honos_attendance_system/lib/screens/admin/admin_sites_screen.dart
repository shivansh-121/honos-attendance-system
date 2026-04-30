import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../services/db_service.dart';
import '../../services/app_nav.dart';
import '../../models/site.dart';
import '../../app_theme.dart';
import 'map_picker_screen.dart';

class AdminSitesScreen extends ConsumerStatefulWidget {
  const AdminSitesScreen({super.key});

  @override
  ConsumerState<AdminSitesScreen> createState() => _AdminSitesScreenState();
}

class _AdminSitesScreenState extends ConsumerState<AdminSitesScreen> {
  final bool _gettingLocation = false;

  Future<void> _addNewSite(BuildContext context) async {
    final result = await AppNav.push(context, const MapPickerScreen());
    if (result == null) return;

    final lat = result['lat'] as double;
    final lng = result['lng'] as double;
    final mapAddress = result['address'] as String;

    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController(text: mapAddress);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('New Geofenced Site',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Location Acquired:\nLat: ${lat.toStringAsFixed(4)}\nLng: ${lng.toStringAsFixed(4)}',
                style: const TextStyle(color: AppTheme.green, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Site Name (e.g., North Gate)')),
            const SizedBox(height: 8),
            TextField(
                controller: addressCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;
              final newSite = Site(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                lat: lat,
                lng: lng,
                radius: 200, // Default 200m
              );
              ref.read(dbProvider).saveSite(newSite);
              Navigator.pop(ctx);
            },
            child: const Text('Save Site'),
          ),
        ],
      ),
    );
  }

  void _adjustRadius(Site site) {
    double currentRadius = site.radius;
    showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.bgSurface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(
              builder: (context, setSt) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Adjust Geofence Radius',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Site: ${site.name}',
                        style: const TextStyle(color: AppTheme.txtSec)),
                    const SizedBox(height: 24),
                    Text('${currentRadius.toInt()} Meters',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                    Slider(
                      value: currentRadius,
                      min: 10,
                      max: 1000,
                      divisions: 99,
                      activeColor: AppTheme.primary,
                      onChanged: (val) => setSt(() => currentRadius = val),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Radius'),
                      onPressed: () {
                        final updatedSite = Site(
                            id: site.id,
                            name: site.name,
                            address: site.address,
                            lat: site.lat,
                            lng: site.lng,
                            radius: currentRadius,
                            supervisorId: site.supervisorId);
                        ref.read(dbProvider).saveSite(updatedSite);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Geofence updated!')));
                      },
                    ),
                  ],
                ),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites & Geofencing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: const Color(0xFF1B3B60).withOpacity(0.5)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewSite(context),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Pin New Site'),
        backgroundColor: AppTheme.green,
      ).animate().scale(),
      body: sitesAsync.when(
        data: (sites) {
          if (sites.isEmpty) {
            return const Center(
                child: Text('No sites found.',
                    style: TextStyle(color: Colors.white54)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sites.length,
            itemBuilder: (ctx, i) {
              final site = sites[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white.withOpacity(0.05),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF1B3B60),
                        child: Icon(Icons.business, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(site.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                                'Radius: ${site.radius.toInt()}m | ${site.address}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _adjustRadius(site),
                            child: const Text('Adjust',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: AppTheme.red, size: 22),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppTheme.bgSurface,
                                  title: const Text('Delete Site',
                                      style: TextStyle(color: Colors.white)),
                                  content: const Text(
                                      'Are you sure you want to delete this site?',
                                      style: TextStyle(color: AppTheme.txtSec)),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete',
                                            style: TextStyle(
                                                color: AppTheme.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                ref.read(dbProvider).deleteSite(site.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (100 * i).ms).slideX();
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child:
                Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
