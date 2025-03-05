import 'dart:io';

import 'package:yaml/yaml.dart';

class ConfigService {
  static ConfigService? _instance;
  late final Map<String, dynamic> _config;

  ConfigService._();

  String get jwtSecret => _config['auth']['jwt_secret'];

  String get ldapBaseDN => _config['ldap']['base_dn'];

  int get ldapPort => _config['ldap']['port'];

  String get ldapUrl => _config['ldap']['url'];
  int get maxAttempts => _config['rate_limit']['max_attempts'];
  String get serviceAccountPassword =>
      _config['auth']['service_account']['password'];
  String get serviceAccountUsername =>
      _config['auth']['service_account']['username'];
  int get windowMinutes => _config['rate_limit']['windows_minutes'];
  Future<void> _initialize() async {
    if (Platform.environment.containsKey('JWT_SECRET')) {
      _config = {
        'auth': {
          'jwt_secret': Platform.environment['JWT_SECRET'],
          'service_account': {
            'username': Platform.environment['SERVICE_ACCOUNT_USERNAME'],
            'password': Platform.environment['SERVICE_ACCOUNT_PASSWORD'],
          },
        },
        'ldap': {
          'url': Platform.environment['LDAP_URL'] ?? 'dc1.ad.unil.ch',
          'port': int.parse(Platform.environment['LDAP_PORT'] ?? '636'),
          'base_dn':
              Platform.environment['LDAP_BASE_DN'] ?? 'DC=ad,DC=unil,DC=ch',
        },
        'rate_limit': {
          'max_attempts':
              int.parse(Platform.environment['RATE_LIMIT_MAX_ATTEMPTS'] ?? '5'),
          'windows_minutes': int.parse(
              Platform.environment['RATE_LIMIT_WINDOW_MINUTES'] ?? '5'),
        },
      };

      return;
    }

    try {
      final file = File('${Directory.current.path}/config.yaml');
      if (!await file.exists()) {
        throw Exception(
            'Configuration file not found. Please create the config.yaml file based on the config.yaml.example file.');
      }

      final yamlString = await file.readAsString();
      final yamlConfig = loadYaml(yamlString);
      _config = Map<String, dynamic>.from(yamlConfig);
    } catch (e) {
      throw Exception('Failed to load configuration: $e');
    }

    _validateConfig();
  }

  void _validateConfig() {
    if (!_config.containsKey('auth') ||
        !_config['auth'].containsKey('service_account') ||
        !_config['auth'].containsKey('jwt_secret') ||
        !_config['auth']['service_account'].containsKey('username') ||
        !_config['auth']['service_account'].containsKey('password')) {
      throw Exception('Invalid configuration: Missing required auth settings');
    }
  }

  static Future<ConfigService> getInstance() async {
    if (_instance == null) {
      _instance = ConfigService._();
      await _instance!._initialize();
    }
    return _instance!;
  }
}
