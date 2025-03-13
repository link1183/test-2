import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';

/// Data model for View (user group with access to links)
class View {
  final int? id;
  final String name;

  View({this.id, required this.name});

  /// Creates a view from a database row
  factory View.fromMap(Map<String, dynamic> map) {
    return View(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  /// Creates a copy of this view with optional overrides
  View copyWith({int? id, String? name}) {
    return View(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
    };
  }

  /// Converts this view to a database row
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
    };
  }
}

/// Service for managing views (user groups with access to links)
class ViewService {
  final DatabaseConnectionPool _connectionPool;
  final Logger _logger = LoggerFactory.getLogger('ViewService');

  ViewService(this._connectionPool);

  /// Creates a new view
  Future<int> createView(String name) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw ArgumentError('View name cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if a view with this name already exists
        final existingViews = await connection.database.query(
          'SELECT id FROM view WHERE name = ?',
          [name],
        );

        if (existingViews.isNotEmpty) {
          throw ConstraintException('A view with this name already exists');
        }

        // Insert the view
        final id = await connection.database.insert('view', {'name': name});

        _logger.info('Created new view', {'id': id, 'name': name});
        return id;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException || e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to create view', e, stackTrace);
      throw DatabaseException('Failed to create view', e, stackTrace);
    }
  }

  /// Deletes a view by ID
  Future<bool> deleteView(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        // Check if the view exists
        final viewExists = await connection.database.query(
          'SELECT 1 FROM view WHERE id = ?',
          [id],
        );

        if (viewExists.isEmpty) {
          _logger.warning('View not found for deletion', {'id': id});
          return false;
        }

        // Check if there are any links using this view
        final linkedLinks = await connection.database.query(
          'SELECT COUNT(*) as count FROM links_views WHERE view_id = ?',
          [id],
        );

        final linkCount = linkedLinks.first['count'] as int;
        if (linkCount > 0) {
          throw ConstraintException(
            'Cannot delete view: it is used by $linkCount links',
          );
        }

        // Start a transaction
        await connection.database.beginTransaction();

        try {
          // Delete the view
          await connection.database.delete(
            'view',
            where: 'id = ?',
            whereArgs: [id],
          );

          await connection.database.commitTransaction();

          _logger.info('Deleted view', {'id': id});
          return true;
        } catch (e) {
          await connection.database.rollbackTransaction();
          rethrow;
        }
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to delete view', e, stackTrace);
      throw DatabaseException(
          'Failed to delete view: ${e.toString()}', e, stackTrace);
    }
  }

  /// Gets all views
  Future<List<View>> getAllViews() async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, name FROM view ORDER BY name',
        );

        return results.map((row) => View.fromMap(row)).toList();
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get all views', e, stackTrace);
      throw DatabaseException('Failed to retrieve views', e, stackTrace);
    }
  }

  /// Gets all links associated with a view
  Future<List<Map<String, dynamic>>> getLinksByViewId(int viewId) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query('''
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

        return results;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error(
          'Failed to get links by view ID', e, stackTrace, {'viewId': viewId});
      throw DatabaseException(
          'Failed to retrieve links for view', e, stackTrace);
    }
  }

  /// Gets a view by ID
  Future<View?> getViewById(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, name FROM view WHERE id = ?',
          [id],
        );

        if (results.isEmpty) {
          return null;
        }

        return View.fromMap(results.first);
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get view by ID', e, stackTrace);
      throw DatabaseException('Failed to retrieve view', e, stackTrace);
    }
  }

  /// Updates a view
  Future<bool> updateView(int id, String name) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw ArgumentError('View name cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if the view exists
        final viewExists = await connection.database.query(
          'SELECT 1 FROM view WHERE id = ?',
          [id],
        );

        if (viewExists.isEmpty) {
          _logger.warning('View not found for update', {'id': id});
          return false;
        }

        // Check if another view with this name already exists
        final existingView = await connection.database.query(
          'SELECT id FROM view WHERE name = ? AND id != ?',
          [name, id],
        );

        if (existingView.isNotEmpty) {
          throw ConstraintException(
              'Another view with this name already exists');
        }

        // Update the view
        await connection.database.update(
          'view',
          {'name': name},
          where: 'id = ?',
          whereArgs: [id],
        );

        _logger.info('Updated view', {'id': id, 'name': name});
        return true;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException || e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to update view', e, stackTrace);
      throw DatabaseException(
          'Failed to update view: ${e.toString()}', e, stackTrace);
    }
  }
}
