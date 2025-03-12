import 'package:backend/db/database_interface.dart';
import 'package:backend/db/migration/migration.dart';

/// Initial database schema migration
class InitialSchemaMigration extends Migration {
  InitialSchemaMigration() : super(1, 'Initial schema');

  @override
  Future<void> down(DatabaseInterface db) async {
    log('Rolling back initial schema...');

    // Drop tables in reverse order of dependencies
    await db.execute('DROP TABLE IF EXISTS keywords_links;');
    await db.execute('DROP TABLE IF EXISTS keyword;');
    await db.execute('DROP TABLE IF EXISTS links_views;');
    await db.execute('DROP TABLE IF EXISTS link_managers_links;');
    await db.execute('DROP TABLE IF EXISTS link;');
    await db.execute('DROP TABLE IF EXISTS status;');
    await db.execute('DROP TABLE IF EXISTS categories;');
    await db.execute('DROP TABLE IF EXISTS view;');
    await db.execute('DROP TABLE IF EXISTS link_manager;');

    log('Initial schema rollback completed.');
  }

  @override
  Future<void> up(DatabaseInterface db) async {
    log('Creating initial schema...');

    // Create tables
    await db.execute('''
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
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS `link_manager` (
        `id` integer primary key NOT NULL UNIQUE,
        `name` TEXT NOT NULL,
        `surname` TEXT NOT NULL,
        `link` TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS `link_managers_links` (
        `link_id` INTEGER NOT NULL,
        `manager_id` INTEGER NOT NULL,
        FOREIGN KEY(`link_id`) REFERENCES `link`(`id`),
        FOREIGN KEY(`manager_id`) REFERENCES `link_manager`(`id`)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS `view` (
        `id` integer primary key NOT NULL UNIQUE,
        `name` TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS `links_views` (
        `link_id` INTEGER NOT NULL,
        `view_id` INTEGER NOT NULL,
        FOREIGN KEY(`link_id`) REFERENCES `link`(`id`),
        FOREIGN KEY(`view_id`) REFERENCES `view`(`id`)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS `categories` (
        `id` integer primary key NOT NULL UNIQUE,
        `name` TEXT NOT NULL UNIQUE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS `status` (
        `id` integer primary key NOT NULL UNIQUE,
        `name` TEXT NOT NULL UNIQUE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS `keyword` (
        `id` integer primary key NOT NULL UNIQUE,
        `keyword` TEXT NOT NULL UNIQUE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS `keywords_links` (
        `link_id` INTEGER NOT NULL,
        `keyword_id` INTEGER NOT NULL,
        FOREIGN KEY(`link_id`) REFERENCES `link`(`id`),
        FOREIGN KEY(`keyword_id`) REFERENCES `keyword`(`id`)
      );
    ''');

    // Create indexes for better performance
    log('Creating indexes...');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_link_category ON link(category_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_link_status ON link(status_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_links_views_link ON links_views(link_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_links_views_view ON links_views(view_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_keywords_links_link ON keywords_links(link_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_keywords_links_keyword ON keywords_links(keyword_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_link_managers_links_link ON link_managers_links(link_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_link_managers_links_manager ON link_managers_links(manager_id);');
    await db
        .execute('CREATE INDEX IF NOT EXISTS idx_link_title ON link(title);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_link_description ON link(description);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_view_name ON view(name);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_keyword_keyword ON keyword(keyword);');

    log('Initial schema migration completed.');
  }
}
