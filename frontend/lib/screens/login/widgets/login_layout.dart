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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
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
