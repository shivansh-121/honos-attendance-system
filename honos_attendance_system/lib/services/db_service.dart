import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guard.dart';
import '../models/site.dart';
import '../models/attendance.dart';
import '../models/app_user.dart';

final dbProvider = Provider<DbService>((ref) => DbService());

// ── keepAlive: true prevents re-fetching when widget unmounts/remounts ────────

final usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  ref.keepAlive();
  return ref.watch(dbProvider).usersStream();
});

final sitesStreamProvider = StreamProvider<List<Site>>((ref) {
  ref.keepAlive();
  return ref.watch(dbProvider).sitesStream();
});

final guardsStreamProvider = StreamProvider<List<Guard>>((ref) {
  ref.keepAlive();
  return ref.watch(dbProvider).guardsStream();
});

final attendanceStreamProvider = StreamProvider<List<Attendance>>((ref) {
  ref.keepAlive();
  return ref.watch(dbProvider).attendanceStream();
});

/// Scoped to today only — much faster than fetching all attendance records
final todayAttendanceProvider = StreamProvider<List<Attendance>>((ref) {
  ref.keepAlive();
  final today = DateTime.now().toIso8601String().split('T').first;
  return ref.watch(dbProvider).attendanceStreamForDate(today);
});

class DbService {
  final _firestore = FirebaseFirestore.instance;

  // --- Users ---
  Stream<List<AppUser>> usersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromJson(doc.data())).toList();
    });
  }

  Future<void> saveUser(AppUser user) async {
    await _firestore.collection('users').doc(user.id).set(user.toJson());
  }

  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  // --- Sites ---
  Stream<List<Site>> sitesStream() {
    return _firestore.collection('sites').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Site.fromJson(doc.data())).toList();
    });
  }

  Future<void> saveSite(Site site) async {
    await _firestore.collection('sites').doc(site.id).set(site.toJson());
  }

  Future<void> deleteSite(String siteId) async {
    await _firestore.collection('sites').doc(siteId).delete();
  }

  // --- Guards ---
  Stream<List<Guard>> guardsStream() {
    return _firestore.collection('guards').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Guard.fromJson(doc.data())).toList();
    });
  }

  Future<void> saveGuard(Guard guard) async {
    await _firestore.collection('guards').doc(guard.id).set(guard.toJson());
  }

  Future<void> deleteGuard(String guardId) async {
    await _firestore.collection('guards').doc(guardId).delete();
  }

  // --- Attendance ---
  Stream<List<Attendance>> attendanceStream() {
    return _firestore.collection('attendance').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Attendance.fromJson(doc.data())).toList();
    });
  }

  /// Today-only query — avoids loading entire attendance history on every screen
  Stream<List<Attendance>> attendanceStreamForDate(String date) {
    return _firestore
        .collection('attendance')
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Attendance.fromJson(doc.data())).toList());
  }

  Future<void> saveAttendance(Attendance record) async {
    await _firestore.collection('attendance').doc(record.id).set(record.toJson());
  }

  Future<void> clearAttendance() async {
    final snapshot = await _firestore.collection('attendance').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteAttendance(String recordId) async {
    await _firestore.collection('attendance').doc(recordId).delete();
  }

}
