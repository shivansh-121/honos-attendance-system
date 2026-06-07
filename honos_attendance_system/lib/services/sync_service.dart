import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance.dart';

final syncProvider = Provider<SyncService>((ref) => SyncService());

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _gpsSub;

  // --- Real-Time Supervisor Location --- //
  
  void startSupervisorLiveTracking(String supervisorId) async {
    // 1. Check permissions
    if (kIsWeb) return; // Background tracking tricky on web, skip for demo

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. Start pushing location every few seconds to Firebase
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // updating every 10 meters
      )
    ).listen((Position position) {
      pushSupervisorLocation(supervisorId, position.latitude, position.longitude);
    });
  }

  void stopSupervisorLiveTracking(String supervisorId) {
    _gpsSub?.cancel();
    _gpsSub = null;
    try {
      _firestore.collection('live_supervisors').doc(supervisorId).update({'status': 'off-duty'});
    } catch (e) {
      debugPrint("Firestore Sync failed: $e");
    }
  }

  Future<void> pushSupervisorLocation(String supervisorId, double lat, double lng) async {
    try {
      await _firestore.collection('live_supervisors').doc(supervisorId).set({
        'lat': lat,
        'lng': lng,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'on-duty',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore Sync failed: $e");
    }
  }

  // --- Attendance Sync (Hive -> Firebase) --- //
  // OfflineQueueService has been removed. Firestore handles offline caching natively.

  Future<void> pushAttendance(Attendance record) async {
    try {
      await _firestore.collection('attendance').doc(record.id).set(record.toJson());
    } catch (e) {
      debugPrint("Firestore Sync failed: $e");
    }
  }

  // --- Map Listening (Admin checks Firestore) --- //
  
  Stream<QuerySnapshot<Map<String, dynamic>>> watchLiveSupervisors() {
    return _firestore.collection('live_supervisors').snapshots();
  }
}
