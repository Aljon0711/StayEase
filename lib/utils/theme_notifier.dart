import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeNotifier with ChangeNotifier {
  ThemeMode _themeMode;
  String? _userEmail;

  ThemeNotifier(this._themeMode);

  ThemeMode get themeMode => _themeMode;

  void setUserEmail(String? email) {
    _userEmail = email;
    // When user email is set, load their preference
    if (_userEmail != null) {
      _loadThemePreference();
    }
  }

  Future<void> _loadThemePreference() async {
    if (_userEmail == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_userEmail).get();
      if (doc.exists) {
        final userData = doc.data();
          final bool? isDarkMode = userData?['isDarkMode'];
          if (isDarkMode != null) {
            _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
            notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    if (_userEmail != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(_userEmail).set(
          {'isDarkMode': isDarkMode},
          SetOptions(merge: true),
        );
      } catch (e) {
        print('Error saving theme preference: $e');
      }
    }
  }
}

