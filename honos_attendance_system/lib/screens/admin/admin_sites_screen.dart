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
  Future<void> _addNewSite(BuildContext context) async {
    final result = await AppNav.push(context, const MapPickerScreen());
    if (result == null) return;

    final lat = result['lat'] as double;
    final lng = result['lng'] as double;
    final mapAddress = result['address'] as String;

    if (!context.mounted) return;

    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController(text: mapAddress);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Geofenced Site',
            style: TextStyle(
                color: context.colors.txtPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: context.colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                  'Location Acquired:\nLat: ${lat.toStringAsFixed(4)}\nLng: ${lng.toStringAsFixed(4)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            TextField(
                controller: nameCtrl,
                style: TextStyle(color: context.colors.txtPrimary),
                decoration: InputDecoration(
                    labelText: 'Site Name (e.g., North Gate)',
                    labelStyle: TextStyle(color: context.colors.txtMuted),
                    filled: true,
                    fillColor: context.colors.bgBase,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(
                controller: addressCtrl,
                style: TextStyle(color: context.colors.txtPrimary),
                decoration: InputDecoration(
                    labelText: 'Address',
                    labelStyle: TextStyle(color: context.colors.txtMuted),
                    filled: true,
                    fillColor: context.colors.bgBase,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: context.colors.txtSec))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: context.colors.bgBase,
              backgroundColor: context.colors.primary,
            ),
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
        backgroundColor: context.colors.bgSurface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(
              builder: (context, setSt) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Adjust Geofence Radius',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.colors.txtPrimary)),
                    const SizedBox(height: 8),
                    Text('Site: ${site.name}',
                        style: TextStyle(color: context.colors.txtSec)),
                    const SizedBox(height: 24),
                    Text('${currentRadius.toInt()} Meters',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: context.colors.primary)),
                    Slider(
                      value: currentRadius,
                      min: 10,
                      max: 1000,
                      divisions: 99,
                      activeColor: context.colors.primary,
                      onChanged: (val) => setSt(() => currentRadius = val),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: context.colors.bgBase,
                        backgroundColor: context.colors.primary,
                      ),
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
      backgroundColor: context.colors.bgBase,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewSite(context),
        icon: Icon(Icons.add_location_alt, color: context.colors.bgBase),
        label: Text('Pin New Site',
            style: TextStyle(
                color: context.colors.bgBase, fontWeight: FontWeight.bold)),
        backgroundColor: context.colors.green,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 2.seconds, color: Colors.white24),
      body: responsiveBody(CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: context.colors.bgBase,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground
              ],
              titlePadding:
                  const EdgeInsets.only(left: 24, bottom: 20, right: 24),
              title: const Text('Sites & Geofencing',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.5)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1B3B60),
                          context.colors.primary
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -60,
                    right: -40,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1)),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.15, 1.15),
                        duration: 4.seconds,
                        curve: Curves.easeInOut),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08)),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                        begin: const Offset(1.15, 1.15),
                        end: const Offset(1, 1),
                        duration: 3.seconds,
                        curve: Curves.easeInOut),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 40,
                    child: Transform.rotate(
                      angle: -0.1,
                      child: Icon(Icons.apartment_rounded,
                          size: 140,
                          color: Colors.white.withValues(alpha: 0.15)),
                    ).animate().fadeIn(duration: 800.ms).slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 800.ms,
                        curve: Curves.easeOutBack),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          sitesAsync.when(
            data: (sites) {
              if (sites.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off_rounded,
                                size: 80,
                                color: context.colors.txtMuted
                                    .withValues(alpha: 0.3))
                            .animate()
                            .scale(
                                delay: 200.ms,
                                duration: 400.ms,
                                curve: Curves.easeOutBack),
                        const SizedBox(height: 20),
                        Text('No sites found.',
                            style: TextStyle(
                                color: context.colors.txtSec,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }
              return ResponsiveSliverPadding(
                extraPadding: const EdgeInsets.fromLTRB(0, 24, 0, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final site = sites[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.colors.bgSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color:
                                  context.colors.bord.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                                color: context.colors.primary
                                    .withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: context.colors.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle),
                                  child: Icon(Icons.business,
                                      color: context.colors.primary),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(site.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: context.colors.txtPrimary,
                                              fontSize: 18,
                                              letterSpacing: -0.3)),
                                      const SizedBox(height: 4),
                                      Text('Radius: ${site.radius.toInt()}m',
                                          style: TextStyle(
                                              color: context.colors.primary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on,
                                    size: 16, color: context.colors.txtMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(site.address,
                                        style: TextStyle(
                                            color: context.colors.txtSec,
                                            fontSize: 13))),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: context.colors.primary
                                          .withValues(alpha: 0.1),
                                      foregroundColor: context.colors.primary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _adjustRadius(site),
                                    icon: const Icon(Icons.tune, size: 18),
                                    label: const Text('Adjust Radius',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: context.colors.red
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Delete Site',
                                    icon: Icon(Icons.delete_outline,
                                        color: context.colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor:
                                              context.colors.bgSurface,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          title: Text('Delete Site',
                                              style: TextStyle(
                                                  color:
                                                      context.colors.txtPrimary,
                                                  fontWeight: FontWeight.bold)),
                                          content: Text(
                                              'Are you sure you want to delete this site?',
                                              style: TextStyle(
                                                  color:
                                                      context.colors.txtSec)),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: Text('Cancel',
                                                    style: TextStyle(
                                                        color: context
                                                            .colors.txtSec))),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text('Delete',
                                                    style: TextStyle(
                                                        color:
                                                            context.colors.red,
                                                        fontWeight:
                                                            FontWeight.bold))),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        ref
                                            .read(dbProvider)
                                            .deleteSite(site.id);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (40 * i).ms).slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOut);
                    },
                    childCount: sites.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
                child: Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: Colors.red)))),
          ),
        ],
      )),
    );
  }
}
