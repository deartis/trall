import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'features/home/screens/home_screen.dart';
import 'features/route/screens/route_manager_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
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
      onGenerateRoute: (settings) {
        WidgetBuilder builder;
        switch (settings.name) {
          case '/':
            builder = (context) => const HomeScreen();
            break;
          case '/route_manager':
            builder = (context) => const RouteManagerScreen();
            break;
          case '/profile':
            builder = (context) => const ProfileScreen();
            break;
          case '/settings':
            builder = (context) => const SettingsScreen();
            break;
          case '/login':
            builder = (context) => const LoginScreen();
            break;
          default:
            return null;
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Transição premium de deslize sutil da direita + fade
            const begin = Offset(0.08, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            final slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 220),
        );
      },
    );
  }
}

