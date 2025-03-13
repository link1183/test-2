import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/utils/logger.dart';

/// Data model for Link
class Link {
  final int? id;
  final String link;
  final String title;
  final String description;
  final String? docLink;
  final int statusId;
  final int categoryId;
  final String? statusName;
  final String? categoryName;
  final List<Map<String, dynamic>>? views;
  final List<Map<String, dynamic>>? keywords;
  final List<Map<String, dynamic>>? managers;

  Link({
    this.id,
    required this.link,
    required this.title,
    required this.description,
    this.docLink,
    required this.statusId,
    required this.categoryId,
    this.statusName,
    this.categoryName,
    this.views,
    this.keywords,
    this.managers,
  });

  /// Creates a link from a database row
  factory Link.fromMap(Map<String, dynamic> map) {
    return Link(
      id: map['id'] as int,
      link: map['link'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      docLink: map['doc_link'] as String?,
      statusId: map['status_id'] as int,
      categoryId: map['category_id'] as int,
      statusName: map['status_name'] as String?,
      categoryName: map['category_name'] as String?,
      views: map['views'] is List
          ? List<Map<String, dynamic>>.from(map['views'])
          : null,
      keywords: map['keywords'] is List
          ? List<Map<String, dynamic>>.from(map['keywords'])
          : null,
      managers: map['managers'] is List
          ? List<Map<String, dynamic>>.from(map['managers'])
          : null,
    );
  }

  /// Creates a copy of this link with optional overrides
  Link copyWith({
    int? id,
    String? link,
    String? title,
    String? description,
    String? docLink,
    int? statusId,
    int? categoryId,
    String? statusName,
    String? categoryName,
    List<Map<String, dynamic>>? views,
    List<Map<String, dynamic>>? keywords,
    List<Map<String, dynamic>>? managers,
  }) {
    return Link(
      id: id ?? this.id,
      link: link ?? this.link,
      title: title ?? this.title,
      description: description ?? this.description,
      docLink: docLink ?? this.docLink,
      statusId: statusId ?? this.statusId,
      categoryId: categoryId ?? this.categoryId,
      statusName: statusName ?? this.statusName,
      categoryName: categoryName ?? this.categoryName,
      views: views ?? this.views,
      keywords: keywords ?? this.keywords,
      managers: managers ?? this.managers,
    );
  }

  /// Converts this link to a database row
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'link': link,
      'title': title,
      'description': description,
      'doc_link': docLink,
      'status_id': statusId,
      'category_id': categoryId,
    };
  }
}

/// Service for managing links
class LinkService {
  final DatabaseConnectionPool _connectionPool;
  final Logger _logger = LoggerFactory.getLogger('LinkService');

  LinkService(this._connectionPool);

  /// Creates a new link with associated entities
  Future<int> createLink({
    required String link,
    required String title,
    required String description,
    String? docLink,
    required int statusId,
    required int categoryId,
    List<int>? viewIds,
    List<int>? keywordIds,
    List<int>? managerIds,
  }) async {
    try {
      // Validate inputs
      if (link.trim().isEmpty) {
        throw ArgumentError('Link URL cannot be empty');
      }

      if (!InputSanitizer.isValidUrl(link)) {
        throw ArgumentError('Invalid URL format');
      }

      if (title.trim().isEmpty) {
        throw ArgumentError('Link title cannot be empty');
      }

      if (description.trim().isEmpty) {
        throw ArgumentError('Link description cannot be empty');
      }

      if (docLink != null &&
          docLink.isNotEmpty &&
          !InputSanitizer.isValidUrl(docLink)) {
        throw ArgumentError('Invalid documentation URL format');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if a link with this title already exists
        final existingLinks = await connection.database.query(
          'SELECT id FROM link WHERE title = ?',
          [title],
        );

        if (existingLinks.isNotEmpty) {
          throw ConstraintException('A link with this title already exists');
        }

        // Start a transaction for atomicity
        await connection.database.beginTransaction();

        try {
          // Insert the link
          final id = await connection.database.insert('link', {
            'link': link,
            'title': title,
            'description': description,
            'doc_link': docLink ?? '',
            'status_id': statusId,
            'category_id': categoryId,
          });

          // Insert view relationships
          if (viewIds != null && viewIds.isNotEmpty) {
            for (final viewId in viewIds) {
              await connection.database.insert('links_views', {
                'link_id': id,
                'view_id': viewId,
              });
            }
          }

          // Insert keyword relationships
          if (keywordIds != null && keywordIds.isNotEmpty) {
            for (final keywordId in keywordIds) {
              await connection.database.insert('keywords_links', {
                'link_id': id,
                'keyword_id': keywordId,
              });
            }
          }

          // Insert manager relationships
          if (managerIds != null && managerIds.isNotEmpty) {
            for (final managerId in managerIds) {
              await connection.database.insert('link_managers_links', {
                'link_id': id,
                'manager_id': managerId,
              });
            }
          }

          await connection.database.commitTransaction();

          _logger.info('Created new link', {'id': id, 'title': title});
          return id;
        } catch (e) {
          await connection.database.rollbackTransaction();
          rethrow;
        }
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException || e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to create link', e, stackTrace);
      throw DatabaseException('Failed to create link', e, stackTrace);
    }
  }

  /// Deletes a link by ID
  Future<bool> deleteLink(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        // Check if the link exists
        final linkExists = await connection.database.query(
          'SELECT 1 FROM link WHERE id = ?',
          [id],
        );

        if (linkExists.isEmpty) {
          _logger.warning('Link not found for deletion', {'id': id});
          return false;
        }

        // Start a transaction
        await connection.database.beginTransaction();

        try {
          // Delete related data first (foreign key constraints)
          await connection.database.delete(
            'links_views',
            where: 'link_id = ?',
            whereArgs: [id],
          );

          await connection.database.delete(
            'keywords_links',
            where: 'link_id = ?',
            whereArgs: [id],
          );

          await connection.database.delete(
            'link_managers_links',
            where: 'link_id = ?',
            whereArgs: [id],
          );

          // Delete the link itself
          await connection.database.delete(
            'link',
            where: 'id = ?',
            whereArgs: [id],
          );

          await connection.database.commitTransaction();

          _logger.info('Deleted link', {'id': id});
          return true;
        } catch (e) {
          await connection.database.rollbackTransaction();
          rethrow;
        }
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to delete link', e, stackTrace);
      throw DatabaseException(
          'Failed to delete link: ${e.toString()}', e, stackTrace);
    }
  }

