import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/routes.dart';
import 'package:test/screens/shared/widgets/footer.dart';
import 'package:test/screens/shared/widgets/header.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/asymmetric/api.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _Login();
}

class _Login extends State<Login> {
  late final Encrypter _encrypter;
  bool _isEncrypterReady = false;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeEncrypter();
  }

  Future<void> _initializeEncrypter() async {
    try {
      final response = await http.get(Uri.parse('/api/public-key'));

      if (response.statusCode == 200) {
        final publicKeyPem = json.decode(response.body)['publicKey'];
        final parser = RSAKeyParser();
        final publicKey = parser.parse(publicKeyPem) as RSAPublicKey;

        setState(() {
          _encrypter = Encrypter(RSA(publicKey: publicKey));
          _isEncrypterReady = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize encryption';
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || !_isEncrypterReady) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final encryptedUsername = _encrypter.encrypt(_usernameController.text);
    final encryptedPassword = _encrypter.encrypt(_passwordController.text);

    try {
      final response = await http.post(
        Uri.parse('/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': encryptedUsername.base64,
          'password': encryptedPassword.base64,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);

        if (!mounted) return;
        _navigateToHome();
      } else {
        setState(() {
          _errorMessage = 'Nom d\'utilisateur ou mot de passe invalide';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connection error';
      });
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !_isEncrypterReady
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const Header(),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    border: OutlineInputBorder(),
                                  ),
                                  obscureText: true,
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                if (_errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Login'),
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                    const Column(
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
