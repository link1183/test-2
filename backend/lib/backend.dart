import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'db/database.dart';

void main() async {
  final db = AppDatabase()..init();

  final app = Router();

  app.get('/links', (Request req) async {
    final links = db.db.select('SELECT * FROM link;');
    return Response.ok(links.toString());
  });

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(app);

  final server = await io.serve(handler, 'localhost', 8080);
  print('Server running on http://${server.address.host}:${server.port}');
}
