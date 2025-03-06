import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  late final Database _db;
  final String dbPath;
  final bool enableLogging;

  AppDatabase({
    this.dbPath = '/data/data.db',
    this.enableLogging = false,
  });

  Database get db => _db;

  Future<bool> backup(String backupPath) async {
    if (enableLogging) {
      print('Starting database backup to $backupPath...');
    }

    try {
      final sourceFile = File(dbPath);

      _db.execute('PRAGMA wal_checkpoint;');

      await sourceFile.copy(backupPath);

      if (enableLogging) {
        final sourceSize = await sourceFile.length();
        final backupSize = await File(backupPath).length();

        print('Database backup completed successfully');
        print('Source size: ${(sourceSize / 1024).toStringAsFixed(2)} KB');
        print('Backup size: ${(backupSize / 1024).toStringAsFixed(2)} KB');
      }

      return true;
    } catch (e) {
      print('Database backup failed: $e');
      return false;
    }
  }

  void dispose() {
    try {
      _db.dispose();
      if (enableLogging) {
        print('Database connection closed.');
      }
    } catch (e) {
      print('Error closing database: $e');
    }
  }

  List<Map<String, dynamic>> executeQuery(String sql,
      [List<Object?> parameters = const []]) {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final result = _db.select(sql, parameters);
      if (enableLogging) {
        print('Query executed in ${stopwatch.elapsedMilliseconds}ms: $sql');
      }
      return result;
    } catch (e) {
      print('Query failed in ${stopwatch.elapsedMilliseconds}ms: $sql');
      print('Error: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> getCategoriesForUser(List<String> userGroups) {
    if (userGroups.isEmpty) {
      return [];
    }

    // Convert userGroups to SQL placeholders
    final placeholders = userGroups.map((_) => '?').join(',');

    // Prepare the SQL statement
    final stmt = _db.prepare('''
    WITH LinkData AS (
      SELECT 
        link.*,
        s.name as status_name,
        json_group_array(DISTINCT json_object(
          'id', k.id,
          'keyword', k.keyword
        )) as keywords,
        json_group_array(DISTINCT json_object(
          'id', v.id,
          'name', v.name
        )) as views,
        json_group_array(DISTINCT json_object(
          'id', m.id,
          'name', m.name,
          'surname', m.surname,
          'link', m.link
        )) as managers,
        EXISTS (
          SELECT 1 
          FROM links_views lv2
          JOIN view v2 ON v2.id = lv2.view_id
          WHERE lv2.link_id = link.id 
          AND v2.name IN ($placeholders)
        ) as has_access
      FROM link
      LEFT JOIN status s ON s.id = link.status_id
      LEFT JOIN keywords_links kl ON link.id = kl.link_id
      LEFT JOIN keyword k ON k.id = kl.keyword_id
      LEFT JOIN links_views lv ON link.id = lv.link_id
      LEFT JOIN view v ON v.id = lv.view_id
      LEFT JOIN link_managers_links lm ON link.id = lm.link_id
      LEFT JOIN link_manager m ON m.id = lm.manager_id
      GROUP BY link.id
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

    try {
      final Stopwatch stopwatch = Stopwatch()..start();
      final result = stmt.select(userGroups);

      if (enableLogging) {
        print(
            'Category query executed in ${stopwatch.elapsedMilliseconds}ms for ${userGroups.length} groups');
      }

      return result.map((row) {
        var map = Map<String, dynamic>.from(row);
        var links = jsonDecode(map['links']) as List;

        links = links.where((link) => link != null).map((link) {
          if (link['keywords'] != null) {
            link['keywords'] = jsonDecode(link['keywords'].toString());
          }
          if (link['views'] != null) {
            link['views'] = jsonDecode(link['views'].toString());
          }
          if (link['managers'] != null) {
            link['managers'] = jsonDecode(link['managers'].toString());
          }
          return link;
        }).toList();

        map['links'] = links;
        return map;
      }).toList();
    } finally {
      stmt.dispose(); // Important to dispose the statement
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

  void init() {
    final dbDir = Directory(dbPath.substring(0, dbPath.lastIndexOf('/')));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }

    _db = sqlite3.open('/data/data.db');
    _initializeDatabase();

    if (enableLogging) {
      print('Database initialized at $dbPath');
    }

    if (!_checkDatabaseIntegrity()) {
      print(
          'WARNING: Database integrity check failed. Consider running recovery.');
    }
  }

  bool _checkDatabaseIntegrity() {
    try {
      final result = _db.select("PRAGMA integrity_check;");
      return result.first['integrity_check'] == 'ok';
    } catch (e) {
      print('Database integrity check failed: $e');
      return false;
    }
  }

  void _createIndexes() {
    print('Creating database indexes for performance optimization...');
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
      print(
          'Upgrading database from version $currentVersion to $targetVersion');
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
        print('Database migration completed successfully');
      } catch (e) {
        _db.execute('ROLLBACK;');
        print('Database migration failed: $e');
        rethrow;
      }
    } else {
      print('Database already at current version ($currentVersion)');
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
}
