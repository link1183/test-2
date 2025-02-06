import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:portail_it/middlewares/auth_provider.dart';
import 'package:portail_it/middlewares/auth_middleware.dart';
import 'package:portail_it/screens/home/home.dart';
import 'package:portail_it/screens/login/login.dart';
import 'package:portail_it/theme/theme.dart';
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
      home: AuthMiddleware(
        loginScreen: const Login(),
        child: const Home(),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}
