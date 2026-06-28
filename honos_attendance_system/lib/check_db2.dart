import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final snap = await FirebaseFirestore.instance.collection('advances').get();
  debugPrint('--- ADVANCES DUMP ---');
  for (var d in snap.docs) {
    debugPrint(d.data().toString());
  }
  debugPrint('--- END ---');

}
