import 'dart:convert';
import 'dart:io';

import 'package:backend/utils/logger.dart';
import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  late final Database _db;
  final String dbPath;
  PreparedStatement? _categoriesStmt;
  final Map<String, CacheEntry<List<Map<String, dynamic>>>> _categoriesCache =
      {};
  final Duration _cacheTtl = Duration(minutes: 10);
  final _logger = LoggerFactory.getLogger('Database');

  AppDatabase({
    this.dbPath = '/data/data.db',
  });

  Database get db => _db;

  Future<bool> backup(String backupPath) async {
    _logger.info('Starting database backup to $backupPath...');

    try {
      final sourceFile = File(dbPath);

      _db.execute('PRAGMA wal_checkpoint;');

      await sourceFile.copy(backupPath);

      final sourceSize = await sourceFile.length();
      final backupSize = await File(backupPath).length();

      _logger.info('Database backup completed successfully',
          {'sourceSize': sourceSize, 'backupSize': backupSize});

      invalidateCategoriesCache();

      return true;
    } catch (e) {
      _logger.error('Database backup failed', e);
      return false;
    }
  }

  /// Create a new category
  /// Returns the ID of the newly created category
  Future<int> createCategory({
    required String name,
  }) async {
    try {
      // Check if a category with this name already exists
      final existingCategory = _db.select(
        'SELECT id FROM categories WHERE name = ?',
        [name],
      );

      if (existingCategory.isNotEmpty) {
        throw Exception('A category with this name already exists.');
      }

      // Insert the category
      final stmt = _db.prepare('''
      INSERT INTO categories (name)
      VALUES (?)
    ''');

      stmt.execute([name]);
      stmt.dispose();

      // Get the ID of the newly inserted category
      final lastRowId =
          _db.select('SELECT last_insert_rowid() as id').first['id'] as int;

      // Invalidate the categories cache
      invalidateCategoriesCache();

      _logger.info('Created new category', {'id': lastRowId, 'name': name});
      return lastRowId;
    } catch (e) {
      _logger.error('Failed to create category', e);
      rethrow;
    }
  }

  /// Create a new keyword
  /// Returns the ID of the newly created keyword
  Future<int> createKeyword({
    required String keyword,
  }) async {
    try {
      // Check if a keyword with this name already exists
      final existingKeyword = _db.select(
        'SELECT id FROM keyword WHERE keyword = ?',
        [keyword],
      );

      if (existingKeyword.isNotEmpty) {
        throw Exception('A keyword with this name already exists.');
      }

      // Insert the keyword
      final stmt = _db.prepare('''
      INSERT INTO keyword (keyword)
      VALUES (?)
    ''');

      stmt.execute([keyword]);
      stmt.dispose();

      // Get the ID of the newly inserted keyword
      final lastRowId =
          _db.select('SELECT last_insert_rowid() as id').first['id'] as int;

      _logger
          .info('Created new keyword', {'id': lastRowId, 'keyword': keyword});
      return lastRowId;
    } catch (e) {
      _logger.error('Failed to create keyword', e);
      rethrow;
    }
  }

  /// Creates a new link
  /// Returns the ID of the newly created link
  Future<int> createLink({
    required String link,
    required String title,
    required String description,
    String? docLink,
    required int statusId,
    required int categoryId,
    required List<int> viewIds,
    required List<int> keywordIds,
    required List<int> managerIds,
  }) async {
    try {
      // Start a transaction for atomicity
      _db.execute('BEGIN TRANSACTION;');

      // Insert the link
      final stmt = _db.prepare('''
      INSERT INTO link (link, title, description, doc_link, status_id, category_id)
      VALUES (?, ?, ?, ?, ?, ?)
    ''');

      stmt.execute([
        link,
        title,
        description,
        docLink ?? '',
        statusId,
        categoryId,
      ]);

      stmt.dispose();

      // Get the ID of the newly inserted link
      final lastRowId =
          _db.select('SELECT last_insert_rowid() as id').first['id'] as int;

      // Insert view relationships
      if (viewIds.isNotEmpty) {
        final viewValues =
            viewIds.map((viewId) => '($lastRowId, $viewId)').join(', ');
        _db.execute('''
        INSERT INTO links_views (link_id, view_id)
        VALUES $viewValues
      ''');
      }

      // Insert keyword relationships
      if (keywordIds.isNotEmpty) {
        final keywordValues = keywordIds
            .map((keywordId) => '($lastRowId, $keywordId)')
            .join(', ');
        _db.execute('''
        INSERT INTO keywords_links (link_id, keyword_id)
        VALUES $keywordValues
      ''');
      }

      // Insert manager relationships
      if (managerIds.isNotEmpty) {
        final managerValues = managerIds
            .map((managerId) => '($lastRowId, $managerId)')
            .join(', ');
        _db.execute('''
        INSERT INTO link_managers_links (link_id, manager_id)
        VALUES $managerValues
      ''');
      }

      // Commit the transaction
      _db.execute('COMMIT;');

      // Invalidate the categories cache since we've modified links
      invalidateCategoriesCache();

      _logger.info('Created new link', {'id': lastRowId, 'title': title});
      return lastRowId;
    } catch (e) {
      // Rollback in case of error
      _db.execute('ROLLBACK;');
      _logger.error('Failed to create link', e);
      rethrow;
    }
  }

  /// Create a new link manager
  /// Returns the ID of the newly created link manager
  Future<int> createLinkManager({
    required String name,
    required String surname,
    String? link,
  }) async {
    try {
      // Insert the link manager
      final stmt = _db.prepare('''
      INSERT INTO link_manager (name, surname, link)
      VALUES (?, ?, ?)
    ''');

      stmt.execute([name, surname, link ?? '']);
      stmt.dispose();

      // Get the ID of the newly inserted link manager
      final lastRowId =
          _db.select('SELECT last_insert_rowid() as id').first['id'] as int;

      _logger.info('Created new link manager',
          {'id': lastRowId, 'name': name, 'surname': surname});

      return lastRowId;
    } catch (e) {
      _logger.error('Failed to create link manager', e);
      rethrow;
    }
  }

  /// Create a new status
  /// Returns the ID of the newly created status
  Future<int> createStatus({
    required String name,
  }) async {
    try {
      // Check if a status with this name already exists
      final existingStatus = _db.select(
        'SELECT id FROM status WHERE name = ?',
        [name],
      );

      if (existingStatus.isNotEmpty) {
        throw Exception('A status with this name already exists.');
      }

      // Insert the status
      final stmt = _db.prepare('''
      INSERT INTO status (name)
      VALUES (?)
    ''');

      stmt.execute([name]);
      stmt.dispose();

      // Get the ID of the newly inserted status
      final lastRowId =
          _db.select('SELECT last_insert_rowid() as id').first['id'] as int;

      _logger.info('Created new status', {'id': lastRowId, 'name': name});
      return lastRowId;
    } catch (e) {
      _logger.error('Failed to create status', e);
      rethrow;
    }
  }

  /// Create a new view
  /// Returns the ID of the newly created view
  Future<int> createView({
    required String name,
  }) async {
    try {
      // Check if a view with this name already exists
      final existingView = _db.select(
        'SELECT id FROM view WHERE name = ?',
        [name],
      );

      if (existingView.isNotEmpty) {
        throw Exception('A view with this name already exists.');
      }

      // Insert the view
      final stmt = _db.prepare('''
      INSERT INTO view (name)
      VALUES (?)
    ''');

      stmt.execute([name]);
      stmt.dispose();

      // Get the ID of the newly inserted view
      final lastRowId =
          _db.select('SELECT last_insert_rowid() as id').first['id'] as int;

      // Invalidate the categories cache since views affect permissions
      invalidateCategoriesCache();

      _logger.info('Created new view', {'id': lastRowId, 'name': name});
      return lastRowId;
    } catch (e) {
      _logger.error('Failed to create view', e);
      rethrow;
    }
  }

  /// Delete a category
  /// Returns true if the deletion was successful
  Future<bool> deleteCategory(int id) async {
    try {
      // Check if the category exists
      final exists =
          _db.select('SELECT 1 FROM categories WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Category not found for deletion', {'id': id});
        return false;
      }

      // Check if there are any links using this category
      final linkedLinks = _db.select(
        'SELECT COUNT(*) as count FROM link WHERE category_id = ?',
        [id],
      ).first['count'] as int;

      if (linkedLinks > 0) {
        throw Exception(
            'Cannot delete category: it is used by $linkedLinks links.');
      }

      // Start a transaction
      _db.execute('BEGIN TRANSACTION;');

      // Delete the category
      _db.execute('DELETE FROM categories WHERE id = ?', [id]);

      // Commit the transaction
      _db.execute('COMMIT;');

      // Invalidate the categories cache
      invalidateCategoriesCache();

      _logger.info('Deleted category', {'id': id});
      return true;
    } catch (e) {
      // Rollback in case of error
      _db.execute('ROLLBACK;');
      _logger.error('Failed to delete category', e, null, {'id': id});
      rethrow;
    }
  }

  /// Delete a keyword
  /// Returns true if the deletion was successful
  Future<bool> deleteKeyword(int id) async {
    try {
      // Check if the keyword exists
      final exists =
          _db.select('SELECT 1 FROM keyword WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Keyword not found for deletion', {'id': id});
        return false;
      }

      // Check if there are any links using this keyword
      final linkedLinks = _db.select(
        'SELECT COUNT(*) as count FROM keywords_links WHERE keyword_id = ?',
        [id],
      ).first['count'] as int;

      if (linkedLinks > 0) {
        throw Exception(
            'Cannot delete keyword: it is used by $linkedLinks links.');
      }

      // Start a transaction
      _db.execute('BEGIN TRANSACTION;');

      // Delete the keyword
      _db.execute('DELETE FROM keyword WHERE id = ?', [id]);

      // Commit the transaction
      _db.execute('COMMIT;');

      _logger.info('Deleted keyword', {'id': id});
      return true;
    } catch (e) {
      // Rollback in case of error
      _db.execute('ROLLBACK;');
      _logger.error('Failed to delete keyword', e, null, {'id': id});
      rethrow;
    }
  }

  /// Delete a link
  /// Returns true if the deletion was successfull
  Future<bool> deleteLink(int id) async {
    try {
      // Check if the link exists
      final exists =
          _db.select('SELECT 1 FROM link WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Link not found for deletion', {'id': id});
        return false;
      }

      // Start a transaction
      _db.execute('BEGIN TRANSACTION;');

      // Delete related data first (foreign key constraints)
      _db.execute('DELETE FROM links_views WHERE link_id = ?', [id]);
      _db.execute('DELETE FROM keywords_links WHERE link_id = ?', [id]);
      _db.execute('DELETE FROM link_managers_links WHERE link_id = ?', [id]);

      // Delete the link itself
      _db.execute('DELETE FROM link WHERE id = ?', [id]);

      // Commit the transaction
      _db.execute('COMMIT;');

      // Invalidate the categories cache
      invalidateCategoriesCache();

      _logger.info('Deleted link', {'id': id});
      return true;
    } catch (e) {
      // Rollback in case of error
      _db.execute('ROLLBACK;');
      _logger.error('Failed to delete link', e, null, {'id': id});
      rethrow;
    }
  }

  /// Delete a link manager
  /// Returns true if the deletion was successful
  Future<bool> deleteLinkManager(int id) async {
    try {
      // Check if the link manager exists
      final exists = _db
          .select('SELECT 1 FROM link_manager WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Link manager not found for deletion', {'id': id});
        return false;
      }

      // Check if there are any links using this link manager
      final linkedLinks = _db.select(
        'SELECT COUNT(*) as count FROM link_managers_links WHERE manager_id = ?',
        [id],
      ).first['count'] as int;

      if (linkedLinks > 0) {
        throw Exception(
            'Cannot delete link manager: it is associated with $linkedLinks links.');
      }

      // Start a transaction
      _db.execute('BEGIN TRANSACTION;');

      // Delete the link manager
      _db.execute('DELETE FROM link_manager WHERE id = ?', [id]);

      // Commit the transaction
      _db.execute('COMMIT;');

      _logger.info('Deleted link manager', {'id': id});
      return true;
    } catch (e) {
      // Rollback in case of error
      _db.execute('ROLLBACK;');
      _logger.error('Failed to delete link manager', e, null, {'id': id});
      rethrow;
    }
  }

  /// Delete a status
  /// Returns true if the deletion was successful
  Future<bool> deleteStatus(int id) async {
    try {
      // Check if the status exists
      final exists =
          _db.select('SELECT 1 FROM status WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Status not found for deletion', {'id': id});
        return false;
      }

      // Check if there are any links using this status
      final linkedLinks = _db.select(
        'SELECT COUNT(*) as count FROM link WHERE status_id = ?',
        [id],
      ).first['count'] as int;

      if (linkedLinks > 0) {
        throw Exception(
            'Cannot delete status: it is used by $linkedLinks links.');
      }

      // Start a transaction
      _db.execute('BEGIN TRANSACTION;');

      // Delete the status
      _db.execute('DELETE FROM status WHERE id = ?', [id]);

      // Commit the transaction
      _db.execute('COMMIT;');

      _logger.info('Deleted status', {'id': id});
      return true;
    } catch (e) {
      // Rollback in case of error
      _db.execute('ROLLBACK;');
      _logger.error('Failed to delete status', e, null, {'id': id});
      rethrow;
    }
  }

  /// Delete a view
  /// Returns true if the deletion was successful
  Future<bool> deleteView(int id) async {
    try {
      // Check if the view exists
      final exists =
          _db.select('SELECT 1 FROM view WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('View not found for deletion', {'id': id});
        return false;
      }

      // Check if there are any links using this view
      final linkedLinks = _db.select(
        'SELECT COUNT(*) as count FROM links_views WHERE view_id = ?',
        [id],
      ).first['count'] as int;

      if (linkedLinks > 0) {
        throw Exception(
            'Cannot delete view: it is used by $linkedLinks links.');
      }

      // Start a transaction
      _db.execute('BEGIN TRANSACTION;');

      // Delete the view
      _db.execute('DELETE FROM view WHERE id = ?', [id]);

      // Commit the transaction
      _db.execute('COMMIT;');

      // Invalidate the categories cache since views affect permissions
      invalidateCategoriesCache();

      _logger.info('Deleted view', {'id': id});
      return true;
    } catch (e) {
      // Rollback in case of error
      _db.execute('ROLLBACK;');
      _logger.error('Failed to delete view', e, null, {'id': id});
      rethrow;
    }
  }

  void dispose() {
    try {
      _db.dispose();
      _logger.info('Database connection closed.');
    } catch (e) {
      _logger.error('Error closing database', e);
    }
  }

  List<Map<String, dynamic>> executeQuery(String sql,
      [List<Object?> parameters = const []]) {
    try {
      final result = _db.select(sql, parameters);
      return result;
    } catch (e) {
      _logger.error('Error while executing query', e);
      rethrow;
    }
  }

  /// Get all keywords
  /// Returns a list of keyword objects
  List<Map<String, dynamic>> getAllKeywords() {
    try {
      return _db.select('''
      SELECT id, keyword
      FROM keyword
      ORDER BY keyword
    ''');
    } catch (e) {
      _logger.error('Error retrieving all keywords', e);
      return [];
    }
  }

  /// Get all link managers
  /// Returns a list of link manager objects
  List<Map<String, dynamic>> getAllLinkManagers() {
    try {
      return _db.select('''
      SELECT id, name, surname, link
      FROM link_manager
      ORDER BY surname, name
    ''');
    } catch (e) {
      _logger.error('Error retrieving all link managers', e);
      return [];
    }
  }

  /// Get all statuses
  /// Returns a list of status objects
  List<Map<String, dynamic>> getAllStatuses() {
    try {
      return _db.select('''
      SELECT id, name
      FROM status
      ORDER BY name
    ''');
    } catch (e) {
      _logger.error('Error retrieving all statuses', e);
      return [];
    }
  }

  /// Get all views
  /// Returns a list of view objects with their permissions
  List<Map<String, dynamic>> getAllViews() {
    try {
      return _db.select('''
      SELECT id, name
      FROM view
      ORDER BY name
    ''');
    } catch (e) {
      _logger.error('Error retrieving all views', e);
      return [];
    }
  }

  List<Map<String, dynamic>> getCategoriesForUser(List<String> userGroups) {
    if (userGroups.isEmpty) {
      return [];
    }

    // Sort groups for consistent cache key
    final sortedGroups = List<String>.from(userGroups)..sort();
    final cacheKey = sortedGroups.join(',');

    // Check cache
    final cachedResult = _categoriesCache[cacheKey];
    if (cachedResult != null && cachedResult.isValid) {
      return List<Map<String, dynamic>>.from(cachedResult.data);
    }

    // Execute query if not in cache
    final result = _executeGetCategoriesQuery(userGroups);

    // Cache the result
    _categoriesCache[cacheKey] =
        CacheEntry<List<Map<String, dynamic>>>(result, _cacheTtl);

    return result;
  }

  /// Get a category by ID
  /// Returns the category data or null if not found
  Map<String, dynamic>? getCategoryById(int id) {
    try {
      final results = _db.select('''
      SELECT 
        id, name
      FROM categories
      WHERE id = ?
    ''', [id]);

      if (results.isEmpty) {
        return null;
      }

      return Map<String, dynamic>.from(results.first);
    } catch (e) {
      _logger.error('Error retrieving category', e, null, {'id': id});
      return null;
    }
  }

  Map<String, dynamic> getDatabaseStats() {
    return {
      'size_kb': File(dbPath).lengthSync() ~/ 1024,
      'page_count': _db.select('PRAGMA page_count;').first['page_count'],
      'page_size': _db.select('PRAGMA page_size;').first['page_size'],
      'schema_version': _db
              .select(
                  "SELECT value FROM db_metadata WHERE key = 'schema_version';")
              .firstOrNull?['value'] ??
          '0',
      'tables': _db
          .select(
              "SELECT name, (SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND tbl_name=m.name) as index_count FROM sqlite_master m WHERE type='table' AND name NOT LIKE 'sqlite_%';")
          .map((row) => {
                'name': row['name'],
                'index_count': row['index_count'],
              })
          .toList(),
    };
  }

  /// Get a keyword by ID
  /// Returns the keyword data or null if not found
  Map<String, dynamic>? getKeywordById(int id) {
    try {
      final results = _db.select('''
      SELECT id, keyword
      FROM keyword
      WHERE id = ?
    ''', [id]);

      if (results.isEmpty) {
        return null;
      }

      return Map<String, dynamic>.from(results.first);
    } catch (e) {
      _logger.error('Error retrieving keyword', e, null, {'id': id});
      return null;
    }
  }

  /// Get a link by ID
  /// Returns the link data or null if not found
  Map<String, dynamic>? getLinkById(int id) {
    try {
      final results = _db.select('''
      SELECT 
        l.id, l.link, l.title, l.description, l.doc_link, 
        l.status_id, s.name as status_name,
        l.category_id, c.name as category_name
      FROM link l
      LEFT JOIN status s ON s.id = l.status_id
      LEFT JOIN categories c ON c.id = l.category_id
      WHERE l.id = ?
    ''', [id]);

      if (results.isEmpty) {
        return null;
      }

      final link = Map<String, dynamic>.from(results.first);

      // Get views
      final views = _db.select('''
      SELECT v.id, v.name
      FROM links_views lv
      JOIN view v ON v.id = lv.view_id
      WHERE lv.link_id = ?
    ''', [id]).map((row) => Map<String, dynamic>.from(row)).toList();

      // Get keywords
      final keywords = _db.select('''
      SELECT k.id, k.keyword
      FROM keywords_links kl
      JOIN keyword k ON k.id = kl.keyword_id
      WHERE kl.link_id = ?
    ''', [id]).map((row) => Map<String, dynamic>.from(row)).toList();

      // Get managers
      final managers = _db.select('''
      SELECT m.id, m.name, m.surname, m.link
      FROM link_managers_links lm
      JOIN link_manager m ON m.id = lm.manager_id
      WHERE lm.link_id = ?
    ''', [id]).map((row) => Map<String, dynamic>.from(row)).toList();

      // Add relationships to the result
      link['views'] = views;
      link['keywords'] = keywords;
      link['managers'] = managers;

      return link;
    } catch (e) {
      _logger.error('Error retrieving link', e, null, {'id': id});
      return null;
    }
  }

  /// Get a link manager by ID
  /// Returns the link manager data or null if not found
  Map<String, dynamic>? getLinkManagerById(int id) {
    try {
      final results = _db.select('''
      SELECT id, name, surname, link
      FROM link_manager
      WHERE id = ?
    ''', [id]);

      if (results.isEmpty) {
        return null;
      }

      return Map<String, dynamic>.from(results.first);
    } catch (e) {
      _logger.error('Error retrieving link manager', e, null, {'id': id});
      return null;
    }
  }

  /// Get links by keyword ID
  /// Returns a list of links that use the specified keyword
  List<Map<String, dynamic>> getLinksByKeywordId(int keywordId) {
    try {
      return _db.select('''
      SELECT 
        l.id, l.link, l.title, l.description, l.doc_link, 
        l.status_id, s.name as status_name,
        l.category_id, c.name as category_name
      FROM link l
      JOIN keywords_links kl ON kl.link_id = l.id
      LEFT JOIN status s ON s.id = l.status_id
      LEFT JOIN categories c ON c.id = l.category_id
      WHERE kl.keyword_id = ?
      ORDER BY l.title
    ''', [keywordId]);
    } catch (e) {
      _logger.error('Error retrieving links by keyword', e, null,
          {'keywordId': keywordId});
      return [];
    }
  }

  /// Get links by link manager ID
  /// Returns a list of links that are associated with the specified link manager
  List<Map<String, dynamic>> getLinksByManagerId(int managerId) {
    try {
      return _db.select('''
      SELECT 
        l.id, l.link, l.title, l.description, l.doc_link, 
        l.status_id, s.name as status_name,
        l.category_id, c.name as category_name
      FROM link l
      JOIN link_managers_links lml ON lml.link_id = l.id
      LEFT JOIN status s ON s.id = l.status_id
      LEFT JOIN categories c ON c.id = l.category_id
      WHERE lml.manager_id = ?
      ORDER BY l.title
    ''', [managerId]);
    } catch (e) {
      _logger.error('Error retrieving links by manager', e, null,
          {'managerId': managerId});
      return [];
    }
  }

  /// Get links by view ID
  /// Returns a list of links that belong to the specified view
  List<Map<String, dynamic>> getLinksByViewId(int viewId) {
    try {
      return _db.select('''
      SELECT 
        l.id, l.link, l.title, l.description, l.doc_link, 
        l.status_id, s.name as status_name,
        l.category_id, c.name as category_name
      FROM link l
      JOIN links_views lv ON lv.link_id = l.id
      LEFT JOIN status s ON s.id = l.status_id
      LEFT JOIN categories c ON c.id = l.category_id
      WHERE lv.view_id = ?
      ORDER BY l.title
    ''', [viewId]);
    } catch (e) {
      _logger
          .error('Error retrieving links by view', e, null, {'viewId': viewId});
      return [];
    }
  }

  // Methods to add to the AppDatabase class in lib/db/database.dart

  /// Get a status by ID
  /// Returns the status data or null if not found
  Map<String, dynamic>? getStatusById(int id) {
    try {
      final results = _db.select('''
      SELECT id, name
      FROM status
      WHERE id = ?
    ''', [id]);

      if (results.isEmpty) {
        return null;
      }

      return Map<String, dynamic>.from(results.first);
    } catch (e) {
      _logger.error('Error retrieving status', e, null, {'id': id});
      return null;
    }
  }

  /// Get a view by ID
  /// Returns the view data or null if not found
  Map<String, dynamic>? getViewById(int id) {
    try {
      final results = _db.select('''
      SELECT id, name
      FROM view
      WHERE id = ?
    ''', [id]);

      if (results.isEmpty) {
        return null;
      }

      return Map<String, dynamic>.from(results.first);
    } catch (e) {
      _logger.error('Error retrieving view', e, null, {'id': id});
      return null;
    }
  }

  void init() {
    final dbDir = Directory(dbPath.substring(0, dbPath.lastIndexOf('/')));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }

    _db = sqlite3.open('/data/data.db');
    _initializeDatabase();

    _logger.info('Database initialized at $dbPath');

    if (!_checkDatabaseIntegrity()) {
      _logger.warning(
          'WARNING: Database integrity check failed. Consider running recovery.');
    }
  }

  void invalidateCategoriesCache() {
    _categoriesCache.clear();
  }

  bool isConnected() {
    try {
      // Execute a simple query to check if the database is connected
      _db.execute('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update an existing category
  /// Returns true if the update was successful
  Future<bool> updateCategory({
    required int id,
    required String name,
  }) async {
    try {
      // Check if the category exists
      final exists =
          _db.select('SELECT 1 FROM categories WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Category not found for update', {'id': id});
        return false;
      }

      // Check if another category with this name already exists
      final existingCategory = _db.select(
        'SELECT id FROM categories WHERE name = ? AND id != ?',
        [name, id],
      );

      if (existingCategory.isNotEmpty) {
        throw Exception('Another category with this name already exists.');
      }

      // Update the category
      _db.execute(
        'UPDATE categories SET name = ? WHERE id = ?',
        [name, id],
      );

      // Invalidate the categories cache
      invalidateCategoriesCache();

      _logger.info('Updated category', {'id': id, 'name': name});
      return true;
    } catch (e) {
      _logger.error('Failed to update category', e, null, {'id': id});
      rethrow;
    }
  }

  // Methods to add to the AppDatabase class in lib/db/database.dart

  /// Update an existing keyword
  /// Returns true if the update was successful
  Future<bool> updateKeyword({
    required int id,
    required String keyword,
  }) async {
    try {
      // Check if the keyword exists
      final exists =
          _db.select('SELECT 1 FROM keyword WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Keyword not found for update', {'id': id});
        return false;
      }

      // Check if another keyword with this name already exists
      final existingKeyword = _db.select(
        'SELECT id FROM keyword WHERE keyword = ? AND id != ?',
        [keyword, id],
      );

      if (existingKeyword.isNotEmpty) {
        throw Exception('Another keyword with this name already exists.');
      }

      // Update the keyword
      _db.execute(
        'UPDATE keyword SET keyword = ? WHERE id = ?',
        [keyword, id],
      );

      _logger.info('Updated keyword', {'id': id, 'keyword': keyword});
      return true;
    } catch (e) {
      _logger.error('Failed to update keyword', e, null, {'id': id});
      rethrow;
    }
  }

  /// Update an existing link
  /// Returns true if the update was successfull
  Future<bool> updateLink({
    required int id,
    String? link,
    String? title,
    String? description,
    String? docLink,
    int? statusId,
    int? categoryId,
    List<int>? viewIds,
    List<int>? keywordIds,
    List<int>? managerIds,
  }) async {
    try {
      // Check if the link exists
      final exists =
          _db.select('SELECT 1 FROM link WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Link not found for update', {'id': id});
        return false;
      }

      // Start a transaction
      _db.execute('BEGIN TRANSACTION;');

      // Build the update statement dynamically based on provided fields
      final updates = <String>[];
      final params = <Object?>[];

      if (link != null) {
        updates.add('link = ?');
        params.add(link);
      }

      if (title != null) {
        updates.add('title = ?');
        params.add(title);
      }

      if (description != null) {
        updates.add('description = ?');
        params.add(description);
      }

      if (docLink != null) {
        updates.add('doc_link = ?');
        params.add(docLink);
      }

      if (statusId != null) {
        updates.add('status_id = ?');
        params.add(statusId);
      }

      if (categoryId != null) {
        updates.add('category_id = ?');
        params.add(categoryId);
      }

      // If we have fields to update
      if (updates.isNotEmpty) {
        params.add(id); // Add the id parameter for the WHERE clause
        final updateSql = '''
        UPDATE link 
        SET ${updates.join(', ')} 
        WHERE id = ?
      ''';
        _db.execute(updateSql, params);
      }

      // Update view relationships if specified
      if (viewIds != null) {
        // Delete existing relationships
        _db.execute('DELETE FROM links_views WHERE link_id = ?', [id]);

        // Insert new relationships
        if (viewIds.isNotEmpty) {
          final viewValues =
              viewIds.map((viewId) => '($id, $viewId)').join(', ');
          _db.execute('''
          INSERT INTO links_views (link_id, view_id)
          VALUES $viewValues
        ''');
        }
      }

      // Update keyword relationships if specified
      if (keywordIds != null) {
        // Delete existing relationships
        _db.execute('DELETE FROM keywords_links WHERE link_id = ?', [id]);

        // Insert new relationships
        if (keywordIds.isNotEmpty) {
          final keywordValues =
              keywordIds.map((keywordId) => '($id, $keywordId)').join(', ');
          _db.execute('''
          INSERT INTO keywords_links (link_id, keyword_id)
          VALUES $keywordValues
        ''');
        }
      }

      // Update manager relationships if specified
      if (managerIds != null) {
        // Delete existing relationships
        _db.execute('DELETE FROM link_managers_links WHERE link_id = ?', [id]);

        // Insert new relationships
        if (managerIds.isNotEmpty) {
          final managerValues =
              managerIds.map((managerId) => '($id, $managerId)').join(', ');
          _db.execute('''
          INSERT INTO link_managers_links (link_id, manager_id)
          VALUES $managerValues
        ''');
        }
      }

      // Commit the transaction
      _db.execute('COMMIT;');

      // Invalidate the categories cache
      invalidateCategoriesCache();

      _logger.info('Updated link', {'id': id});
      return true;
    } catch (e) {
      // Rollback in case of error
      _db.execute('ROLLBACK;');
      _logger.error('Failed to update link', e, null, {'id': id});
      rethrow;
    }
  }

  /// Update an existing link manager
  /// Returns true if the update was successful
  Future<bool> updateLinkManager({
    required int id,
    String? name,
    String? surname,
    String? link,
  }) async {
    try {
      // Check if the link manager exists
      final exists = _db
          .select('SELECT 1 FROM link_manager WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Link manager not found for update', {'id': id});
        return false;
      }

      // Build the update statement dynamically based on provided fields
      final updates = <String>[];
      final params = <Object?>[];

      if (name != null) {
        updates.add('name = ?');
        params.add(name);
      }

      if (surname != null) {
        updates.add('surname = ?');
        params.add(surname);
      }

      if (link != null) {
        updates.add('link = ?');
        params.add(link);
      }

      // If we have fields to update
      if (updates.isNotEmpty) {
        params.add(id); // Add the id parameter for the WHERE clause
        final updateSql = '''
        UPDATE link_manager 
        SET ${updates.join(', ')} 
        WHERE id = ?
      ''';

        _db.execute(updateSql, params);

        _logger.info('Updated link manager', {'id': id});
        return true;
      } else {
        _logger.warning('No fields to update for link manager', {'id': id});
        return false;
      }
    } catch (e) {
      _logger.error('Failed to update link manager', e, null, {'id': id});
      rethrow;
    }
  }

  /// Update an existing status
  /// Returns true if the update was successful
  Future<bool> updateStatus({
    required int id,
    required String name,
  }) async {
    try {
      // Check if the status exists
      final exists =
          _db.select('SELECT 1 FROM status WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('Status not found for update', {'id': id});
        return false;
      }

      // Check if another status with this name already exists
      final existingStatus = _db.select(
        'SELECT id FROM status WHERE name = ? AND id != ?',
        [name, id],
      );

      if (existingStatus.isNotEmpty) {
        throw Exception('Another status with this name already exists.');
      }

      // Update the status
      _db.execute(
        'UPDATE status SET name = ? WHERE id = ?',
        [name, id],
      );

      _logger.info('Updated status', {'id': id, 'name': name});
      return true;
    } catch (e) {
      _logger.error('Failed to update status', e, null, {'id': id});
      rethrow;
    }
  }

  /// Update an existing view
  /// Returns true if the update was successful
  Future<bool> updateView({
    required int id,
    required String name,
  }) async {
    try {
      // Check if the view exists
      final exists =
          _db.select('SELECT 1 FROM view WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        _logger.warning('View not found for update', {'id': id});
        return false;
      }

      // Check if another view with this name already exists
      final existingView = _db.select(
        'SELECT id FROM view WHERE name = ? AND id != ?',
        [name, id],
      );

      if (existingView.isNotEmpty) {
        throw Exception('Another view with this name already exists.');
      }

      // Update the view
      _db.execute(
        'UPDATE view SET name = ? WHERE id = ?',
        [name, id],
      );

      // Invalidate the categories cache since views affect permissions
      invalidateCategoriesCache();

      _logger.info('Updated view', {'id': id, 'name': name});
      return true;
    } catch (e) {
      _logger.error('Failed to update view', e, null, {'id': id});
      rethrow;
    }
  }

  bool _checkDatabaseIntegrity() {
    try {
      final result = _db.select("PRAGMA integrity_check;");
      return result.first['integrity_check'] == 'ok';
    } catch (e) {
      _logger.error('Database integrity check failed', e);
      return false;
    }
  }

  void _createIndexes() {
    _logger.info('Creating database indexes for performance optimization...');
    _db.execute('''
      -- Indexes for link table
      CREATE INDEX IF NOT EXISTS idx_link_category ON link(category_id);
      CREATE INDEX IF NOT EXISTS idx_link_status ON link(status_id);

      -- Indexes for relationship tables
      CREATE INDEX IF NOT EXISTS idx_links_views_link ON links_views(link_id);
      CREATE INDEX IF NOT EXISTS idx_links_views_view ON links_views(view_id);
      CREATE INDEX IF NOT EXISTS idx_keywords_links_link ON keywords_links(link_id);
      CREATE INDEX IF NOT EXISTS idx_keywords_links_keyword ON keywords_links(keyword_id);
      CREATE INDEX IF NOT EXISTS idx_link_managers_links_link ON link_managers_links(link_id);
      CREATE INDEX IF NOT EXISTS idx_link_managers_links_manager ON link_managers_links(manager_id);
      CREATE INDEX IF NOT EXISTS idx_link_title ON link(title);
      CREATE INDEX IF NOT EXISTS idx_link_description ON link(description);
      CREATE INDEX IF NOT EXISTS idx_view_name ON view(name);
      CREATE INDEX IF NOT EXISTS idx_keyword_keyword ON keyword(keyword);
    ''');
  }

  void _createTables() {
    _db.execute('''
CREATE TABLE IF NOT EXISTS `link` (
	`id` integer primary key NOT NULL UNIQUE,
	`link` TEXT NOT NULL,
	`title` TEXT NOT NULL UNIQUE,
	`description` TEXT NOT NULL,
	`doc_link` TEXT,
	`status_id` INTEGER NOT NULL,
	`category_id` INTEGER NOT NULL,
FOREIGN KEY(`status_id`) REFERENCES `status`(`id`),
FOREIGN KEY(`category_id`) REFERENCES `categories`(`id`)
);
CREATE TABLE IF NOT EXISTS `link_manager` (
	`id` integer primary key NOT NULL UNIQUE,
	`name` TEXT NOT NULL,
	`surname` TEXT NOT NULL,
	`link` TEXT
);
CREATE TABLE IF NOT EXISTS `link_managers_links` (
	`link_id` INTEGER NOT NULL,
	`manager_id` INTEGER NOT NULL,
FOREIGN KEY(`link_id`) REFERENCES `link`(`id`),
FOREIGN KEY(`manager_id`) REFERENCES `link_manager`(`id`)
);
CREATE TABLE IF NOT EXISTS `view` (
	`id` integer primary key NOT NULL UNIQUE,
	`name` TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS `links_views` (
	`link_id` INTEGER NOT NULL,
	`view_id` INTEGER NOT NULL,
FOREIGN KEY(`link_id`) REFERENCES `link`(`id`),
FOREIGN KEY(`view_id`) REFERENCES `view`(`id`)
);
CREATE TABLE IF NOT EXISTS `categories` (
	`id` integer primary key NOT NULL UNIQUE,
	`name` TEXT NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS `status` (
	`id` integer primary key NOT NULL UNIQUE,
	`name` TEXT NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS `keyword` (
	`id` integer primary key NOT NULL UNIQUE,
	`keyword` TEXT NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS `keywords_links` (
	`link_id` INTEGER NOT NULL,
	`keyword_id` INTEGER NOT NULL,
FOREIGN KEY(`link_id`) REFERENCES `link`(`id`),
FOREIGN KEY(`keyword_id`) REFERENCES `keyword`(`id`)
);
    ''');
  }

  List<Map<String, dynamic>> _executeGetCategoriesQuery(
      List<String> userGroups) {
    _categoriesStmt ??= _prepareGetCategoriesStatement();

    try {
      // Create a parameter list that matches the number of placeholders
      // Since we used 99 placeholders in the prepared statement, we need to pad with empty values if there are fewer groups
      final parameters = <String>[...userGroups];
      if (parameters.length < 99) {
        parameters.addAll(List.filled(99 - parameters.length, ''));
      }

      final result = _categoriesStmt!.select(parameters);

      return result.map((row) {
        var map = Map<String, dynamic>.from(row);
        var linksJson = map['links'] as String;

        List links;
        try {
          links = jsonDecode(linksJson) as List;
        } catch (e) {
          _logger.error('Error parsing JSON links data', e);
          links = [];
        }

        links = links.where((link) => link != null).map((link) {
          if (link is! Map<String, dynamic>) return link;

          // Parse nested JSON strings
          try {
            if (link['keywords'] is String) {
              link['keywords'] = jsonDecode(link['keywords']);
            }
          } catch (e) {
            link['keywords'] = [];
          }

          try {
            if (link['views'] is String) {
              link['views'] = jsonDecode(link['views']);
            }
          } catch (e) {
            link['views'] = [];
          }

          try {
            if (link['managers'] is String) {
              link['managers'] = jsonDecode(link['managers']);
            }
          } catch (e) {
            link['managers'] = [];
          }

          return link;
        }).toList();

        map['links'] = links;
        return map;
      }).toList();
    } catch (e) {
      _logger.error('Error executing getCategoriesForUser', e);

      // If an error occurs, recreate the prepared statement
      if (_categoriesStmt != null) {
        try {
          _categoriesStmt!.dispose();
        } catch (_) {}
        _categoriesStmt = null;
      }

      _categoriesStmt = _prepareGetCategoriesStatement();

      // Fall back to a simpler query if the optimized one fails
      return _executeSimpleCategoriesQuery(userGroups);
    }
  }

  List<Map<String, dynamic>> _executeSimpleCategoriesQuery(
      List<String> userGroups) {
    final placeholders = userGroups.map((_) => '?').join(',');

    final sql = '''
    SELECT 
      c.id as category_id,
      c.name as category_name
    FROM categories c
  ''';

    final categories = executeQuery(sql);

    // For each category, fetch the links separately
    for (var category in categories) {
      final linksSql = '''
      SELECT 
        l.id,
        l.link,
        l.title,
        l.description,
        l.doc_link,
        l.status_id,
        s.name as status_name
      FROM link l
      LEFT JOIN status s ON s.id = l.status_id
      WHERE l.category_id = ?
      AND EXISTS (
        SELECT 1 
        FROM links_views lv
        JOIN view v ON v.id = lv.view_id
        WHERE lv.link_id = l.id 
        AND v.name IN ($placeholders)
      )
    ''';

      final links =
          executeQuery(linksSql, [category['category_id'], ...userGroups]);

      // For each link, fetch keywords, views, and managers
      for (var link in links) {
        // Get keywords
        final keywordsSql = '''
        SELECT k.id, k.keyword
        FROM keywords_links kl
        JOIN keyword k ON k.id = kl.keyword_id
        WHERE kl.link_id = ?
      ''';
        link['keywords'] = executeQuery(keywordsSql, [link['id']]);

        // Get views
        final viewsSql = '''
        SELECT v.id, v.name
        FROM links_views lv
        JOIN view v ON v.id = lv.view_id
        WHERE lv.link_id = ?
      ''';
        link['views'] = executeQuery(viewsSql, [link['id']]);

        // Get managers
        final managersSql = '''
        SELECT m.id, m.name, m.surname, m.link
        FROM link_managers_links lm
        JOIN link_manager m ON m.id = lm.manager_id
        WHERE lm.link_id = ?
      ''';
        link['managers'] = executeQuery(managersSql, [link['id']]);
      }

      category['links'] = links;
    }

    return categories;
  }

  void _initializeDatabase() {
    // Create version table if it doesn't exist
    _db.execute('''
      CREATE TABLE IF NOT EXISTS db_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // Check current schema version
    final versionResult = _db
        .select("SELECT value FROM db_metadata WHERE key = 'schema_version';");

    final currentVersion =
        versionResult.isEmpty ? 0 : int.parse(versionResult.first['value']);
    const targetVersion = 1; // Increment this when schema changes

    if (currentVersion < targetVersion) {
      _logger.info('Upgrading database...',
          {'currentVersion': currentVersion, 'targetVersion': targetVersion});
      _db.execute('BEGIN TRANSACTION;');

      try {
        if (currentVersion == 0) {
          _createTables();
          _createIndexes();

          // Check if we need to insert mock data
          final categoriesCount =
              _db.select('SELECT COUNT(*) as count FROM categories;');
          if (categoriesCount.first['count'] == 0) {
            _insertMockData();
          }
        }

        // Future migrations would go here
        // if (currentVersion < 2) _migrateToV2();

        // Update the schema version
        _db.execute('''
          INSERT OR REPLACE INTO db_metadata (key, value) 
          VALUES ('schema_version', '$targetVersion');
        ''');

        _db.execute('COMMIT;');
        _logger.info('Database migration completed successfully');
      } catch (e) {
        _db.execute('ROLLBACK;');
        _logger.error('Database migration failed', e);
        rethrow;
      }
    }
  }

  void _insertMockData() {
    try {
      final mockData = [
        '''
-- Insert statuses
INSERT INTO status (name) VALUES ('Active');
INSERT INTO status (name) VALUES ('Inactive');

-- Insert views
INSERT INTO view (name) VALUES ('si-bcu-g');
INSERT INTO view (name) VALUES ('User');

-- Insert categories
INSERT INTO categories (name) VALUES ('Applications métiers'),
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
 ('Utilitaires');

-- Insert managers
INSERT INTO link_manager (name, surname, link) VALUES 
 ('Bob', 'Brown', ''),
 ('John', 'Doe', ''),
 ('Jane', 'Smith', ''),
 ('Alice', 'Johnson', ''),
 ('Kevin', 'Pradervand', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1184744'),
 ('Augustin', 'Schicker', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1079784'),
 ('Brendan', 'Demierre', 'https://applications.unil.ch/intra/auth/php/Sy/SyPerInfo.php?PerNum=1279608');

-- Insert keywords
INSERT INTO keyword (keyword) VALUES ('gitlab'),
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
 ('support');

-- Insert links and their relationships
-- Applications métiers
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://gitlab-bcul.unil.ch', 'Gitlab', 'Le Gitlab de la BCUL', 'https://docs.gitlab.com/', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (1, 1);
INSERT INTO links_views (link_id, view_id) VALUES (1, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 32);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 31);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 30);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 29);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 28);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 18);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 19);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (1, 20);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://appm-bookstack.prduks-bcul-ci4881-limited.uks.unil.ch/', 'Bookstack', 'Bookstack - Le Wiki de la BCUL', 'https://www.bookstackapp.com/docs/', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (2, 1);
INSERT INTO links_views (link_id, view_id) VALUES (2, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (2, 1);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://itop-bcul.unil.ch/itop', 'Itop', 'iTop - Application d''inventaire', 'https://www.itophub.io/wiki/page', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (3, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (3, 2);
INSERT INTO links_views (link_id, view_id) VALUES (3, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 32);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 31);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 30);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 29);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 28);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 18);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 19);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (3, 20);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://apps-ocsinventory.prduks-bcul-ci4881-limited.uks.unil.ch/ocsreports/', 'OCS Inventory', 'Application d''inventaire des laptops', 'https://wiki.ocsinventory-ng.org/', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (4, 1);
INSERT INTO links_views (link_id, view_id) VALUES (4, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (4, 20);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://portal.uks.unil.ch/dashboard/auth/printin?timed-out', 'UKS Portal', 'Portail de gestion des pods Kubernetes', 'https://rancher.com/docs/', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (5, 1);
INSERT INTO links_views (link_id, view_id) VALUES (5, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (5, 17);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://apps-passbolt.prduks-bcul-ci4881-limited.uks.unil.ch/app/passwords', 'Passbolt', 'Gestionnaire de mots de passe BCUL', 'https://www.passbolt.com/docs/', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (6, 1);
INSERT INTO links_views (link_id, view_id) VALUES (6, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (6, 18);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://helpdesk.unil.ch/otobo', 'Otobo', 'Interface de gestion des tickets', 'https://doc.otobo.org/', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (7, 1);
INSERT INTO links_views (link_id, view_id) VALUES (7, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (7, 33);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (7, 18);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://discord.gg/6VwfW3j6r4', 'Discord', 'Lien vers le serveur Discord du service.', 'https://discord.com/developers/docs/intro', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (8, 1);
INSERT INTO links_views (link_id, view_id) VALUES (8, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (8, 1);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/RESSOURCE-INF/itop-inventory/index.php', 'Application Inventaire', 'Application de scan d''inventaire connectée à iTop', 'https://google.com', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (9, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (9, 2);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (9, 3);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (9, 4);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (9, 5);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (9, 6);
INSERT INTO links_views (link_id, view_id) VALUES (9, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 32);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 31);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 30);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 29);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 28);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 18);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 19);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (9, 20);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://ephoto-bcul.unil.ch', 'E-photo', 'Application e-photo de stockage de photos', '', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (10, 1);
INSERT INTO links_views (link_id, view_id) VALUES (10, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (10, 21);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://printunil-uniflow.unil.ch/pwbudget/', 'Uniflow', 'Application de gestion des crédits d''impression printunil sur les campus card', '', 1, 1);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (11, 1);
INSERT INTO links_views (link_id, view_id) VALUES (11, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (11, 22);

-- Monitoring
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://apps-grafana.prduks-bcul-ci4881-limited.uks.unil.ch/printin', 'Grafana BCUL', 'Monitoring Grafana de la BCUL', 'https://grafana.com/docs/', 1, 2);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (12, 1);
INSERT INTO links_views (link_id, view_id) VALUES (12, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (12, 13);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://status-bcul.unil.ch/', 'Cachet - Application de statuts des serveurs BCUL', 'Application permettant la vérification des status serveur.', '', 1, 2);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (13, 1);
INSERT INTO links_views (link_id, view_id) VALUES (13, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (13, 2);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://tenable-sc.unil.ch/', 'Tenable - Surveillance des vulnérabilités (SOC)', 'SOC de surveillance des vulnérabilités des serveurs.', 'https://docs.tenable.com/', 1, 2);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (14, 1);
INSERT INTO links_views (link_id, view_id) VALUES (14, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (14, 23);

-- Serveurs Web
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webext-apache.prduks-bcul-ci4881.uks.unil.ch/', 'Externe', 'Serveur Web Externe', '', 1, 3);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (15, 1);
INSERT INTO links_views (link_id, view_id) VALUES (15, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (15, 10);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/', 'Interne', 'Serveur Web Interne', '', 1, 3);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (16, 1);
INSERT INTO links_views (link_id, view_id) VALUES (16, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (16, 10);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/index-it.html', 'IT', 'Serveur Web Interne du service IT', '', 1, 3);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (17, 1);
INSERT INTO links_views (link_id, view_id) VALUES (17, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (17, 10);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webtest-apache.prduks-bcul-ci4881-limited.uks.unil.ch/', 'Test', 'Serveur Web Test', '', 1, 3);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (18, 1);
INSERT INTO links_views (link_id, view_id) VALUES (18, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (18, 10);

-- Virtualisation - BCUL
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://vcsa-vdi-bcul.unil.ch/', 'VCSA VDI', 'VCSA VDI', 'https://docs.vmware.com/en/VMware-vSphere/index.html', 1, 4);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (19, 1);
INSERT INTO links_views (link_id, view_id) VALUES (19, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (19, 12);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://vcsa-prd-bcul.unil.ch/', 'VCSA PRD', 'VCSA PRD', 'https://docs.vmware.com/en/VMware-vSphere/index.html', 1, 4);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (20, 1);
INSERT INTO links_views (link_id, view_id) VALUES (20, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (20, 12);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://vco-bcul.unil.ch/admin/', 'VCO BCUL', 'VCO BCUL', 'https://docs.vmware.com/fr/VMware-SD-WAN/index.html', 1, 4);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (21, 1);
INSERT INTO links_views (link_id, view_id) VALUES (21, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (21, 12);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://av-bcul.unil.ch/printin', 'App Volumes', 'App Volumes', 'https://docs.vmware.com/en/VMware-App-Volumes/index.html', 1, 4);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (22, 1);
INSERT INTO links_views (link_id, view_id) VALUES (22, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (22, 12);

-- Formulaires BCUL
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/FORMS/informatique/Formulaire-pret.html', 'BCUL - Formulaire de prêt', 'Formulaire de prêt de matériel', '', 1, 5);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (23, 1);
INSERT INTO links_views (link_id, view_id) VALUES (23, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (23, 4);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webext-apache.prduks-bcul-ci4881.uks.unil.ch/FORMS/manuscrits/Formulaire-manuscrit.html', 'Manuscrits - Demande de consultation', 'Formulaire de demande de consultation de manuscrits', '', 1, 5);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (24, 1);
INSERT INTO links_views (link_id, view_id) VALUES (24, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (24, 4);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/FORMS/informatique/Formulaire-entree.html', 'RH - Entrée d''un collaborateur', 'Formulaire d''entrée d''un collaborateur', '', 1, 5);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (25, 1);
INSERT INTO links_views (link_id, view_id) VALUES (25, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (25, 4);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/FORMS/informatique/Formulaire-sortie.html', 'RH - Sortie d''un collaborateur', 'Formulaire de sortie d''un collaborateur', '', 1, 5);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (26, 1);
INSERT INTO links_views (link_id, view_id) VALUES (26, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (26, 4);

-- Formulaires BCUL (continued)
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/FORMS/informatique/Formulaire-prolongation.html', 'RH - Prolongation d''un collaborateur', 'Formulaire de prolongation d''un collaborateur', '', 1, 5);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (27, 1);
INSERT INTO links_views (link_id, view_id) VALUES (27, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (27, 4);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://webint-apache.prduks-bcul-ci4881-limited.uks.unil.ch/FORMS/rh/Formulaire-accident.html', 'RH - Déclaration d''accident', 'Formulaire de déclaration d''accident', '', 1, 5);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (28, 1);
INSERT INTO links_views (link_id, view_id) VALUES (28, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (28, 4);

-- Formulaires UNIL
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www2.unil.ch/dbcm-adm/SiteFormulaires/cde_materiel_UNIL2018.pdf', 'Formulaire achats UNIL', 'Formulaire à remplir pour les demandes d''achats à l''UNIL', '', 1, 6);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (29, 1);
INSERT INTO links_views (link_id, view_id) VALUES (29, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (29, 4);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://unil.ch/ci/id', 'Compte informatique UNIL', 'Toutes les opérations concernant les comptes informatiques', '', 1, 6);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (30, 1);
INSERT INTO links_views (link_id, view_id) VALUES (30, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (30, 4);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www2.unil.ch/ci/forms_otrs/comptes/acces_intranet/acces_intranet.php', 'Accès intranet UNIL', 'Formulaire de demande d''accès à l''Intranet UNIL', '', 1, 6);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (31, 1);
INSERT INTO links_views (link_id, view_id) VALUES (31, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (31, 4);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www2.unil.ch/ci/forms_otrs/reseau/request.php', 'Formulaire de demande de réseau de l''UNIL', 'Formulaire de demande de réseau de l''UNIL', '', 1, 6);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (32, 1);
INSERT INTO links_views (link_id, view_id) VALUES (32, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (32, 4);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.unil.ch/ci/voip', 'Activation téléphonie Teams', 'Permet d''activer la téléphonie sur Teams', '', 1, 6);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (33, 1);
INSERT INTO links_views (link_id, view_id) VALUES (33, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (33, 7);

-- Administration
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('http://jbm6-bcul.ad.unil.ch/workflow/default.aspx?tick=988', 'JBM Workflow', 'Application JBM Workflow permettant de noter les heures effectuées', '', 1, 7);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (34, 1);
INSERT INTO links_views (link_id, view_id) VALUES (34, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (34, 5);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://applications.unil.ch/intra/auth/php/Sy/SyMenu.php', 'Intranet UNIL', 'Accès à Sylvia - l''Intranet de l''UNIL', '', 1, 7);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (35, 1);
INSERT INTO links_views (link_id, view_id) VALUES (35, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (35, 5);

-- Lorawan
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('http://lorawan01.unil.ch:3000/printin', 'Dashboard Grafana Lorawan', 'Dashboard de monitoring des sondes Lorawan', 'https://grafana.com/docs/', 1, 8);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (36, 1);
INSERT INTO links_views (link_id, view_id) VALUES (36, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (36, 13);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('http://lorawan01.unil.ch:8086/signin', 'Base de données influxDB', 'Base de données des sondes Lorawan', 'https://docs.influxdata.com/influxdb/v2/', 1, 8);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (37, 1);
INSERT INTO links_views (link_id, view_id) VALUES (37, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (37, 24);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('http://lorawan01.unil.ch:8080/#/printin', 'Gateway des antennes Lorawan', 'Gateway de gestion des sondes Lorawan', 'https://www.chirpstack.io/docs/', 1, 8);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (38, 1);
INSERT INTO links_views (link_id, view_id) VALUES (38, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (38, 25);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://crypto.unil.ch/secubat', 'EXTUNI Gestion MCR Unibat', 'EXTUNI Gestion MCR Unibat', '', 1, 8);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (39, 1);
INSERT INTO links_views (link_id, view_id) VALUES (39, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (39, 5);

-- Virtualisation - UNIL
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://xaas-di.vra.unil.ch/', 'Gestion des VM Ci UNIL (XaaS)', 'L''application Aria permet de simplifier et d''automatiser la gestion du cycle de vie des machines virtuelles (VM). Notamment sur le provisionnement et sur les opérations de gestion.', 'https://wiki.unil.ch/ci/books/hebergement-de-machines-virtuelles-vm-hors-recherche/chapter/doc-publique', 1, 9);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (40, 1);
INSERT INTO links_views (link_id, view_id) VALUES (40, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (40, 12);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://vcsa.unil.ch', 'Gestion des VM Ci UNIL (VCSA)', 'VSCA UNIL', 'https://docs.vmware.com/en/VMware-vSphere/index.html', 1, 9);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (41, 1);
INSERT INTO links_views (link_id, view_id) VALUES (41, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (41, 12);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://prdvdiu-vcsa02.unil.ch/', 'vSphere VDI UNIL', 'vSphere VDI UNIL', 'https://docs.vmware.com/fr/VMware-vSphere/index.html', 1, 9);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (42, 1);
INSERT INTO links_views (link_id, view_id) VALUES (42, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (42, 12);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://vdiu-srvco-max.unil.ch/admin/#/printin', 'VMWare Horizon UNIL', 'VMWare Horizon UNIL', '', 1, 9);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (43, 1);
INSERT INTO links_views (link_id, view_id) VALUES (43, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (43, 12);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://cohesity01.unil.ch/', 'Cohesity', 'Restauration de fichiers et de VM UNIL', 'https://docs.cohesity.com/ui/', 1, 9);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (44, 1);
INSERT INTO links_views (link_id, view_id) VALUES (44, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (44, 26);

-- Mail
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://sympa.unil.ch/sympa/home', 'Listes de diffusion', 'Listes de diffusion de l''UNIL', '', 1, 10);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (45, 1);
INSERT INTO links_views (link_id, view_id) VALUES (45, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (45, 27);

-- Réseau
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://web-auth.unil.ch/', 'Authentification Firewall UNIL', 'Permet de s''authentifier sur le firewall de l''UNIL et de se connecter sur leur différents services', '', 1, 11);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (46, 1);
INSERT INTO links_views (link_id, view_id) VALUES (46, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (46, 14);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.unil.ch/ci/home/menuinst/cataprintue-de-services/reseau-et-telephonie/firewall-as-a-service/acceder-au-service.html', 'Règles Firewall (FaaS)', 'Ajout, suppression et modification de règles pour le Firewall de l''UNIL', '', 1, 11);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (47, 1);
INSERT INTO links_views (link_id, view_id) VALUES (47, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (47, 14);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.unil.ch/ci/fr/home/menuinst/cataprintue-de-services/reseau-et-telephonie/demande-d-ip-fixe.html', 'Demande d''IP fixe et DNS', 'Pour effectuer une demande d''IP fixe et/ou de DNS pour un serveur/PC/VM', '', 1, 11);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (48, 1);
INSERT INTO links_views (link_id, view_id) VALUES (48, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (48, 15);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www2.unil.ch/ci/reseau/hosts_unil.arp', 'Adresses IP UNIL (ARP)', 'Table ARP regroupant toutes les adresses IP de l''UNIL (et les réseaux).', 'https://en.wikipedia.org/wiki/Address_Resolution_Protocol', 1, 11);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (49, 1);
INSERT INTO links_views (link_id, view_id) VALUES (49, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (49, 16);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://apps-unificheck.prduks-bcul-ci4881-limited.uks.unil.ch/', 'Portail Unifi', 'Portail Unifi vers les devices unifi des différents sites BCUL', 'https://help.ui.com/hc/en-us/categories/6583256751383-UniFi', 1, 11);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (50, 1);
INSERT INTO links_views (link_id, view_id) VALUES (50, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (50, 14);

-- Téléphonie
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.unil.ch/ci/fr/home/menuinst/cataprintue-de-services/reseau-et-telephonie.html', 'Formulaires UNIL de téléphonie', 'Formulaires diverses concernant la téléphonie à l''UNIL', '', 1, 12);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (51, 1);
INSERT INTO links_views (link_id, view_id) VALUES (51, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (51, 7);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://annuaire.unil.ch/', 'Annuaire UNIL', 'Annuaire de l''UNIL', '', 1, 12);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (52, 1);
INSERT INTO links_views (link_id, view_id) VALUES (52, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (52, 28);

-- Formations
INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.eni-training.com/instant-Connection/Default.aspx?WSLogin=TmRu6E1WYa1IEiTDUTLXrg%3D%3D&WSPwd=m3OjUZGox9AfMGCblpkA6g%3D%3D&IdDomain=239&IdGroup=168078', 'eni-training', 'Plateforme de formation Eni-training', '', 1, 13);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (53, 1);
INSERT INTO links_views (link_id, view_id) VALUES (53, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (53, 8);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.pressreader.com/', 'Pressreader', 'Plateforme de cataprintue de journaux Pressreader', '', 1, 13);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (54, 1);
INSERT INTO links_views (link_id, view_id) VALUES (54, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (54, 8);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.elephorm.com/', 'Elephorm', 'Plateforme de formation Elephorm', '', 1, 13);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (55, 1);
INSERT INTO links_views (link_id, view_id) VALUES (55, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (55, 8);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.alphorm.com/', 'Alphorm', 'Plateforme de formation Alphorm', '', 1, 13);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (56, 1);
INSERT INTO links_views (link_id, view_id) VALUES (56, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (56, 24);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://www.packtpub.com/', 'Packtpub', 'Plateforme de formation Packtpub', '', 1, 13);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (57, 2);
INSERT INTO links_views (link_id, view_id) VALUES (57, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (57, 24);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://m3.material.io/', 'Material - Web design', 'Système de Web Design créé par Google.', '', 1, 14);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (58, 3);
INSERT INTO links_views (link_id, view_id) VALUES (58, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (58, 25);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://store.rg-adguard.net/', 'Microsoft Store bypass', 'Lien permettant de télécharger des applications du Microsoft Store sans passer par celui-ci', '', 1, 14);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (59, 4);
INSERT INTO links_views (link_id, view_id) VALUES (59, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (59, 25);

INSERT INTO link (link, title, description, doc_link, status_id, category_id) VALUES ('https://planete.unil.ch/', 'Planete UNIL', 'Plans de l''UNIL', '', 1, 14);
INSERT INTO link_managers_links (link_id, manager_id) VALUES (60, 1);
INSERT INTO links_views (link_id, view_id) VALUES (60, 1);
INSERT INTO keywords_links (link_id, keyword_id) VALUES (60, 25);
'''
      ];
      for (final sql in mockData) {
        _db.execute(sql);
      }
    } catch (e) {
      rethrow;
    }
  }

  PreparedStatement _prepareGetCategoriesStatement() {
    return _db.prepare('''
    WITH LinkData AS (
      -- Use a simpler subquery for better SQLite performance
      SELECT 
        link.*,
        s.name as status_name,
        (
          SELECT json_group_array(json_object(
            'id', k.id, 'keyword', k.keyword
          ))
          FROM keywords_links kl
          JOIN keyword k ON k.id = kl.keyword_id
          WHERE kl.link_id = link.id
        ) as keywords,
        (
          SELECT json_group_array(json_object(
            'id', v.id, 'name', v.name
          ))
          FROM links_views lv
          JOIN view v ON v.id = lv.view_id
          WHERE lv.link_id = link.id
        ) as views,
        (
          SELECT json_group_array(json_object(
            'id', m.id, 'name', m.name, 'surname', m.surname, 'link', m.link
          ))
          FROM link_managers_links lm
          JOIN link_manager m ON m.id = lm.manager_id
          WHERE lm.link_id = link.id
        ) as managers,
        EXISTS (
          SELECT 1 
          FROM links_views lv2
          JOIN view v2 ON v2.id = lv2.view_id
          WHERE lv2.link_id = link.id 
          AND v2.name IN (${List.filled(99, '?').join(',')})
        ) as has_access
      FROM link
      LEFT JOIN status s ON s.id = link.status_id
    )
    SELECT 
      c.id as category_id,
      c.name as category_name,
      json_group_array(
        CASE 
          WHEN ld.has_access = 1 THEN
            json_object(
              'id', ld.id,
              'link', ld.link,
              'title', ld.title,
              'description', ld.description,
              'doc_link', ld.doc_link,
              'status_id', ld.status_id,
              'status_name', ld.status_name,
              'keywords', ld.keywords,
              'views', ld.views,
              'managers', ld.managers
            )
          ELSE NULL
        END
      ) as links
    FROM categories c
    LEFT JOIN LinkData ld ON c.id = ld.category_id
    GROUP BY c.id
  ''');
  }
}

class CacheEntry<T> {
  final T data;
  final DateTime expiry;

  CacheEntry(this.data, Duration ttl) : expiry = DateTime.now().add(ttl);

  bool get isValid => DateTime.now().isBefore(expiry);
}
