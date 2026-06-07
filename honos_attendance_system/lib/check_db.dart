import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final sites = await FirebaseFirestore.instance.collection('sites').get();
  debugPrint('--- SITES ---');
  for (var s in sites.docs) {
    debugPrint('${s.id} : ${s.data()['name']}');
  }
  
  final guards = await FirebaseFirestore.instance.collection('guards').get();
  debugPrint('--- GUARDS ---');
  for (var g in guards.docs) {
    debugPrint('${g.id} : ${g.data()['name']} (SiteID: ${g.data()['siteId']})');
  }
}
