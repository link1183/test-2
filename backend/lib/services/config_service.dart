import 'dart:io';

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
      _validateJwtSecret(Platform.environment['JWT_SECRET']!);

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
  }

  void _validateJwtSecret(String secret) {
    if (secret.length < 32) {
      throw Exception("JWT secret must be at least 32 characters long");
    }

    bool hasLowercase = secret.contains(RegExp(r'[a-z]'));
    bool hasUppercase = secret.contains(RegExp(r'[A-Z]'));
    bool hasDigits = secret.contains(RegExp(r'[0-9]'));
    bool hasSpecial = secret.contains(RegExp(r'[^a-zA-Z0-9]'));

    int complexityScore = 0;
    if (hasLowercase) complexityScore++;
    if (hasUppercase) complexityScore++;
    if (hasDigits) complexityScore++;
    if (hasSpecial) complexityScore++;

    if (complexityScore < 3) {
      throw Exception(
          'JWT secret must contain at least 3 of the following: lowercase letters, uppercase letters, numbers, special characters');
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
