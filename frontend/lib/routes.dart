import 'package:flutter/material.dart';
import 'package:portail_it/middlewares/auth_middleware.dart';
import 'package:portail_it/screens/home/home.dart';
import 'package:portail_it/screens/login/login.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => AuthMiddleware(
            loginScreen: const Login(),
            child: const Home(),
          ),
        );
      case login:
        return MaterialPageRoute(builder: (_) => const Login());
      default:
        return MaterialPageRoute(
          builder: (_) => AuthMiddleware(
            loginScreen: const Login(),
            child: const Home(),
          ),
        );
    }
  }
}
