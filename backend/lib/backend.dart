import 'package:backend/db/api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

void main() async {
  var db = DatabaseApi();

  final app = Router();

  app.mount('/api/', db.router.call);

  final handler = Pipeline()
      .addMiddleware(logRequests.call())
      .addMiddleware(corsHeaders())
      .addHandler(app.call);

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Server running on http://${server.address.host}:${server.port}');
}
