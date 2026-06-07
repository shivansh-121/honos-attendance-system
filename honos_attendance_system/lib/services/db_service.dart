import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guard.dart';
import '../models/site.dart';
import '../models/attendance.dart';
import '../models/app_user.dart';
import '../models/app_notification.dart';
import '../models/advance.dart';
import '../models/leave.dart';

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

final attendanceForDateProvider = StreamProvider.family<List<Attendance>, String>((ref, date) {
  ref.keepAlive();
  return ref.watch(dbProvider).attendanceStreamForDate(date);
});

/// Scoped to a specific guard only — loaded on guard profile screen
final guardAttendanceProvider = StreamProvider.family<List<Attendance>, String>((ref, guardId) {
  ref.keepAlive();
  return ref.watch(dbProvider).attendanceStreamForGuard(guardId);
});

/// Scoped to a specific site only — loaded on supervisor reports screen
final siteAttendanceStreamProvider = StreamProvider.family<List<Attendance>, String>((ref, siteId) {
  ref.keepAlive();
  return ref.watch(dbProvider).attendanceStreamForSite(siteId);
});

final notificationsStreamProvider = StreamProvider<List<AppNotification>>((ref) {
  ref.keepAlive();
  return ref.watch(dbProvider).notificationsStream();
});

final advancesStreamProvider = StreamProvider<List<Advance>>((ref) {
  ref.keepAlive();
  return ref.watch(dbProvider).advancesStream();
});

final userAdvancesProvider = StreamProvider.family<List<Advance>, String>((ref, userId) {
  ref.keepAlive();
  return ref.watch(dbProvider).advancesStreamForUser(userId);
});

final leavesStreamProvider = StreamProvider<List<Leave>>((ref) {
  ref.keepAlive();
  return ref.watch(dbProvider).leavesStream();
});

class DbService {
  final _firestore = FirebaseFirestore.instance;

  // --- Users ---
  Stream<List<AppUser>> usersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AppUser.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveUser(AppUser user) async {
    await _firestore.collection('users').doc(user.id).set(user.toJson());
  }

  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  Future<void> updateUserField(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
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
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Guard.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveGuard(Guard guard) async {
    await _firestore.collection('guards').doc(guard.id).set(guard.toJson());
  }

  Future<void> deleteGuard(String guardId) async {
    await _firestore.collection('guards').doc(guardId).delete();
  }

  Future<void> updateGuardField(String guardId, Map<String, dynamic> data) async {
    await _firestore.collection('guards').doc(guardId).update(data);
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

  /// Date range query for optimized reports
  Stream<List<Attendance>> attendanceStreamForDateRange(String startDate, String endDate) {
    return _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Attendance.fromJson(doc.data())).toList());
  }

