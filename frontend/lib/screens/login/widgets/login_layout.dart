import 'package:flutter/material.dart';
import 'package:portail_it/screens/login/widgets/login_header.dart';
import 'package:portail_it/screens/shared/widgets/footer.dart';
import 'package:portail_it/screens/shared/widgets/header.dart';

class LoginLayout extends StatelessWidget {
  final Widget loginForm;

  const LoginLayout({
    super.key,
    required this.loginForm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Header(),
                  const LoginHeader(),
                  loginForm,
                ],
              ),
              Column(
                children: [
                  const SizedBox(height: 16),
                  Footer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
