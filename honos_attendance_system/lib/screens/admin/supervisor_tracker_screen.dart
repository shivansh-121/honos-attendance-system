import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/sync_service.dart';
import '../../services/db_service.dart';
import '../../app_theme.dart';

// Colours for each supervisor's polyline
const _pathColours = [
  Colors.orange,
  Colors.cyan,
  Colors.pink,
  Colors.lime,
  Colors.purple,
];

class SupervisorTrackerScreen extends ConsumerWidget {
  const SupervisorTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.read(syncProvider);
    final sitesAsync = ref.watch(sitesStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Live Supervisor Tracker')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: syncService.watchLiveSupervisors(),
        builder: (context, snapshot) {
          final activeSupervisors = <String, Map<String, dynamic>>{};

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data();
              if (data['status'] == 'on-duty') {
                activeSupervisors[doc.id] = data;
              }
            }
          }

          return sitesAsync.when(
            data: (sites) => usersAsync.when(
              data: (users) => _TrackerMapBody(
                activeSupervisors: activeSupervisors,
                sites: sites,
                users: users,
                syncService: syncService,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text('Error: $e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(child: Text('Geofence Load Error: $e')),
          );
        },
      ),
    );
  }
}

// ── Map body — stateful so it can hold StreamBuilders for paths ───────────────
class _TrackerMapBody extends StatefulWidget {
  final Map<String, Map<String, dynamic>> activeSupervisors;
  final List sites;
  final List users;
  final SyncService syncService;

  const _TrackerMapBody({
    required this.activeSupervisors,
    required this.sites,
    required this.users,
    required this.syncService,
  });

  @override
  State<_TrackerMapBody> createState() => _TrackerMapBodyState();
}

class _TrackerMapBodyState extends State<_TrackerMapBody> {
  // supervisorId -> list of their breadcrumb coordinates
  final Map<String, List<LatLng>> _paths = {};
  final Map<String, dynamic> _pathStreams = {};

  @override
  void didUpdateWidget(_TrackerMapBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupPathStreams();
  }

  @override
  void initState() {
    super.initState();
    _setupPathStreams();
  }

  void _setupPathStreams() {
    // Subscribe to path_points sub-collection for each active supervisor
    for (final entry in widget.activeSupervisors.entries) {
      final supId = entry.key;
      if (_pathStreams.containsKey(supId)) continue; // already subscribed

      final stream = FirebaseFirestore.instance
          .collection('live_supervisors')
          .doc(supId)
          .collection('path_points')
          .orderBy('ts')
          .snapshots();

      _pathStreams[supId] = stream.listen((snap) {
        final pts = snap.docs.map((d) {
          final data = d.data();
          return LatLng(
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          );
        }).toList();
        if (mounted) {
          setState(() => _paths[supId] = pts);
        }
      });
    }

    // Cancel streams for supervisors who went off-duty
    final toRemove = _pathStreams.keys
        .where((id) => !widget.activeSupervisors.containsKey(id))
        .toList();
    for (final id in toRemove) {
      (_pathStreams[id] as dynamic)?.cancel();
      _pathStreams.remove(id);
      _paths.remove(id);
    }
  }

  @override
  void dispose() {
    for (final s in _pathStreams.values) {
      (s as dynamic)?.cancel();
    }
    super.dispose();
  }

  String _getSupName(String supId) {
    final match = widget.users.where((u) => u.id == supId);
    return match.isNotEmpty ? match.first.name : supId;
  }

  @override
  Widget build(BuildContext context) {
    final supEntries = widget.activeSupervisors.entries.toList();
    int colourIndex = 0;

    // Build polylines and markers
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    for (final entry in supEntries) {
      final supId = entry.key;
      final data = entry.value;
      final colour = _pathColours[colourIndex % _pathColours.length];
      colourIndex++;

      final path = _paths[supId] ?? [];
      if (path.length >= 2) {
        polylines.add(Polyline(
          points: path,
          color: colour,
          strokeWidth: 4.0,
        ));
      }

      markers.add(Marker(
        point: LatLng(
          (data['lat'] as num).toDouble(),
          (data['lng'] as num).toDouble(),
        ),
        width: 50,
        height: 60,
        child: Column(
          children: [
            Icon(Icons.gps_fixed,
                color: colour,
                size: 28,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colour.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getSupName(supId).split(' ').first,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ));
    }

    // Default map center
    final defaultCenter = widget.sites.isNotEmpty
        ? LatLng((widget.sites.first.lat as num).toDouble(),
            (widget.sites.first.lng as num).toDouble())
        : const LatLng(21.1612, 72.8703);

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: defaultCenter,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.honos.attendance',
            ),

            // Geofence Circles
            CircleLayer(
              circles: widget.sites
                  .map((site) => CircleMarker(
                        point: LatLng((site.lat as num).toDouble(),
                            (site.lng as num).toDouble()),
                        color: AppTheme.primary.withOpacity(0.15),
                        borderStrokeWidth: 2,
                        borderColor: AppTheme.primary,
                        radius: (site.radius as num).toDouble(),
                        useRadiusInMeter: true,
                      ))
                  .toList(),
            ),

            // Supervisor Path Polylines
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),

            // Supervisor Markers
            MarkerLayer(markers: markers),
          ],
        ),

        // Status / Legend overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: widget.activeSupervisors.isEmpty
              ? const Card(
                  color: AppTheme.cardBg,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.txtMuted),
                        SizedBox(width: 12),
                        Text('No supervisors currently On‑Duty.',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              : Card(
                  color: AppTheme.cardBg.withOpacity(0.92),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🟢 On-Duty Supervisors',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...supEntries.asMap().entries.map((e) {
                          final colour =
                              _pathColours[e.key % _pathColours.length];
                          final supId = e.value.key;
                          final pathLen = _paths[supId]?.length ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: colour, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text(_getSupName(supId),
                                    style: const TextStyle(fontSize: 12)),
                                const Spacer(),
                                Text('$pathLen pts',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.txtMuted)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
