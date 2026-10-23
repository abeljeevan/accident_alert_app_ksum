import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    const navy = Color(0xFF10264D);
    const red = Color(0xFFFF3347);
    const muted = Color(0xFF63718A);
    return MaterialApp(
      title: 'Accident Alert App',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.light).copyWith(primary: red, secondary: const Color(0xFF2588F5), surface: Colors.white),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF4F7FB), foregroundColor: navy, elevation: 0, centerTitle: false, titleTextStyle: TextStyle(color: navy, fontSize: 19, fontWeight: FontWeight.w800), systemOverlayStyle: SystemUiOverlayStyle.dark),
        cardTheme: CardThemeData(color: Colors.white, elevation: 1.5, shadowColor: const Color(0xFF263957).withValues(alpha: 0.08), margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        textTheme: const TextTheme(bodyLarge: TextStyle(color: navy), bodyMedium: TextStyle(color: muted), titleMedium: TextStyle(color: navy, fontWeight: FontWeight.bold)),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFFF0F3F8), hintStyle: const TextStyle(color: muted), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: red))),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, elevation: 2, shadowColor: red.withValues(alpha: .3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20), textStyle: const TextStyle(fontWeight: FontWeight.w700))),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: navy, side: const BorderSide(color: Color(0xFFDCE3ED)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18))),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: red, foregroundColor: Colors.white),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF061321),
        colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.dark).copyWith(primary: red, secondary: const Color(0xFF2588F5), surface: const Color(0xFF10243A)),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF061321), foregroundColor: Colors.white, elevation: 0, centerTitle: false, titleTextStyle: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800), systemOverlayStyle: SystemUiOverlayStyle.light),
        cardTheme: CardThemeData(color: const Color(0xFF10243A), elevation: 1.5, shadowColor: Colors.black.withValues(alpha: .2), margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.white), bodyMedium: TextStyle(color: Color(0xFF9EB0C9)), titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF10243A), hintStyle: const TextStyle(color: Color(0xFF9EB0C9)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: red))),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, elevation: 2, shadowColor: red.withValues(alpha: .25), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20), textStyle: const TextStyle(fontWeight: FontWeight.w700))),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF29425C)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18))),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: red, foregroundColor: Colors.white),
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
