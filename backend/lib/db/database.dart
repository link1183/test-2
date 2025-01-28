import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  late final Database _db;
  Database get db => _db;

  void init() {
    _db = sqlite3.open('data.db');
    _initializeDatabase();
  }

  void _initializeDatabase() {
    final tableExists = _db.select('''
        SELECT name
        FROM sqlite_master
        WHERE type='table' AND name='link';
      ''');

    if (tableExists.isEmpty) {
      _createTables();
      _insertMockData();
    }
  }

  void _createTables() {
    _db.execute('''
CREATE TABLE IF NOT EXISTS `link` (
	`id` integer primary key NOT NULL UNIQUE,
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
	`surname` TEXT NOT NULL
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

  void _insertMockData() {
    _db.execute('BEGIN TRANSACTION;');
    try {
      final mockData = [
        '''INSERT INTO status (id, name) VALUES
         (1, 'Active'),
         (2, 'Pending'),
         (3, 'Archived'),
         (4, 'Under Review'),
         (5, 'Draft'),
         (6, 'Deprecated')''',
        '''INSERT INTO categories (id, name) VALUES
         (1, 'Documentation'),
         (2, 'Tutorials'),
         (3, 'API Reference'),
         (4, 'Best Practices'),
         (5, 'Getting Started'),
         (6, 'Security Guidelines'),
         (7, 'Performance Tips'),
         (8, 'Troubleshooting'),
         (9, 'Development Tools'),
         (10, 'Integration Guides')''',
        '''INSERT INTO keyword (id, keyword) VALUES
         (1, 'flutter'),
         (2, 'dart'),
         (3, 'database'),
         (4, 'mobile'),
         (5, 'web'),
         (6, 'backend'),
         (7, 'frontend'),
         (8, 'testing'),
         (9, 'security'),
         (10, 'performance'),
         (11, 'deployment'),
         (12, 'architecture'),
         (13, 'debugging'),
         (14, 'authentication'),
         (15, 'api'),
         (16, 'ui'),
         (17, 'ux'),
         (18, 'responsive'),
         (19, 'storage'),
         (20, 'networking')''',
        '''INSERT INTO link_manager (id, name, surname) VALUES
         (1, 'John', 'Doe'),
         (2, 'Jane', 'Smith'),
         (3, 'Robert', 'Johnson'),
         (4, 'Sarah', 'Williams'),
         (5, 'Michael', 'Brown'),
         (6, 'Emily', 'Davis'),
         (7, 'David', 'Miller'),
         (8, 'Lisa', 'Wilson'),
         (9, 'James', 'Taylor'),
         (10, 'Emma', 'Anderson')''',
        '''INSERT INTO view (id, name) VALUES
         (1, 'Public'),
         (2, 'Internal'),
         (3, 'Developer'),
         (4, 'Administrator'),
         (5, 'Team Lead'),
         (6, 'Security Team')''',
        '''INSERT INTO link (id, title, description, doc_link, status_id, category_id) VALUES
         (1, 'Flutter Setup Guide', 'Complete guide for setting up Flutter development environment', 'https://docs.example.com/flutter-setup', 1, 5),
         (2, 'Dart Language Overview', 'Comprehensive overview of Dart programming language', 'https://docs.example.com/dart-overview', 1, 1),
         (3, 'SQLite Integration', 'Tutorial on integrating SQLite with Flutter applications', 'https://docs.example.com/sqlite-flutter', 1, 2),
         (4, 'API Documentation', 'Complete API reference for the platform', 'https://docs.example.com/api-ref', 2, 3),
         (5, 'Testing Guidelines', 'Best practices for testing Flutter applications', 'https://docs.example.com/testing', 1, 4),
         (6, 'Security Best Practices', 'Essential security guidelines for Flutter applications', 'https://docs.example.com/security', 1, 6),
         (7, 'Performance Optimization Guide', 'Tips and tricks for optimizing Flutter app performance', 'https://docs.example.com/performance', 1, 7),
         (8, 'Common Issues & Solutions', 'Solutions to frequently encountered Flutter problems', 'https://docs.example.com/troubleshooting', 1, 8),
         (9, 'VS Code Setup for Flutter', 'Setting up Visual Studio Code for Flutter development', 'https://docs.example.com/vscode-setup', 1, 9),
         (10, 'Firebase Integration', 'Guide to integrating Firebase with Flutter', 'https://docs.example.com/firebase', 1, 10),
         (11, 'State Management Overview', 'Comparison of different state management solutions', 'https://docs.example.com/state', 1, 1),
         (12, 'UI Components Guide', 'Comprehensive guide to Flutter UI components', 'https://docs.example.com/ui-components', 1, 2),
         (13, 'REST API Integration', 'Tutorial on integrating REST APIs in Flutter', 'https://docs.example.com/rest-api', 1, 10),
         (14, 'App Architecture Guide', 'Best practices for Flutter app architecture', 'https://docs.example.com/architecture', 1, 4),
         (15, 'Animation Tutorial', 'Create smooth animations in Flutter', 'https://docs.example.com/animations', 1, 2)''',
        '''INSERT INTO link_managers_links (link_id, manager_id) VALUES
         (1, 1), (1, 2), (2, 2), (3, 3), (4, 4), (5, 1),
         (6, 5), (7, 6), (8, 7), (9, 8), (10, 9),
         (11, 2), (12, 3), (13, 4), (14, 5), (15, 6),
         (6, 10), (7, 1), (8, 2), (9, 3), (10, 4)''',
        '''INSERT INTO links_views (link_id, view_id) VALUES
         (1, 1), (1, 2), (2, 1), (3, 3), (4, 2), (5, 1),
         (6, 6), (7, 1), (8, 1), (9, 1), (10, 3),
         (11, 1), (12, 1), (13, 3), (14, 2), (15, 1),
         (6, 2), (7, 2), (8, 3), (9, 2), (10, 1)''',
        '''INSERT INTO keywords_links (link_id, keyword_id) VALUES
         (1, 1), (1, 4), (2, 2), (3, 1), (3, 3), (4, 6), (5, 1), (5, 8),
         (6, 9), (6, 1), (7, 1), (7, 10), (8, 1), (8, 13), (9, 1), (9, 7),
         (10, 1), (10, 15), (11, 1), (11, 12), (12, 1), (12, 16),
         (13, 1), (13, 15), (14, 1), (14, 12), (15, 1), (15, 16),
         (6, 14), (7, 18), (8, 19), (9, 17), (10, 20)'''
      ];
      for (final sql in mockData) {
        _db.execute(sql);
      }
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }
}
