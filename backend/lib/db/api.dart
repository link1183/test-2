import 'dart:convert';
import 'package:backend/db/database.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class DatabaseApi {
  final AppDatabase db;

  DatabaseApi() : db = AppDatabase() {
    db.init();
  }

  Router get router {
    final router = Router();

    router.get('/api/categories', (Request request) {
      try {
        final categories = db.db.select('''
          WITH LinkData AS (
            SELECT 
              l.*,
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
                'surname', m.surname
              )) as managers
            FROM link l
            LEFT JOIN status s ON s.id = l.status_id
            LEFT JOIN keywords_links kl ON l.id = kl.link_id
            LEFT JOIN keyword k ON k.id = kl.keyword_id
            LEFT JOIN links_views lv ON l.id = lv.link_id
            LEFT JOIN view v ON v.id = lv.view_id
            LEFT JOIN link_managers_links lm ON l.id = lm.link_id
            LEFT JOIN link_manager m ON m.id = lm.manager_id
            GROUP BY l.id
          )
          SELECT 
            c.id as category_id,
            c.name as category_name,
            json_group_array(
              CASE 
                WHEN ld.id IS NULL THEN json_object()
                ELSE json_object(
                  'id', ld.id,
                  'title', ld.title,
                  'description', ld.description,
                  'doc_link', ld.doc_link,
                  'status_id', ld.status_id,
                  'status_name', ld.status_name,
                  'keywords', ld.keywords,
                  'views', ld.views,
                  'managers', ld.managers
                )
              END
            ) as links
          FROM categories c
          LEFT JOIN LinkData ld ON c.id = ld.category_id
          GROUP BY c.id
        ''').map((row) {
          var map = Map<String, dynamic>.from(row);
          var links = jsonDecode(map['links']) as List;

          // Filter out empty objects from links
          links = links.where((link) => link.isNotEmpty).map((link) {
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

        return Response.ok(
          jsonEncode({'categories': categories}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}),
            headers: {'content-type': 'application/json'});
      }
    });

    return router;
  }
}