  /// Gets all links
  Future<List<Link>> getAllLinks() async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query('''
          SELECT 
            l.id, l.link, l.title, l.description, l.doc_link, 
            l.status_id, s.name as status_name,
            l.category_id, c.name as category_name
          FROM link l
          LEFT JOIN status s ON s.id = l.status_id
          LEFT JOIN categories c ON c.id = l.category_id
          ORDER BY l.title
        ''');

        final links = <Link>[];

        for (final row in results) {
          final linkId = row['id'] as int;

          // Get views for this link
          final views = await connection.database.query('''
            SELECT v.id, v.name
            FROM links_views lv
            JOIN view v ON v.id = lv.view_id
            WHERE lv.link_id = ?
          ''', [linkId]);

          // Get keywords for this link
          final keywords = await connection.database.query('''
            SELECT k.id, k.keyword
            FROM keywords_links kl
            JOIN keyword k ON k.id = kl.keyword_id
            WHERE kl.link_id = ?
          ''', [linkId]);

          // Get managers for this link
          final managers = await connection.database.query('''
            SELECT m.id, m.name, m.surname, m.link
            FROM link_managers_links lm
            JOIN link_manager m ON m.id = lm.manager_id
            WHERE lm.link_id = ?
          ''', [linkId]);

          // Create the link with related entities
          final link = Link.fromMap({
            ...row,
            'views': views,
            'keywords': keywords,
            'managers': managers,
          });

          links.add(link);
        }

