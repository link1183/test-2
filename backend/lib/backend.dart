import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'db/database.dart';

void main() async {
  final db = AppDatabase()..init();

  final app = Router();

  app.get('/api/links', (Request req) async {
    final links = db.db.select('SELECT * FROM keyword;');
    return Response.ok(links.toString());
  });

  app.get('/api/mock_insert', (Request req) async {
    db.insertMockData();
    return Response.ok('Success');
  });

  app.get('/api/mock', (Request request) {
    final links = db.db.select('''
        SELECT 
          l.*,
          s.name as status_name,
          c.name as category_name,
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
        LEFT JOIN categories c ON c.id = l.category_id
        LEFT JOIN keywords_links kl ON l.id = kl.link_id
        LEFT JOIN keyword k ON k.id = kl.keyword_id
        LEFT JOIN links_views lv ON l.id = lv.link_id
        LEFT JOIN view v ON v.id = lv.view_id
        LEFT JOIN link_managers_links lm ON l.id = lm.link_id
        LEFT JOIN link_manager m ON m.id = lm.manager_id
        GROUP BY l.id
      ''').map((row) {
      var map = Map<String, dynamic>.from(row);
      // Parse JSON arrays from SQLite
      map['keywords'] = jsonDecode(map['keywords']);
      map['views'] = jsonDecode(map['views']);
      map['managers'] = jsonDecode(map['managers']);
      return map;
    }).toList();

    return Response.ok(
      jsonEncode({'links': links}),
      headers: {'content-type': 'application/json'},
    );
  });

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(app);

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Server running on http://${server.address.host}:${server.port}');
}
