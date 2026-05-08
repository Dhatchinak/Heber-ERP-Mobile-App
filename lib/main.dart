import 'package:bhc_erp/Student/screens/main_page.dart';
import 'package:bhc_erp/Student/theme_provider.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:bhc_erp/core/auth/user_type.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'login/screens/unified_login_screen.dart';
import 'Staff/screens/staff_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider.init();
  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    // MultiProvider is the ROOT — above MaterialApp.
    // This means ALL routes pushed by the navigator inherit these providers.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),      // Student screens
        ChangeNotifierProvider(create: (_) => StaffThemeProvider()), // Staff screens
      ],
      child: _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'BHC Unified ERP',
      debugShowCheckedModeBanner: false,
      theme: theme.themeData,
      // builder wraps every route in the navigator with the providers above,
      // ensuring pushed routes also see ThemeProvider.
      builder: (context, child) => child!,
      home: _resolveHome(auth),
      routes: {
        '/login': (_) => const UnifiedLoginScreen(),
        '/staff-dashboard': (_) => const StaffDashboard(),
      },
    );
  }

  Widget _resolveHome(AuthProvider auth) {
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isAuthenticated) {
      return const UnifiedLoginScreen();
    }
    if (auth.userType == UserType.student) {
      return MainPage(
        rollNo: auth.studentRollNo ?? '',
        studentName: auth.studentName ?? 'Student',
      );
    }
    return const StaffDashboard();
  }
}
