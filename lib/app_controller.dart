import 'package:flutter/material.dart';

class AppController extends ChangeNotifier {
  static final AppController instance = AppController._();

  AppController._();

  bool isDarkTheme = false;

  void changeTheme() {
    isDarkTheme = !isDarkTheme;
    notifyListeners();
  }
}