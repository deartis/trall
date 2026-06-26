import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'features/home/screens/home_screen.dart';
import 'features/route/screens/route_manager_screen.dart';
import 'controllers/truck_controller.dart';
import 'services/preferences_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/truck_profile_service.dart';
import 'models/truck_profile.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.instance.init();
  await ApiService.instance.init();
  await AuthService.instance.tryRestoreSession();
  
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
        ChangeNotifierProvider(create: (_) => AuthService.instance),
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
      title: 'Trall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/route_manager': (context) => const RouteManagerScreen(),
      },
    );
  }
}

