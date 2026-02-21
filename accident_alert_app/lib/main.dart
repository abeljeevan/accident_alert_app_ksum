import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accident Alert App',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode
          ? ThemeData.dark().copyWith(
              primaryColor: const Color(0xFFE63946),
              scaffoldBackgroundColor: const Color.fromARGB(255, 18, 18, 18),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 30, 30, 30),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              cardTheme: const CardThemeData(
                color: Color.fromARGB(255, 30, 30, 30),
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white70),
                titleMedium:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: Colors.white),
                hintStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color.fromARGB(255, 40, 40, 40),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFFE63946),
                foregroundColor: Colors.white,
              ),
            )
          : ThemeData(
              scaffoldBackgroundColor:
                  const Color.fromARGB(255, 249, 249, 249),
              primaryColor: const Color(0xFFE63946),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 228, 231, 235),
                titleTextStyle: TextStyle(
                  color: Color(0xFFE63946),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                iconTheme: IconThemeData(color: Colors.red),
              ),
              cardTheme: const CardThemeData(
                color: Color.fromARGB(255, 25, 66, 118),
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.black),
                bodyMedium: TextStyle(color: Colors.black54),
                titleMedium:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: Colors.black),
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color.fromARGB(255, 240, 240, 240),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black26),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFFE63946),
                foregroundColor: Colors.white,
              ),
            ),
      home: HomePage(
        isDarkMode: _isDarkMode,
        onToggleTheme: () {
          setState(() {
            _isDarkMode = !_isDarkMode;
          });
        },
      ),
    );
  }
}
