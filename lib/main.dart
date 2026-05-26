import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/map_screen.dart';
import '../controllers/truck_controller.dart';
import '../services/preferences_service.dart';
import '../services/truck_profile_service.dart';
import '../models/truck_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.instance.init();
  
  final defaultProfileId = PreferencesService.instance.defaultProfileId;
  final profile = TruckProfilePresets.all.firstWhere(
    (p) => p.type.name == defaultProfileId,
    orElse: () => TruckProfilePresets.truck,
  );
  TruckProfileService.instance.selectProfile(profile);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TruckController()),
        ChangeNotifierProvider(create: (_) => PreferencesService.instance),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrallZero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
      ),
      home: const MapScreen(),
    );
  }
}
