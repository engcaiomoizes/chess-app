import 'package:flutter/material.dart';
import "home_page.dart";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String email = "";
  String password = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    email = value;
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Email"
                  ),
                ),
                Container(height: 10),
                TextField(
                  obscureText: true,
                  onChanged: (value) {
                    password = value;
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Password"
                  ),
                ),
                Container(height: 15),
                ElevatedButton(
                  onPressed: () {
                    if (email == "engcaiomoizes@gmail.com" && password == "caio2000") {
                      Navigator.of(context).pushReplacementNamed("/home");
                    } else {
                      print("Login inválido.");
                    }
                  },
                  child: Text("Entrar"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}