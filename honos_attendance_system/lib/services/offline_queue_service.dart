import 'package:hive_flutter/hive_flutter.dart';
import '../models/attendance.dart';

class OfflineQueueService {
  static const String boxName = 'offline_attendance';

  static Future<void> init() async {
    await Hive.openBox<Map>(boxName);
  }

  static Box<Map> get _box => Hive.box<Map>(boxName);

  static Future<void> addRecord(Attendance record) async {
    await _box.put(record.id, record.toJson());
  }

  static List<Attendance> getPendingRecords() {
    final List<Attendance> records = [];
    for (var value in _box.values) {
      final map = Map<String, dynamic>.from(value);
      records.add(Attendance.fromJson(map));
    }
    return records;
  }

  static Future<void> removeRecord(String id) async {
    await _box.delete(id);
  }

  static bool get hasPending => _box.isNotEmpty;
}
