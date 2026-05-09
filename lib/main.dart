import 'package:bhc_erp/Student/screens/main_page.dart';
import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/core/auth/user_type.dart';
import 'package:bhc_erp/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'login/screens/unified_login_screen.dart';
import 'Staff/screens/staff_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final authProvider = AuthProvider();
  await authProvider.init();
  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => StaffThemeProvider()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final auth  = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'BHC ERP',
      debugShowCheckedModeBanner: false,
      theme: theme.themeData,
      builder: (context, child) => child!,
      // Splash is always the entry — it decides where to go
      home: SplashScreen(nextScreen: _resolveHome(auth)),
      routes: {
        '/login':           (_) => const UnifiedLoginScreen(),
        '/staff-dashboard': (_) => const StaffDashboard(),
      },
      // Smooth default page transition for named routes
      onGenerateRoute: (settings) {
        Widget? page;
        if (settings.name == '/login') page = const UnifiedLoginScreen();
        if (settings.name == '/staff-dashboard') page = const StaffDashboard();
        if (page == null) return null;
        return _fadeSlideRoute(page);
      },
    );
  }

  Widget _resolveHome(AuthProvider auth) {
    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF05060F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7B8CFF))),
      );
    }
    if (!auth.isAuthenticated) return const UnifiedLoginScreen();
    if (auth.userType == UserType.student) {
      return MainPage(
        rollNo: auth.studentRollNo ?? '',
        studentName: auth.studentName ?? 'Student',
      );
    }
    return const StaffDashboard();
  }
}

/// Reusable smooth fade+slide page route
PageRouteBuilder _fadeSlideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.03), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}
