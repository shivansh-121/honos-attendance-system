import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final sites = await FirebaseFirestore.instance.collection('sites').get();
  print('--- SITES ---');
  for (var s in sites.docs) {
    print('${s.id} : ${s.data()['name']}');
  }
  
  final guards = await FirebaseFirestore.instance.collection('guards').get();
  print('--- GUARDS ---');
  for (var g in guards.docs) {
    print('${g.id} : ${g.data()['name']} (SiteID: ${g.data()['siteId']})');
  }
}
