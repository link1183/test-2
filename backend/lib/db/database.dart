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
}
