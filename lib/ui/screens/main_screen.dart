import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'home_screen.dart';
import 'video_form_checker_screen.dart';

class MainScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MainScreen({super.key, required this.cameras});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Kita buat daftar _pages di dalam build agar VideoFormCheckerScreen 
    // selalu mendapatkan status isActive terbaru (berguna untuk pause video saat pindah tab)
    final pages = [
      HomeScreen(cameras: widget.cameras),
      VideoFormCheckerScreen(isActive: _currentIndex == 1),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Logbook Latihan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_file),
            label: 'Cek Video Form',
          ),
        ],
      ),
    );
  }
}
