import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/site.dart';
import '../models/guard.dart';
import '../services/db_service.dart';

// Provides an O(1) lookup map of Sites by Site ID
final siteMapProvider = Provider<Map<String, Site>>((ref) {
  final sitesAsync = ref.watch(sitesStreamProvider);
  final map = <String, Site>{};
  if (sitesAsync.value != null) {
    for (var site in sitesAsync.value!) {
      map[site.id] = site;
    }
  }
  return map;
});

// Provides an O(1) lookup map of Guards by Guard ID
final guardMapProvider = Provider<Map<String, Guard>>((ref) {
  final guardsAsync = ref.watch(guardsStreamProvider);
  final map = <String, Guard>{};
  if (guardsAsync.value != null) {
    for (var guard in guardsAsync.value!) {
      map[guard.id] = guard;
    }
  }
  return map;
});

// Provides the count of pending leaves (calculated once, cached)
final pendingLeavesCountProvider = Provider<int>((ref) {
  final leavesAsync = ref.watch(leavesStreamProvider);
  if (leavesAsync.value == null) return 0;
  return leavesAsync.value!.where((l) => l.status == 'pending').length;
});

// Provides the count of active guards
final activeGuardsCountProvider = Provider<int>((ref) {
  final guardsAsync = ref.watch(guardsStreamProvider);
  if (guardsAsync.value == null) return 0;
  return guardsAsync.value!.where((g) => g.status == 'active').length;
});

// Providers for efficient list of guards per supervisor/site
final guardsForSupervisorProvider = Provider.family<List<Guard>, String>((ref, supervisorId) {
  final guardsAsync = ref.watch(guardsStreamProvider);
  if (guardsAsync.value == null) return [];
  return guardsAsync.value!.where((g) => g.supervisorId == supervisorId).toList();
});

final guardsBySiteProvider = Provider.family<List<Guard>, String>((ref, siteId) {
  final guardsAsync = ref.watch(guardsStreamProvider);
  if (guardsAsync.value == null) return [];
  return guardsAsync.value!.where((g) => g.siteId == siteId).toList();
});

// Provides count of unread notifications for a specific user
final unreadNotificationsCountForUserProvider = Provider.family<int, String>((ref, userId) {
  final notifs = ref.watch(notificationsStreamProvider);
  if (notifs.value == null) return 0;
  return notifs.value!.where((n) {
    if (n.isRead) return false;
    if (n.type == 'edit_request') return false;
    return n.supervisorId == userId || n.guardId == userId;
  }).length;
});
