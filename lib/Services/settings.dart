import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings with ChangeNotifier {
  // Singleton pattern for Settings
  static final Settings _instance = Settings._internal();

  factory Settings() {
    return _instance;
  }

  Settings._internal();

  // Current theme: true for black, false for white
  bool _isBlackTheme = true;
  String? _profileImagePath;

  bool get isBlackTheme => _isBlackTheme;
  String? get profileImagePath => _profileImagePath;

  // Getter and Setter for isBlackTheme
  set isBlackTheme(bool value) {
    if (_isBlackTheme != value) {
      _isBlackTheme = value;
      _saveThemePreference(value); // Save the theme to SharedPreferences
      notifyListeners(); // Notify listeners when the theme changes
    }
  }

  set profileImagePath(String? path) {
    if (_profileImagePath != path) {
      _profileImagePath = path;
      _saveProfileImage(
          path); // Save the profile image path to SharedPreferences
      notifyListeners();
    }
  }

  // Method to load the theme preference from SharedPreferences
  Future<void> loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isBlackTheme =
        prefs.getBool('isBlackTheme') ?? true; // Default to black theme
    //pfp image setter and getter
    _profileImagePath = prefs.getString('profileImagePath');
    notifyListeners(); // Notify listeners when the theme is loaded
  }

  // Method to save the theme preference to SharedPreferences
  Future<void> _saveThemePreference(bool isBlack) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isBlackTheme', isBlack); // Save the theme preference
  }

  Future<void> _saveProfileImage(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
        'profileImagePath', path ?? ''); // Store path or empty string if null
  }
}
