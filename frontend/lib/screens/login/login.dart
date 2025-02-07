import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:portail_it/services/api_client.dart';
import 'package:provider/provider.dart';
import 'package:portail_it/middlewares/auth_provider.dart';
import 'package:portail_it/routes.dart';
import 'package:portail_it/screens/shared/widgets/loading_screen.dart';
import 'package:portail_it/screens/login/widgets/login_form.dart';
import 'package:portail_it/screens/login/widgets/login_layout.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:encrypt/encrypt.dart';

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
  final _passwordFocusNode = FocusNode();
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
      setState(() => _errorMessage = 'Failed to initialize encryption');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || !_isEncrypterReady) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.login(
        _usernameController.text,
        _passwordController.text,
        _encrypter,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];

        if (mounted) {
          await Provider.of<AuthProvider>(context, listen: false)
              .setAuthenticated(true, token: token);

          await Future.delayed(const Duration(milliseconds: 100));

          if (mounted) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          }
        }
      } else {
        if (mounted) {
          _passwordController.clear();
          _passwordFocusNode.requestFocus();
          setState(() => _errorMessage = 'Invalid credentials');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Connection error');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !_isEncrypterReady
          ? const LoadingScreen()
          : LoginLayout(
              loginForm: LoginForm(
                formKey: _formKey,
                usernameController: _usernameController,
                passwordController: _passwordController,
                passwordFocusNode: _passwordFocusNode,
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                onLogin: _login,
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
