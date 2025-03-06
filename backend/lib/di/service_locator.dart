import 'package:backend/db/database.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/category_service.dart';
import 'package:backend/services/config_service.dart';
import 'package:backend/services/encryption_service.dart';

class ServiceLocator {
  static final ServiceLocator instance = ServiceLocator._();

  final Map<Type, dynamic> _services = {};

  ServiceLocator._();

  Future<void> dispose() async {
    // Clean up resources
    if (_services.containsKey(AppDatabase)) {
      await _services[AppDatabase].dispose();
    }

    if (_services.containsKey(AuthService)) {
      await _services[AuthService].dispose();
    }

    _services.clear();
  }

  T get<T>() {
    if (!_services.containsKey(T)) {
      throw Exception('Service of type $T not registered');
    }
    return _services[T] as T;
  }

  Future<void> initialize() async {
    // Initialize config first
    final config = await ConfigService.getInstance();
    register<ConfigService>(config);

    // Initialize database
    final db = AppDatabase(enableLogging: true);
    db.init();
    register<AppDatabase>(db);

    // Initialize services
    register<EncryptionService>(EncryptionService());

    register<AuthService>(AuthService(
      jwtSecret: config.jwtSecret,
      serviceAccountUsername: config.serviceAccountUsername,
      serviceAccountPassword: config.serviceAccountPassword,
      ldapUrl: config.ldapUrl,
      ldapPort: config.ldapPort,
      baseDN: config.ldapBaseDN,
    ));

    register<CategoryService>(CategoryService(db));
  }

  void register<T>(T service) {
    _services[T] = service;
  }
}
