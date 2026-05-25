import 'dart:convert';
import 'package:crypto/crypto.dart';
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
    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8), onTimeout: () {
            throw Exception("Network timeout. Please check your internet connection and try again.");
          });

      if (snapshot.docs.isNotEmpty) {
        final userData = snapshot.docs.first.data();
        final dbPassword = userData['password'] as String? ?? '';
        final hashedInput = sha256.convert(utf8.encode(password)).toString();

        if (dbPassword == hashedInput || dbPassword == password) {
          var user = AppUser.fromJson(userData);
          
          // Seamless migration: If plaintext matches, upgrade DB to hash
          if (dbPassword == password) {
             await db.collection('users').doc(user.id).update({'password': hashedInput});
             user = AppUser(
              id: user.id,
              name: user.name,
              username: user.username,
              role: user.role,
              siteId: user.siteId,
              password: hashedInput,
            );
          }
          
          await _saveSession(user);
          return null; // Success
        } else {
          return 'Invalid username or password.';
        }
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

  Future<void> updateUser(AppUser user) async {
    await _saveSession(user);
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
