import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/local/hive_service.dart';
import 'providers/squat_provider.dart';
import 'providers/situp_provider.dart';
import 'providers/pushup_provider.dart';
import 'providers/shouldertap_provider.dart';
import 'providers/lunges_provider.dart';
import 'providers/burpees_provider.dart';
import 'providers/jumpingjack_provider.dart';
import 'providers/benchdips_provider.dart';
import 'providers/plank_provider.dart';
import 'providers/legraise_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  await HiveService.init();
  
  final cameras = await availableCameras();
  
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SquatProvider()),
        ChangeNotifierProvider(create: (_) => SitUpProvider()),
        ChangeNotifierProvider(create: (_) => PushUpProvider()),
        ChangeNotifierProvider(create: (_) => ShoulderTapProvider()),
        ChangeNotifierProvider(create: (_) => LungesProvider()),
        ChangeNotifierProvider(create: (_) => BurpeesProvider()),
        ChangeNotifierProvider(create: (_) => JumpingJackProvider()),
        ChangeNotifierProvider(create: (_) => BenchDipsProvider()),
        ChangeNotifierProvider(create: (_) => PlankProvider()),
        ChangeNotifierProvider(create: (_) => LegRaiseProvider()),
      ],
      child: MaterialApp(
        title: 'Workout Counter AI',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1B1B1B),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD95C27), // Burnt orange
            secondary: Color(0xFFD95C27),
            surface: Color(0xFF2C2C2C),
            background: Color(0xFF1B1B1B),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1B1B1B),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'BebasNeue',
              letterSpacing: 1.5,
            ),
          ),
          textTheme: TextTheme(
            displayLarge: GoogleFonts.bebasNeue(
              color: Colors.white,
              fontSize: 56,
              height: 1.0,
            ),
            displayMedium: GoogleFonts.bebasNeue(
              color: Colors.white,
              fontSize: 48,
              height: 1.0,
            ),
            displaySmall: GoogleFonts.bebasNeue(
              color: Colors.white,
              fontSize: 36,
              height: 1.1,
            ),
            headlineLarge: GoogleFonts.bebasNeue(
              color: Colors.white,
              fontSize: 32,
            ),
            headlineMedium: GoogleFonts.bebasNeue(
              color: Colors.white,
              fontSize: 28,
            ),
            titleLarge: GoogleFonts.bebasNeue(
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 1.2,
            ),
            bodyLarge: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 16,
            ),
            bodyMedium: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
            ),
            bodySmall: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFD95C27),
            foregroundColor: Colors.white,
          ),
        ),
        home: MainScreen(cameras: cameras),
      ),
    );
  }
}
