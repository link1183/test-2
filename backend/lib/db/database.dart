import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  late final Database _db;
  Database get db => _db;

  void init() {
    _db = sqlite3.open('data.db');
    _createTables();
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

  void insertMockData() {
    final mockData = [
      '''INSERT INTO status (id, name) VALUES
         (1, 'Active'),
         (2, 'Pending'),
         (3, 'Archived'),
         (4, 'Under Review')''',
      '''INSERT INTO categories (id, name) VALUES
         (1, 'Documentation'),
         (2, 'Tutorials'),
         (3, 'API Reference'),
         (4, 'Best Practices'),
         (5, 'Getting Started')''',
      '''INSERT INTO keyword (id, keyword) VALUES
         (1, 'flutter'),
         (2, 'dart'),
         (3, 'database'),
         (4, 'mobile'),
         (5, 'web'),
         (6, 'backend'),
         (7, 'frontend'),
         (8, 'testing')''',
      '''INSERT INTO link_manager (id, name, surname) VALUES
         (1, 'John', 'Doe'),
         (2, 'Jane', 'Smith'),
         (3, 'Robert', 'Johnson'),
         (4, 'Sarah', 'Williams')''',
      '''INSERT INTO view (id, name) VALUES
         (1, 'Public'),
         (2, 'Internal'),
         (3, 'Developer'),
         (4, 'Administrator')''',
      '''INSERT INTO link (id, title, description, doc_link, status_id, category_id) VALUES
         (1, 'Flutter Setup Guide', 'Complete guide for setting up Flutter development environment', 'https://docs.example.com/flutter-setup', 1, 5),
         (2, 'Dart Language Overview', 'Comprehensive overview of Dart programming language', 'https://docs.example.com/dart-overview', 1, 1),
         (3, 'SQLite Integration', 'Tutorial on integrating SQLite with Flutter applications', 'https://docs.example.com/sqlite-flutter', 1, 2),
         (4, 'API Documentation', 'Complete API reference for the platform', 'https://docs.example.com/api-ref', 2, 3),
         (5, 'Testing Guidelines', 'Best practices for testing Flutter applications', 'https://docs.example.com/testing', 1, 4)''',
      '''INSERT INTO link_managers_links (link_id, manager_id) VALUES
         (1, 1), (1, 2), (2, 2), (3, 3), (4, 4), (5, 1)''',
      '''INSERT INTO links_views (link_id, view_id) VALUES
         (1, 1), (1, 2), (2, 1), (3, 3), (4, 2), (5, 1)''',
      '''INSERT INTO keywords_links (link_id, keyword_id) VALUES
         (1, 1), (1, 4), (2, 2), (3, 1), (3, 3), (4, 6), (5, 1), (5, 8)'''
    ];

    for (final sql in mockData) {
      _db.execute(sql);
    }
  }
}
