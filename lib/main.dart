import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/watch_screen.dart';

void main() {
  runApp(const ECGMonitorApp());
}

/// Main app widget for ECG Arrhythmia Classification with Real-Time Monitoring
class ECGMonitorApp extends StatelessWidget {
  const ECGMonitorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG Monitor - Mamba AI',
      theme: ThemeData(
        /// Primary color scheme
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        
        /// App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        
        /// Button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            backgroundColor: const Color(0xFF1E88E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        /// Card theme
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/watch': (context) => const WatchScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
