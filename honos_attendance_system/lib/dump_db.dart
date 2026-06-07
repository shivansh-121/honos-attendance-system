import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final db = FirebaseFirestore.instance;
  
  debugPrint('SUPERVISORS:');
  final users = await db.collection('users').where('role', isEqualTo: 'supervisor').get();
  for (var d in users.docs) {
    debugPrint('${d.id}: ${d.data()['username']} - siteId: ${d.data()['siteId']}');
  }

  debugPrint('\nGUARDS:');
  final guards = await db.collection('guards').get();
  for (var d in guards.docs) {
    debugPrint('${d.id}: ${d.data()['name']} - siteId: ${d.data()['siteId']} - supervisorId: ${d.data()['supervisorId']}');
  }

  debugPrint('\nSITES:');
  final sites = await db.collection('sites').get();
  for (var d in sites.docs) {
    debugPrint('${d.id}: ${d.data()['name']}');
  }
}