        return links;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get all links', e, stackTrace);
      throw DatabaseException('Failed to retrieve links', e, stackTrace);
    }
  }

  /// Gets a link by ID with all related entities
  Future<Link?> getLinkById(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query('''
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

        final row = results.first;

        // Get views for this link
        final views = await connection.database.query('''
          SELECT v.id, v.name
          FROM links_views lv
          JOIN view v ON v.id = lv.view_id
          WHERE lv.link_id = ?
        ''', [id]);

        // Get keywords for this link
        final keywords = await connection.database.query('''
          SELECT k.id, k.keyword
          FROM keywords_links kl
          JOIN keyword k ON k.id = kl.keyword_id
          WHERE kl.link_id = ?
        ''', [id]);

        // Get managers for this link
        final managers = await connection.database.query('''
          SELECT m.id, m.name, m.surname, m.link
          FROM link_managers_links lm
          JOIN link_manager m ON m.id = lm.manager_id
          WHERE lm.link_id = ?
        ''', [id]);

        // Create the link with related entities
        return Link.fromMap({
          ...row,
          'views': views,
          'keywords': keywords,
          'managers': managers,
        });
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get link by ID', e, stackTrace);
      throw DatabaseException('Failed to retrieve link', e, stackTrace);
    }
  }

  /// Gets all links for a specific category
  Future<List<Link>> getLinksByCategory(int categoryId) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query('''
          SELECT 
            l.id, l.link, l.title, l.description, l.doc_link, 
            l.status_id, s.name as status_name,
            l.category_id, c.name as category_name
          FROM link l
          LEFT JOIN status s ON s.id = l.status_id
          LEFT JOIN categories c ON c.id = l.category_id
          WHERE l.category_id = ?
          ORDER BY l.title
        ''', [categoryId]);

        final links = <Link>[];

        for (final row in results) {
          final linkId = row['id'] as int;

          // Get views for this link
          final views = await connection.database.query('''
            SELECT v.id, v.name
            FROM links_views lv
            JOIN view v ON v.id = lv.view_id
            WHERE lv.link_id = ?
          ''', [linkId]);

          // Get keywords for this link
          final keywords = await connection.database.query('''
            SELECT k.id, k.keyword
            FROM keywords_links kl
            JOIN keyword k ON k.id = kl.keyword_id
            WHERE kl.link_id = ?
          ''', [linkId]);

          // Get managers for this link
          final managers = await connection.database.query('''
            SELECT m.id, m.name, m.surname, m.link
            FROM link_managers_links lm
            JOIN link_manager m ON m.id = lm.manager_id
            WHERE lm.link_id = ?
          ''', [linkId]);

          // Create the link with related entities
          final link = Link.fromMap({
            ...row,
            'views': views,
            'keywords': keywords,
            'managers': managers,
          });

          links.add(link);
        }

        return links;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get links by category', e, stackTrace);
      throw DatabaseException(
          'Failed to retrieve links for category', e, stackTrace);
    }
  }

  /// Updates a link by ID
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
      // Validate URL format if provided
      if (link != null && !InputSanitizer.isValidUrl(link)) {
        throw ArgumentError('Invalid URL format');
      }

      // Validate doc_link if provided
      if (docLink != null &&
          docLink.isNotEmpty &&
          !InputSanitizer.isValidUrl(docLink)) {
        throw ArgumentError('Invalid documentation URL format');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if the link exists
        final linkExists = await connection.database.query(
          'SELECT 1 FROM link WHERE id = ?',
          [id],
        );

        if (linkExists.isEmpty) {
          _logger.warning('Link not found for update', {'id': id});
          return false;
        }

        // Check if updating to an existing title
        if (title != null) {
          final existingTitle = await connection.database.query(
            'SELECT id FROM link WHERE title = ? AND id != ?',
            [title, id],
          );

          if (existingTitle.isNotEmpty) {
            throw ConstraintException(
                'Another link with this title already exists');
          }
        }

        // Start a transaction
        await connection.database.beginTransaction();

        try {
          // Prepare update data
          final updateData = <String, dynamic>{};
          if (link != null) updateData['link'] = link;
          if (title != null) updateData['title'] = title;
          if (description != null) updateData['description'] = description;
          if (docLink != null) updateData['doc_link'] = docLink;
          if (statusId != null) updateData['status_id'] = statusId;
          if (categoryId != null) updateData['category_id'] = categoryId;

          // Update the link if we have fields to update
          if (updateData.isNotEmpty) {
            await connection.database.update(
              'link',
              updateData,
              where: 'id = ?',
              whereArgs: [id],
            );
          }

          // Update view relationships if specified
          if (viewIds != null) {
            // Delete existing relationships
            await connection.database.delete(
              'links_views',
              where: 'link_id = ?',
              whereArgs: [id],
            );

            // Insert new relationships
            for (final viewId in viewIds) {
              await connection.database.insert('links_views', {
                'link_id': id,
                'view_id': viewId,
              });
            }
          }

          // Update keyword relationships if specified
          if (keywordIds != null) {
            // Delete existing relationships
            await connection.database.delete(
              'keywords_links',
              where: 'link_id = ?',
              whereArgs: [id],
            );

            // Insert new relationships
            for (final keywordId in keywordIds) {
              await connection.database.insert('keywords_links', {
                'link_id': id,
                'keyword_id': keywordId,
              });
            }
          }

          // Update manager relationships if specified
          if (managerIds != null) {
            // Delete existing relationships
            await connection.database.delete(
              'link_managers_links',
              where: 'link_id = ?',
              whereArgs: [id],
            );

            // Insert new relationships
            for (final managerId in managerIds) {
              await connection.database.insert('link_managers_links', {
                'link_id': id,
                'manager_id': managerId,
              });
            }
          }

          await connection.database.commitTransaction();

          _logger.info('Updated link', {
            'id': id,
            'fields': [
              if (updateData.isNotEmpty) 'basic data',
              if (viewIds != null) 'views',
              if (keywordIds != null) 'keywords',
              if (managerIds != null) 'managers',
            ].join(', '),
          });

          return true;
        } catch (e) {
          await connection.database.rollbackTransaction();
          rethrow;
        }
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException || e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to update link', e, stackTrace);
      throw DatabaseException(
          'Failed to update link: ${e.toString()}', e, stackTrace);
    }
  }
}
