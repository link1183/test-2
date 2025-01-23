import 'package:flutter/material.dart';
import 'package:test/widgets/footer.dart';
import 'package:test/widgets/header.dart';

void main() async {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portail IT BCUL',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Header(),

          // Main content
          const Expanded(
            child: SizedBox(),
          ),

          Footer(),
        ],
      ),
    );
  }
}
