import 'package:backend/db/api.dart';
import 'package:backend/services/auth_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final AuthService authService = AuthService(
    jwtSecret: 'Some secret key',
    serviceAccountUsername: 'agunthe1adm',
    serviceAccountPassword: 'E1MimgfaIlh2!?',
  );
  var api = Api(authService: authService);

  final app = Router();

  app.mount('/api/', api.router.call);

  final handler = Pipeline()
      .addMiddleware(logRequests.call())
      .addMiddleware(corsHeaders())
      .addHandler(app.call);

  app.get('/health', (Request request) {
    return Response.ok('OK');
  });

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Server running on http://${server.address.host}:${server.port}');
}
