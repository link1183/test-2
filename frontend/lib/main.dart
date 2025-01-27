import 'package:flutter/material.dart';
import 'package:test/widgets/footer.dart';
import 'package:test/widgets/header.dart';
import 'package:test/widgets/main.dart';
import 'package:http/http.dart' as http;

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
      home: const Home(),
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  Future<void> _insertMockData() async {
    try {
      final response = await http.get(Uri.parse('/api/mock_insert'));
      if (response.statusCode == 200) {
        print('Mock data received: ${response.body}');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> _getMockData() async {
    try {
      final response = await http.get(Uri.parse('/api/mock'));
      if (response.statusCode == 200) {
        print('Mock data received: ${response.body}');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Header(),
            const Main(),
            ElevatedButton.icon(
                onPressed: _insertMockData,
                label: const Text('Insert Mock data')),
            SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: _getMockData, label: const Text('Get mock data')),
            const Footer(),
          ],
        ),
      ),
    );
  }
}
