import '../models/app_user.dart';
import '../models/guard.dart';

class IdGenerator {
  static String generateRecycledEmpId(String rolePrefix, List<String> existingIds) {
    final usedNumbers = <int>{};
    for (final id in existingIds) {
      if (id.startsWith(rolePrefix)) {
        final numStr = id.substring(rolePrefix.length);
        final number = int.tryParse(numStr);
        if (number != null) {
          usedNumbers.add(number);
        }
      }
    }
    
    int nextId = 1;
    while (usedNumbers.contains(nextId)) {
      nextId++;
    }
    
    final numStr = nextId < 1000 ? nextId.toString().padLeft(3, '0') : nextId.toString();
    return '$rolePrefix$numStr';
  }

  static String generateGuardId(List<Guard> guards) {
    final ids = guards.map((g) => g.empId).toList();
    return generateRecycledEmpId('HS-G-', ids);
  }

  static String generateSupervisorId(List<AppUser> users) {
    final ids = users.where((u) => u.role == 'supervisor').map((u) => u.empId).toList();
    return generateRecycledEmpId('HS-S-', ids);
  }

  static String generateExecutiveId(List<AppUser> users) {
    final ids = users.where((u) => u.role == 'executive').map((u) => u.empId).toList();
    return generateRecycledEmpId('HS-E-', ids);
  }
}
