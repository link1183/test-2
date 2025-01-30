import 'package:flutter/material.dart';
import 'package:test/routes.dart';
import 'package:test/screens/home/home.dart';
import 'package:test/screens/login/login.dart';
import 'package:test/theme/theme.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void main() async {
  setUrlStrategy(PathUrlStrategy());
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portail IT BCUL',
      theme: AppTheme.theme,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.home: (context) => const Home(),
        AppRoutes.login: (context) => const Login(),
      },
    );
  }
}
