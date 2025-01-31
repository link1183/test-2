import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/middlewares/auth_provider.dart';
import 'package:test/middlewares/auth_middleware.dart';
import 'package:test/routes.dart';
import 'package:test/screens/home/home.dart';
import 'package:test/screens/login/login.dart';
import 'package:test/theme/theme.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void main() async {
  setUrlStrategy(PathUrlStrategy());

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkAuth(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portail IT BCUL',
      theme: AppTheme.theme,
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (context) => AuthMiddleware(
              loginScreen: const Login(),
              child: const Home(),
            ),
        AppRoutes.login: (context) => const Login(),
      },
    );
  }
}
