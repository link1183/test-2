import 'package:flutter/material.dart';
import 'package:test/screens/shared/widgets/footer.dart';
import 'package:test/screens/shared/widgets/header.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                children: [
                  Header(),
                  SizedBox(height: 16),
                  Text('test'),
                ],
              ),
              Column(
                children: [
                  SizedBox(height: 16),
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
