import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AppUser?> {
  final Ref ref;

  AuthNotifier(this.ref) : super(null) {
    _loadSession();
  }

  void _loadSession() {
    final box = Hive.box('session');
    final userJson = box.get('user');
    if (userJson != null) {
      state = AppUser.fromJson(jsonDecode(userJson));
    }
  }

  Future<String?> login(String username, String password) async {
    final db = FirebaseFirestore.instance;

    try {
      final snapshot = await db
          .collection('users')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final user = AppUser.fromJson(snapshot.docs.first.data());
        await _saveSession(user);
        return null; // Success
      } else {
        return 'Invalid username or password.';
      }
    } catch (e) {
      return 'Login error: ${e.toString()}';
    }
  }

  Future<void> _saveSession(AppUser user) async {
    final box = Hive.box('session');
    await box.put('user', jsonEncode(user.toJson()));
    state = user;
  }

  Future<void> updateSite(String newSiteId) async {
    if (state == null) return;
    
    final updatedUser = AppUser(
      id: state!.id,
      name: state!.name,
      username: state!.username,
      role: state!.role,
      siteId: newSiteId,
      password: state!.password,
    );

    // 1. Update Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(updatedUser.id)
        .update({'siteId': newSiteId});

    // 2. Update Local Session & State
    await _saveSession(updatedUser);
  }

  Future<void> logout() async {
    final box = Hive.box('session');
    await box.delete('user');
    state = null;
  }
}
