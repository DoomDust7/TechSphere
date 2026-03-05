import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:techsphere/firebase_options.dart';
import 'package:techsphere/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TechSphereApp());
}

class TechSphereApp extends StatelessWidget {
  const TechSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TechSphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.lightBlueAccent,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
