import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';

/// Base class for database seeders
abstract class DatabaseSeeder {
  final Logger _logger = LoggerFactory.getLogger('DatabaseSeeder');

  /// Logs seeding information
  void log(String message) {
    _logger.info(message);
  }

  /// Logs seeding error
  void logError(String message, Object error, [StackTrace? stackTrace]) {
    _logger.error(message, error, stackTrace);
  }

  /// Seeds the database with initial data
  Future<void> seed(DatabaseConnectionPool connectionPool);
}

/// Development environment database seeder
class DevelopmentSeeder extends DatabaseSeeder {
  @override
  Future<void> seed(DatabaseConnectionPool connectionPool) async {
    log('Seeding development database...');

    final connection = await connectionPool.getConnection();

    try {
      await connection.database.beginTransaction();

      try {
        // Check if we need to seed (only seed if tables are empty)
        final statusCount = await connection.database.query(
          'SELECT COUNT(*) as count FROM status',
        );

        if ((statusCount.first['count'] as int) > 0) {
          log('Database already has data, skipping seeding');
          await connection.database.rollbackTransaction();
          return;
        }

        // Insert statuses
        log('Seeding statuses...');
        await connection.database.execute('''
          INSERT INTO status (name) VALUES 
            ('Active'),
            ('Inactive'),
            ('Deprecated'),
            ('In Development')
        ''');

        // Insert views (user groups)
        log('Seeding views...');
        await connection.database.execute('''
          INSERT INTO view (name) VALUES 
            ('si-bcu-g'),
            ('User'),
            ('Guest'),
            ('Administrator')
        ''');

        // Insert categories
        log('Seeding categories...');
        await connection.database.execute('''
          INSERT INTO categories (name) VALUES 
            ('Applications métiers'),
            ('Monitoring'),
            ('Serveurs Web'),
            ('Virtualisation - BCUL'),
            ('Formulaires BCUL'),
            ('Formulaires UNIL'),
            ('Administration'),
            ('Lorawan'),
            ('Virtualisation - UNIL'),
            ('Mail'),
            ('Réseau'),
            ('Téléphonie'),
            ('Formations'),
            ('Utilitaires')
        ''');

        // Insert managers
        log('Seeding link managers...');
        await connection.database.execute('''
          INSERT INTO link_manager (name, surname, link) VALUES 
            ('Bob', 'Brown', ''),
            ('John', 'Doe', ''),
            ('Jane', 'Smith', ''),
            ('Alice', 'Johnson', ''),
            ('Kevin', 'Pradervand', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1184744'),
            ('Augustin', 'Schicker', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1079784'),
            ('Brendan', 'Demierre', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1279608')
        ''');

        // Insert keywords
        log('Seeding keywords...');
        await connection.database.execute('''
          INSERT INTO keyword (keyword) VALUES 
            ('gitlab'),
            ('monitoring'),
            ('virtualisation'),
            ('formulaires'),
            ('administration'),
            ('réseau'),
            ('téléphonie'),
            ('formations'),
            ('utilitaires'),
            ('web'),
            ('serveurs'),
            ('vMware'),
            ('grafana'),
            ('firewall'),
            ('dNS'),
            ('ip'),
            ('kubernetes'),
            ('passwords'),
            ('tickets'),
            ('inventaire'),
            ('stockage'),
            ('impression'),
            ('vulnérabilités'),
            ('sondes'),
            ('antennes'),
            ('restauration'),
            ('listes de diffusion'),
            ('annuaire'),
            ('web design'),
            ('microsoft store'),
            ('plans'),
            ('code'),
            ('support')
        ''');

        // Insert sample links
        log('Seeding links...');

        // Gitlab link
        int gitlabId = await connection.database.insert('link', {
          'link': 'https://gitlab-bcul.unil.ch',
          'title': 'Gitlab',
          'description': 'Le Gitlab de la BCUL',
          'doc_link': 'https://docs.gitlab.com/',
          'status_id': 1,
          'category_id': 1,
        });

        // Add relationships
        await connection.database.execute(
            'INSERT INTO link_managers_links (link_id, manager_id) VALUES ($gitlabId, 1)');
        await connection.database.execute(
            'INSERT INTO links_views (link_id, view_id) VALUES ($gitlabId, 1)');
        await connection.database.execute(
            'INSERT INTO keywords_links (link_id, keyword_id) VALUES ($gitlabId, 1), ($gitlabId, 32)');

        // Bookstack link
        int bookstackId = await connection.database.insert('link', {
          'link':
              'https://appm-bookstack.prduks-bcul-ci4881-limited.uks.unil.ch/',
          'title': 'Bookstack',
          'description': 'Bookstack - Le Wiki de la BCUL',
          'doc_link': 'https://www.bookstackapp.com/docs/',
          'status_id': 1,
          'category_id': 1,
        });

        // Add relationships
        await connection.database.execute(
            'INSERT INTO link_managers_links (link_id, manager_id) VALUES ($bookstackId, 1)');
        await connection.database.execute(
            'INSERT INTO links_views (link_id, view_id) VALUES ($bookstackId, 1)');
        await connection.database.execute(
            'INSERT INTO keywords_links (link_id, keyword_id) VALUES ($bookstackId, 1)');

        // Commit the transaction
        await connection.database.commitTransaction();

        log('Development database seeded successfully');
      } catch (e, stackTrace) {
        await connection.database.rollbackTransaction();
        logError('Failed to seed development database', e, stackTrace);
        throw DatabaseException(
            'Failed to seed development database', e, stackTrace);
      }
    } finally {
      await connection.release();
    }
  }
}

/// Testing environment database seeder
class TestingSeeder extends DatabaseSeeder {
  @override
  Future<void> seed(DatabaseConnectionPool connectionPool) async {
    log('Seeding test database...');

    final connection = await connectionPool.getConnection();

    try {
      await connection.database.beginTransaction();

      try {
        // Insert minimal test data

        // Status
        await connection.database.execute('''
          INSERT INTO status (name) VALUES 
            ('Active'),
            ('Inactive')
        ''');

        // Views
        await connection.database.execute('''
          INSERT INTO view (name) VALUES 
            ('Test'),
            ('Admin')
        ''');

        // Categories
        await connection.database.execute('''
          INSERT INTO categories (name) VALUES 
            ('Test Category 1'),
            ('Test Category 2')
        ''');

        // Commit the transaction
        await connection.database.commitTransaction();

        log('Test database seeded successfully');
      } catch (e, stackTrace) {
        await connection.database.rollbackTransaction();
        logError('Failed to seed test database', e, stackTrace);
        throw DatabaseException('Failed to seed test database', e, stackTrace);
      }
    } finally {
      await connection.release();
    }
  }
}
