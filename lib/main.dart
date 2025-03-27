import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:travver/constants/app_theme.dart';
import 'package:travver/screens/splash_screen.dart';

void main() {
  runApp(const TravverApp());
}

class TravverApp extends StatelessWidget {
  const TravverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
