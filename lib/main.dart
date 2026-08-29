import 'package:flutter/material.dart';

import 'src/app_constants.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppText.displayName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.cyan,
          brightness: Brightness.dark,
          surface: AppPalette.surface,
          error: AppPalette.error,
        ),
        scaffoldBackgroundColor: AppPalette.background,
        useMaterial3: true,
      ),
      home: const Scaffold(
        backgroundColor: AppPalette.background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppText.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.cyan,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  AppText.slogan,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.violet,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
