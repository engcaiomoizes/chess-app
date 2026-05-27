import 'package:chess_app/app_controller.dart';
import 'home_page.dart';
import 'chess_game_page.dart';
import 'package:flutter/material.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppController.instance,
      builder: (context, child) {
        return MaterialApp(
          theme: ThemeData(
            primarySwatch: Colors.red,
            brightness: AppController.instance.isDarkTheme ? Brightness.dark : Brightness.dark,
          ),
          initialRoute: "/",
          routes: {
            "/": (context) => HomePage(),
            "/game": (context) => ChessGamePage(),
          },
        );
      },
    );
  }
}