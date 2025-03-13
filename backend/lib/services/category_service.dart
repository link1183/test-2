import 'dart:convert' as convert;

import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';

/// Data model for Category
class Category {
  final int? id;
  final String name;

  Category({this.id, required this.name});

  /// Creates a category from a database row
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  /// Creates a copy of this category with optional overrides
  Category copyWith({int? id, String? name}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  /// Converts this category to a database row
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
    };
  }
}

/// Service for managing categories
class CategoryService {
  final DatabaseConnectionPool _connectionPool;
  final Logger _logger = LoggerFactory.getLogger('CategoryService');

  CategoryService(this._connectionPool);

  /// Creates a new category
  Future<int> createCategory(String name) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw ArgumentError('Category name cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if a category with this name already exists
        final existingCategories = await connection.database.query(
          'SELECT id FROM categories WHERE name = ?',
          [name],
        );

        if (existingCategories.isNotEmpty) {
          throw ConstraintException('A category with this name already exists');
        }

        // Insert the category
        final id =
            await connection.database.insert('categories', {'name': name});

        _logger.info('Created new category', {'id': id, 'name': name});
        return id;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException || e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to create category', e, stackTrace);
      throw DatabaseException('Failed to create category', e, stackTrace);
    }
  }

  /// Deletes a category by ID
  Future<bool> deleteCategory(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        // Check if the category exists
        final categoryExists = await connection.database.query(
          'SELECT 1 FROM categories WHERE id = ?',
          [id],
        );

        if (categoryExists.isEmpty) {
          _logger.warning('Category not found for deletion', {'id': id});
          return false;
        }

        // Check if there are any links using this category
        final linkedLinks = await connection.database.query(
          'SELECT COUNT(*) as count FROM link WHERE category_id = ?',
          [id],
        );

        final linkCount = linkedLinks.first['count'] as int;
        if (linkCount > 0) {
          throw ConstraintException(
            'Cannot delete category: it is used by $linkCount links',
          );
        }

        // Start a transaction
        await connection.database.beginTransaction();

        try {
          // Delete the category
          await connection.database.delete(
            'categories',
            where: 'id = ?',
            whereArgs: [id],
          );

          await connection.database.commitTransaction();

          _logger.info('Deleted category', {'id': id});
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

      _logger.error('Failed to delete category', e, stackTrace);
      throw DatabaseException(
          'Failed to delete category: ${e.toString()}', e, stackTrace);
    }
  }

  /// Gets all categories
  Future<List<Category>> getAllCategories() async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, name FROM categories ORDER BY name',
        );

        return results.map((row) => Category.fromMap(row)).toList();
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get all categories', e, stackTrace);
      throw DatabaseException('Failed to retrieve categories', e, stackTrace);
    }
  }

  /// Gets all categories for a user based on their groups
  Future<List<Map<String, dynamic>>> getCategoriesForUser(
      List<String> userGroups) async {
    if (userGroups.isEmpty) {
      return [];
    }

    try {
      final connection = await _connectionPool.getConnection();

      try {
        // Sort groups for consistent cache key
        final sortedGroups = List<String>.from(userGroups)..sort();

        // Create placeholders for SQL query
        final placeholders = List.filled(sortedGroups.length, '?').join(',');

        // Get categories and links in a single query

        final sql = '''
        WITH LinkData AS (
          SELECT 
            link.*,
            s.name as status_name,
            IFNULL(
              (
                SELECT json_group_array(json_object(
                  'id', k.id, 'keyword', k.keyword
                ))
                FROM keywords_links kl
                JOIN keyword k ON k.id = kl.keyword_id
                WHERE kl.link_id = link.id
              ),
              '[]'
            ) as keywords,
            IFNULL(
              (
                SELECT json_group_array(json_object(
                  'id', v.id, 'name', v.name
                ))
                FROM links_views lv
                JOIN view v ON v.id = lv.view_id
                WHERE lv.link_id = link.id
              ),
              '[]'
            ) as views,
            IFNULL(
              (
                SELECT json_group_array(json_object(
                  'id', m.id, 'name', m.name, 'surname', m.surname, 'link', m.link
                ))
                FROM link_managers_links lm
                JOIN link_manager m ON m.id = lm.manager_id
                WHERE lm.link_id = link.id
              ),
              '[]'
            ) as managers,
            EXISTS (
              SELECT 1 
              FROM links_views lv2
              JOIN view v2 ON v2.id = lv2.view_id
              WHERE lv2.link_id = link.id 
              AND v2.name IN ($placeholders)
            ) as has_access
          FROM link
          LEFT JOIN status s ON s.id = link.status_id
        )
        SELECT 
          c.id as category_id,
          c.name as category_name,
          IFNULL(
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
            ),
            '[]'
          ) as links
        FROM categories c
        LEFT JOIN LinkData ld ON c.id = ld.category_id
        GROUP BY c.id
      ''';
        // Execute query
        final result = await connection.database.query(sql, sortedGroups);

        // Post-process results
        for (final category in result) {
          // Parse the links JSON
          final linksJson = category['links'] as String?;

          try {
            // Handle the case when linksJson is null
            if (linksJson == null) {
              category['links'] = [];
              continue;
            }

            // Try to parse, but handle failure gracefully
            dynamic parsedLinks;
            try {
              parsedLinks = _parseJson(linksJson);
            } catch (e) {
              _logger.error('Error parsing root links JSON', e);
              category['links'] = [];
              continue;
            }

            if (parsedLinks == null) {
              category['links'] = [];
              continue;
            }

            // Ensure we have a list
            final linksList = parsedLinks is List ? parsedLinks : [];

            // Filter out null values and process nested JSON
            final validLinks =
                linksList.where((link) => link != null).map((link) {
              if (link is Map<String, dynamic>) {
                // Parse nested JSON strings, handling each one individually with safe defaults

                // Handle keywords
                if (link.containsKey('keywords')) {
                  try {
                    if (link['keywords'] is String) {
                      link['keywords'] = _safeParseJson(link['keywords']);
                    }
                  } catch (e) {
                    _logger.error('Error parsing keywords JSON', e);
                    link['keywords'] = [];
                  }
                } else {
                  link['keywords'] = [];
                }

                // Handle views
                if (link.containsKey('views')) {
                  try {
                    if (link['views'] is String) {
                      link['views'] = _safeParseJson(link['views']);
                    }
                  } catch (e) {
                    _logger.error('Error parsing views JSON', e);
                    link['views'] = [];
                  }
                } else {
                  link['views'] = [];
                }

                // Handle managers
                if (link.containsKey('managers')) {
                  try {
                    if (link['managers'] is String) {
                      link['managers'] = _safeParseJson(link['managers']);
                    }
                  } catch (e) {
                    _logger.error('Error parsing managers JSON', e);
                    link['managers'] = [];
                  }
                } else {
                  link['managers'] = [];
                }
              }

              return link;
            }).toList();

            // Update the category with parsed links
            category['links'] = validLinks;
          } catch (e) {
            _logger.error('Error processing category links', e);
            category['links'] = [];
          }
        }
        return result;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get categories for user', e, stackTrace);
      throw DatabaseException('Failed to retrieve categories', e, stackTrace);
    }
  }

  /// Gets a category by ID
  Future<Category?> getCategoryById(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, name FROM categories WHERE id = ?',
          [id],
        );

        if (results.isEmpty) {
          return null;
        }

        return Category.fromMap(results.first);
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get category by ID', e, stackTrace);
      throw DatabaseException('Failed to retrieve category', e, stackTrace);
    }
  }

  /// Updates a category
  Future<bool> updateCategory(int id, String name) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw ArgumentError('Category name cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if the category exists
        final categoryExists = await connection.database.query(
          'SELECT 1 FROM categories WHERE id = ?',
          [id],
        );

        if (categoryExists.isEmpty) {
          _logger.warning('Category not found for update', {'id': id});
          return false;
        }

        // Check if another category with this name already exists
        final existingCategory = await connection.database.query(
          'SELECT id FROM categories WHERE name = ? AND id != ?',
          [name, id],
        );

        if (existingCategory.isNotEmpty) {
          throw ConstraintException(
              'Another category with this name already exists');
        }

        // Update the category
        await connection.database.update(
          'categories',
          {'name': name},
          where: 'id = ?',
          whereArgs: [id],
        );

        _logger.info('Updated category', {'id': id, 'name': name});
        return true;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException || e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to update category', e, stackTrace);
      throw DatabaseException(
          'Failed to update category: ${e.toString()}', e, stackTrace);
    }
  }

  /// Parse JSON with error handling
  dynamic _parseJson(String? json) {
    if (json == null || json.isEmpty) {
      return [];
    }

    try {
      return (_connectionPool.config.extraOptions['jsonCodec'] as JsonCodec?)
              ?.decode(json) ??
          const JsonCodec().decode(json);
    } catch (e) {
      _logger.error('Error parsing JSON', e);
      return [];
    }
  }

  dynamic _safeParseJson(dynamic json) {
    if (json == null) return [];
    if (json is! String) return [];
    if (json.isEmpty) return [];

    try {
      final result =
          (_connectionPool.config.extraOptions['jsonCodec'] as JsonCodec?)
                  ?.decode(json) ??
              const JsonCodec().decode(json);
      return result is List ? result : [];
    } catch (e) {
      return [];
    }
  }
}

/// JSON codec for use with database
class JsonCodec {
  const JsonCodec();

  dynamic decode(String source) => convert.json.decode(source);
  String encode(dynamic value) => convert.json.encode(value);
}
