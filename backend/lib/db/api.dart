import 'dart:convert';
import 'package:backend/db/database.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/encryption_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class Api {
  final AppDatabase db;
  final AuthService authService;
  final EncryptionService encryptionService;

  Api({required this.authService})
      : db = AppDatabase(),
        encryptionService = EncryptionService() {
    db.init();
  }

  Router get router {
    final router = Router();

    router.get('/categories', (Request request) {
      try {
        final categories = db.db.select('''
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
                'surname', m.surname
              )) as managers
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
            ) as links
          FROM categories c
          LEFT JOIN LinkData ld ON c.id = ld.category_id
          GROUP BY c.id
        ''').map((row) {
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

        return Response.ok(
          jsonEncode({'categories': categories}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // Auth endpoints
    router.get('/public-key', (Request request) {
      return Response.ok(
        json.encode({'publicKey': encryptionService.publicKey}),
        headers: {'content-type': 'application/json'},
      );
    });

    router.post('/login', (Request request) async {
      try {
        final payload = await request.readAsString();
        final data = json.decode(payload);

        final encryptedUsername = data['username'];
        final encryptedPassword = data['password'];

        if (encryptedUsername == null || encryptedPassword == null) {
          return Response(400, body: 'Username and password required');
        }

        final username = encryptionService.decrypt(encryptedUsername);
        final password = encryptionService.decrypt(encryptedPassword);

        final userData = await authService.authenticateUser(username, password);

        if (userData == null) {
          return Response(401, body: 'Invalid credentials');
        }

        final token = authService.generateToken(userData);

        return Response.ok(
          json.encode({'token': token, 'user': userData}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: 'Server error');
      }
    });

    router.post('/verify-token', (Request request) {
      try {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response(401, body: 'No token provided');
        }

        final token = authHeader.substring(7);
        final isValid = authService.verifyToken(token);

        if (!isValid) {
          return Response(401, body: 'Invalid or expired token');
        }

        return Response.ok('Token valid');
      } catch (e) {
        return Response.internalServerError(body: 'Server error');
      }
    });

    return router;
  }
}
