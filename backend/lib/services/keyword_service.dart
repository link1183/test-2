import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';

/// Data model for Keyword
class Keyword {
  final int? id;
  final String keyword;

  Keyword({this.id, required this.keyword});

  /// Creates a keyword from a database row
  factory Keyword.fromMap(Map<String, dynamic> map) {
    return Keyword(
      id: map['id'] as int,
      keyword: map['keyword'] as String,
    );
  }

  /// Creates a copy of this keyword with optional overrides
  Keyword copyWith({int? id, String? keyword}) {
    return Keyword(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'keyword': keyword,
    };
  }

  /// Converts this keyword to a database row
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'keyword': keyword,
    };
  }
}

/// Service for managing keywords
class KeywordService {
  final DatabaseConnectionPool _connectionPool;
  final Logger _logger = LoggerFactory.getLogger('KeywordService');

  KeywordService(this._connectionPool);

  /// Creates a new keyword
  Future<int> createKeyword(String keyword) async {
    try {
      // Validate inputs
      if (keyword.trim().isEmpty) {
        throw ArgumentError('Keyword cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if a keyword with this name already exists
        final existingKeywords = await connection.database.query(
          'SELECT id FROM keyword WHERE keyword = ?',
          [keyword],
        );

        if (existingKeywords.isNotEmpty) {
          return -1;
        }

        // Insert the keyword
        final id =
            await connection.database.insert('keyword', {'keyword': keyword});

        _logger.info('Created new keyword', {'id': id, 'keyword': keyword});
        return id;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to create keyword', e, stackTrace);
      throw DatabaseException('Failed to create keyword', e, stackTrace);
    }
  }

  /// Deletes a keyword by ID
  Future<bool> deleteKeyword(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        // Check if the keyword exists
        final keywordExists = await connection.database.query(
          'SELECT 1 FROM keyword WHERE id = ?',
          [id],
        );

        if (keywordExists.isEmpty) {
          _logger.warning('Keyword not found for deletion', {'id': id});
          return false;
        }

        // Check if there are any links using this keyword
        final linkedLinks = await connection.database.query(
          'SELECT COUNT(*) as count FROM keywords_links WHERE keyword_id = ?',
          [id],
        );

        final linkCount = linkedLinks.first['count'] as int;
        if (linkCount > 0) {
          throw ConstraintException(
            'Cannot delete keyword: it is used by $linkCount links',
          );
        }

        // Start a transaction
        await connection.database.beginTransaction();

        try {
          // Delete the keyword
          await connection.database.delete(
            'keyword',
            where: 'id = ?',
            whereArgs: [id],
          );

          await connection.database.commitTransaction();

          _logger.info('Deleted keyword', {'id': id});
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

      _logger.error('Failed to delete keyword', e, stackTrace);
      throw DatabaseException(
          'Failed to delete keyword: ${e.toString()}', e, stackTrace);
    }
  }

  /// Gets all keywords
  Future<List<Keyword>> getAllKeywords() async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, keyword FROM keyword ORDER BY keyword',
        );

        return results.map((row) => Keyword.fromMap(row)).toList();
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get all keywords', e, stackTrace);
      throw DatabaseException('Failed to retrieve keywords', e, stackTrace);
    }
  }

  /// Gets a keyword by ID
  Future<Keyword?> getKeywordById(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, keyword FROM keyword WHERE id = ?',
          [id],
        );

        if (results.isEmpty) {
          return null;
        }

        return Keyword.fromMap(results.first);
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get keyword by ID', e, stackTrace);
      throw DatabaseException('Failed to retrieve keyword', e, stackTrace);
    }
  }

  /// Gets all links associated with a keyword
  Future<List<Map<String, dynamic>>> getLinksByKeywordId(int keywordId) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query('''
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

        return results;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get links by keyword ID', e, stackTrace,
          {'keywordId': keywordId});
      throw DatabaseException(
          'Failed to retrieve links for keyword', e, stackTrace);
    }
  }

  /// Updates a keyword
  Future<bool> updateKeyword(int id, String keyword) async {
    try {
      // Trim and normalize the keyword
      keyword = keyword.trim();

      // Validate inputs
      if (keyword.isEmpty) {
        throw ArgumentError('Keyword cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if the keyword exists
        final keywordExists = await connection.database.query(
          'SELECT 1 FROM keyword WHERE id = ?',
          [id],
        );

        if (keywordExists.isEmpty) {
          _logger.warning('Keyword not found for update', {'id': id});
          return false;
        }

        // Check if another keyword with this name already exists (case-insensitive)
        final existingKeyword = await connection.database.query(
          'SELECT id FROM keyword WHERE LOWER(keyword) = LOWER(?) AND id != ?',
          [keyword, id],
        );

        if (existingKeyword.isNotEmpty) {
          return false;
        }

        await connection.database.update(
          'keyword',
          {'keyword': keyword},
          where: 'id = ?',
          whereArgs: [id],
        );

        _logger.info('Updated keyword', {'id': id, 'keyword': keyword});
        return true;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to update keyword', e, stackTrace);
      throw DatabaseException(
          'Failed to update keyword: ${e.toString()}', e, stackTrace);
    }
  }
}