  /// Scoped guard attendance query
  Stream<List<Attendance>> attendanceStreamForGuard(String guardId) {
    return _firestore
        .collection('attendance')
        .where('guardId', isEqualTo: guardId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Attendance.fromJson(doc.data())).toList());
  }

  /// Scoped site attendance query
  Stream<List<Attendance>> attendanceStreamForSite(String siteId) {
    return _firestore
        .collection('attendance')
        .where('siteId', isEqualTo: siteId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Attendance.fromJson(doc.data())).toList());
  }

  Future<void> saveAttendance(Attendance record) async {
    final now = DateTime.now();

    if (record.checkOutTime.isEmpty) {
      // Check-In deduplication logic: only 1 check-in allowed per 8 hours
      final snapshot = await _firestore
          .collection('attendance')
          .where('guardId', isEqualTo: record.guardId)
          .where('date', isEqualTo: record.date)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final existingRecords = snapshot.docs.map((d) => Attendance.fromJson(d.data())).toList();
        existingRecords.sort((a, b) => a.time.compareTo(b.time));
        final earliestRecord = existingRecords.first;

        try {
          final timeParts = earliestRecord.time.split(':');
          final earliestTime = DateTime(
            now.year, now.month, now.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );

          final recordParts = record.time.split(':');
          final recordTime = DateTime(
            now.year, now.month, now.day,
            int.parse(recordParts[0]),
            int.parse(recordParts[1]),
          );

          final diff = recordTime.difference(earliestTime).inMinutes;
          // If within 8 hours (480 mins), silently drop this new check-in
          if (diff >= 0 && diff < 480) {
            return;
          }
        } catch (_) {}
      }
    } else {
      // Check-Out logic: ensure we only overwrite with a LATER time
      final docSnap = await _firestore.collection('attendance').doc(record.id).get();
      if (docSnap.exists) {
        final existing = Attendance.fromJson(docSnap.data()!);
        if (existing.checkOutTime.isNotEmpty && record.checkOutTime.isNotEmpty) {
          try {
            final eParts = existing.checkOutTime.split(':');
            final rParts = record.checkOutTime.split(':');
            var eTime = DateTime(2000, 1, 1, int.parse(eParts[0]), int.parse(eParts[1]));
            var rTime = DateTime(2000, 1, 1, int.parse(rParts[0]), int.parse(rParts[1]));

            final inParts = existing.time.split(':');
            final inTime = DateTime(2000, 1, 1, int.parse(inParts[0]), int.parse(inParts[1]));

            if (eTime.isBefore(inTime)) eTime = eTime.add(const Duration(days: 1));
            if (rTime.isBefore(inTime)) rTime = rTime.add(const Duration(days: 1));

            if (rTime.isBefore(eTime)) {
              // The new check-out time is earlier. User wants the LATEST one only.
              return;
            }
          } catch (_) {}
        }
      }
    }

    final data = record.toJson();
    data['serverCreatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('attendance').doc(record.id).set(data);
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

  Future<void> cleanupOldAttendancePhotos() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore.collection('attendance').get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final markedAtStr = data['markedAt'] as String?;
        if (markedAtStr != null && markedAtStr.isNotEmpty) {
          final markedDate = DateTime.tryParse(markedAtStr);
          if (markedDate != null && now.difference(markedDate).inHours >= 24) {
            final hasPhoto = (data['photoPath'] as String?)?.isNotEmpty ?? false;
            final hasCheckOutPhoto = (data['checkOutPhotoPath'] as String?)?.isNotEmpty ?? false;
            
            if (hasPhoto || hasCheckOutPhoto) {
              await doc.reference.update({
                'photoPath': '',
                'checkOutPhotoPath': ''
              });
            }
          }
        }
      }
    } catch (e) {
      // Silently ignore cleanup errors to not disrupt user experience
    }
  }

  // --- Notifications ---
  Stream<List<AppNotification>> notificationsStream() {
    return _firestore.collection('notifications').orderBy('timestamp', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppNotification.fromJson(doc.data())).toList();
    });
  }

  Future<void> saveNotification(AppNotification notif) async {
    await _firestore.collection('notifications').doc(notif.id).set(notif.toJson());
  }

  Future<void> markNotificationAsRead(String id) async {
    await _firestore.collection('notifications').doc(id).update({'isRead': true});
  }

  Future<void> updateNotificationStatus(String id, String status) async {
    await _firestore.collection('notifications').doc(id).update({'status': status});
  }

  Future<void> deleteNotification(String id) async {
    await _firestore.collection('notifications').doc(id).delete();
  }

  // --- Advances ---
  Stream<List<Advance>> advancesStream() {
    return _firestore.collection('advances').snapshots().map(
          (snap) => snap.docs.map((d) => Advance.fromJson(d.data())).toList(),
        );
  }

  Stream<List<Advance>> advancesStreamForUser(String userId) {
    return _firestore.collection('advances').where('userId', isEqualTo: userId).snapshots().map(
          (snap) => snap.docs.map((d) => Advance.fromJson(d.data())).toList(),
        );
  }

  Future<void> saveAdvance(Advance advance) async {
    await _firestore.collection('advances').doc(advance.id).set(advance.toJson());
  }

  Future<void> deleteAdvance(String id) async {
    await _firestore.collection('advances').doc(id).delete();
  }

  // --- Leaves ---
  Stream<List<Leave>> leavesStream() {
    return _firestore.collection('leaves').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Leave.fromJson(doc.data())).toList();
    });
  }

  Future<void> saveLeave(Leave leave) async {
    await _firestore.collection('leaves').doc(leave.id).set(leave.toJson());
  }

  Future<void> updateLeaveStatus(String leaveId, String status) async {
    await _firestore.collection('leaves').doc(leaveId).update({'status': status});
  }

  Future<void> deleteLeave(String leaveId) async {
    await _firestore.collection('leaves').doc(leaveId).delete();
  }
}
