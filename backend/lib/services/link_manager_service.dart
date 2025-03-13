import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';

/// Data model for LinkManager
class LinkManager {
  final int? id;
  final String name;
  final String surname;
  final String? link;

  LinkManager({
    this.id,
    required this.name,
    required this.surname,
    this.link,
  });

  /// Creates a link manager from a database row
  factory LinkManager.fromMap(Map<String, dynamic> map) {
    return LinkManager(
      id: map['id'] as int,
      name: map['name'] as String,
      surname: map['surname'] as String,
      link: map['link'] as String?,
    );
  }

  /// Gets the full name of the link manager
  String get fullName => '$name $surname';

  /// Creates a copy of this link manager with optional overrides
  LinkManager copyWith({
    int? id,
    String? name,
    String? surname,
    String? link,
  }) {
    return LinkManager(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      link: link ?? this.link,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'surname': surname,
      'link': link,
    };
  }

  /// Converts this link manager to a database row
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'surname': surname,
      'link': link,
    };
  }
}

/// Service for managing link managers (people associated with links)
class LinkManagerService {
  final DatabaseConnectionPool _connectionPool;
  final Logger _logger = LoggerFactory.getLogger('LinkManagerService');

  LinkManagerService(this._connectionPool);

  /// Creates a new link manager
  Future<int> createLinkManager(
      String name, String surname, String? link) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw ArgumentError('Link manager name cannot be empty');
      }

      if (surname.trim().isEmpty) {
        throw ArgumentError('Link manager surname cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Insert the link manager
        final id = await connection.database.insert('link_manager', {
          'name': name,
          'surname': surname,
          'link': link ?? '',
        });

        _logger.info('Created new link manager',
            {'id': id, 'name': name, 'surname': surname});

        return id;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to create link manager', e, stackTrace);
      throw DatabaseException('Failed to create link manager', e, stackTrace);
    }
  }

  /// Deletes a link manager by ID
  Future<bool> deleteLinkManager(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        // Check if the link manager exists
        final managerExists = await connection.database.query(
          'SELECT 1 FROM link_manager WHERE id = ?',
          [id],
        );

        if (managerExists.isEmpty) {
          _logger.warning('Link manager not found for deletion', {'id': id});
          return false;
        }

        // Check if there are any links using this link manager
        final linkedLinks = await connection.database.query(
          'SELECT COUNT(*) as count FROM link_managers_links WHERE manager_id = ?',
          [id],
        );

        final linkCount = linkedLinks.first['count'] as int;
        if (linkCount > 0) {
          throw ConstraintException(
            'Cannot delete link manager: it is associated with $linkCount links',
          );
        }

        // Start a transaction
        await connection.database.beginTransaction();

        try {
          // Delete the link manager
          await connection.database.delete(
            'link_manager',
            where: 'id = ?',
            whereArgs: [id],
          );

          await connection.database.commitTransaction();

          _logger.info('Deleted link manager', {'id': id});
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

      _logger.error('Failed to delete link manager', e, stackTrace);
      throw DatabaseException(
          'Failed to delete link manager: ${e.toString()}', e, stackTrace);
    }
  }

  /// Gets all link managers
  Future<List<LinkManager>> getAllLinkManagers() async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, name, surname, link FROM link_manager ORDER BY surname, name',
        );

        return results.map((row) => LinkManager.fromMap(row)).toList();
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get all link managers', e, stackTrace);
      throw DatabaseException(
          'Failed to retrieve link managers', e, stackTrace);
    }
  }

  /// Gets a link manager by ID
  Future<LinkManager?> getLinkManagerById(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, name, surname, link FROM link_manager WHERE id = ?',
          [id],
        );

        if (results.isEmpty) {
          return null;
        }

        return LinkManager.fromMap(results.first);
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get link manager by ID', e, stackTrace);
      throw DatabaseException('Failed to retrieve link manager', e, stackTrace);
    }
  }

  /// Gets all links associated with a link manager
  Future<List<Map<String, dynamic>>> getLinksByManagerId(int managerId) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query('''
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

        return results;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get links by manager ID', e, stackTrace,
          {'managerId': managerId});
      throw DatabaseException(
          'Failed to retrieve links for manager', e, stackTrace);
    }
  }

  /// Updates a link manager
  Future<bool> updateLinkManager(
    int id, {
    String? name,
    String? surname,
    String? link,
  }) async {
    try {
      // Validate inputs if provided
      if (name != null && name.trim().isEmpty) {
        throw ArgumentError('Link manager name cannot be empty');
      }

      if (surname != null && surname.trim().isEmpty) {
        throw ArgumentError('Link manager surname cannot be empty');
      }

      // Check if there's anything to update
      if (name == null && surname == null && link == null) {
        _logger.warning('No fields to update for link manager', {'id': id});
        return false;
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if the link manager exists
        final managerExists = await connection.database.query(
          'SELECT 1 FROM link_manager WHERE id = ?',
          [id],
        );

        if (managerExists.isEmpty) {
          _logger.warning('Link manager not found for update', {'id': id});
          return false;
        }

        // Prepare update data
        final updateData = <String, dynamic>{};
        if (name != null) updateData['name'] = name;
        if (surname != null) updateData['surname'] = surname;
        if (link != null) updateData['link'] = link;

        // Update the link manager
        await connection.database.update(
          'link_manager',
          updateData,
          where: 'id = ?',
          whereArgs: [id],
        );

        _logger.info('Updated link manager', {
          'id': id,
          'fields': updateData.keys.join(', '),
        });

        return true;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to update link manager', e, stackTrace);
      throw DatabaseException(
          'Failed to update link manager: ${e.toString()}', e, stackTrace);
    }
  }
}
