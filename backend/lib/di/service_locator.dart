import 'package:backend/db/database_config.dart';
import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_factory.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/category_service.dart';
import 'package:backend/services/config_service.dart';
import 'package:backend/services/database_health_service.dart';
import 'package:backend/services/encryption_service.dart';
import 'package:backend/services/keyword_service.dart';
import 'package:backend/services/link_manager_service.dart';
import 'package:backend/services/metrics_service.dart';
import 'package:backend/services/status_service.dart';
import 'package:backend/services/view_service.dart';
import 'package:backend/utils/logger.dart';

/// Service locator for dependency injection
class ServiceLocator {
  static final ServiceLocator instance = ServiceLocator._();

  final Map<Type, dynamic> _services = {};
  final Logger _logger = LoggerFactory.getLogger('ServiceLocator');

  ServiceLocator._();

  /// Disposes all registered services
  Future<void> dispose() async {
    _logger.info('Disposing services...');

    // Clean up database connections first
    if (_services.containsKey(DatabaseConnectionPool)) {
      try {
        final pool =
            _services[DatabaseConnectionPool] as DatabaseConnectionPool;
        await pool.shutdown();
        _logger.info('Database connection pool shut down');
      } catch (e, stackTrace) {
        _logger.error(
            'Error shutting down database connection pool', e, stackTrace);
      }
    }

    // Clean up AuthService
    if (_services.containsKey(AuthService)) {
      try {
        await _services[AuthService].dispose();
        _logger.info('AuthService disposed');
      } catch (e, stackTrace) {
        _logger.error('Error disposing AuthService', e, stackTrace);
      }
    }

    // Clean up metrics service
    try {
      MetricsService.instance.dispose();
      _logger.info('MetricsService disposed');
    } catch (e, stackTrace) {
      _logger.error('Error disposing MetricsService', e, stackTrace);
    }

    // Close all loggers
    try {
      LoggerFactory.closeAll();
    } catch (e) {
      // Can't log here as loggers are already closing
      print('Error closing loggers: $e');
    }

    _services.clear();
    _logger.info('All services disposed');
  }

  /// Gets a registered service by type
  T get<T>() {
    if (!_services.containsKey(T)) {
      throw Exception('Service of type $T not registered');
    }
    return _services[T] as T;
  }

  /// Initializes all services
  Future<void> initialize() async {
    _logger.info('Initializing services...');

    try {
      // Initialize config first
      final config = await ConfigService.getInstance();
      register<ConfigService>(config);
      _logger.info('ConfigService initialized');

      // Create database configuration
      final dbConfig = DatabaseConfig.fromEnvironment();
      register<DatabaseConfig>(dbConfig);
      _logger.info('DatabaseConfig registered');

      // Initialize database
      final dbFactory = DatabaseFactory();
      register<DatabaseFactory>(dbFactory);
      _logger.info('DatabaseFactory registered');

      // Create connection pool
      final connectionPool = await dbFactory.createConnectionPool(dbConfig);
      register<DatabaseConnectionPool>(connectionPool);
      _logger.info('Database connection pool initialized');

      // Initialize metrics service
      MetricsService.instance.startPeriodicExport(
        interval: Duration(minutes: 1),
        filePath: '/data/metrics/metrics.json',
      );
      _logger.info('MetricsService initialized');

      // Initialize database health monitoring
      final dbHealth =
          DatabaseHealthService(connectionPool, MetricsService.instance);
      register<DatabaseHealthService>(dbHealth);
      dbHealth.startMonitoring(interval: Duration(minutes: 5));
      _logger.info('DatabaseHealthService initialized');

      // Initialize encryption service
      register<EncryptionService>(EncryptionService());
      _logger.info('EncryptionService initialized');

      // Initialize authentication service
      register<AuthService>(AuthService(
        jwtSecret: config.jwtSecret,
        serviceAccountUsername: config.serviceAccountUsername,
        serviceAccountPassword: config.serviceAccountPassword,
        ldapUrl: config.ldapUrl,
        ldapPort: config.ldapPort,
        baseDN: config.ldapBaseDN,
      ));
      _logger.info('AuthService initialized');

      // Initialize data services
      register<CategoryService>(CategoryService(connectionPool));
      register<KeywordService>(KeywordService(connectionPool));
      register<StatusService>(StatusService(connectionPool));
      register<ViewService>(ViewService(connectionPool));
      register<LinkManagerService>(LinkManagerService(connectionPool));
      _logger.info('Data services initialized');

      _logger.info('All services initialized successfully');
    } catch (e, stackTrace) {
      _logger.critical('Failed to initialize services', e, stackTrace);
      await dispose();
      rethrow;
    }
  }

  /// Registers a service instance
  void register<T>(T service) {
    _services[T] = service;
  }
}

