import 'dart:async';
import 'dart:io';

import 'package:backend/db/api.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/config_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

void main() async {
  Api? api;
  HttpServer? server;

  ProcessSignal.sigint.watch().listen((_) async {
    await _shutdown(server, api);
  });

  ProcessSignal.sigterm.watch().listen((_) async {
    await _shutdown(server, api);
  });

  try {
    final config = await ConfigService.getInstance();
    final AuthService authService = AuthService(
      jwtSecret: config.jwtSecret,
      serviceAccountUsername: config.serviceAccountUsername,
      serviceAccountPassword: config.serviceAccountPassword,
      ldapUrl: config.ldapUrl,
      ldapPort: config.ldapPort,
      baseDN: config.ldapBaseDN,
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
  } catch (e) {
    print('Failed to start server: $e');
    await _shutdown(server, api);
    exit(1);
  }
}

Future<void> _shutdown(HttpServer? server, Api? api) async {
  print('Shutting down server...');

  if (server != null) {
    await server.close(force: false);
    print('HTTP server closed');
  }

  if (api != null) {
    api.dispose();
    print('Database connections closed');
  }

  print('Shutdown complete');
  exit(0);
}
