import 'package:backend/services/auth_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:shelf/shelf.dart';

class AuthMiddleware {
  final AuthService authService;

  AuthMiddleware(this.authService);

  Middleware get requireAdmin => (Handler innerHandler) {
        return (Request request) async {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return ApiResponse.unauthorized('No valid token provided');
          }

          final token = authHeader.substring(7);
          if (!authService.verifyAccessToken(token, request)) {
            return ApiResponse.unauthorized('Invalid or expired token');
          }

          // Check if user is an admin
          final userGroups = authService.getGroupsFromToken(token);

          if (!userGroups.contains('admin') &&
              !userGroups.contains('si-bcu-g')) {
            return ApiResponse.forbidden('Insufficient permissions');
          }

          // Continue to the handler
          return innerHandler(request);
        };
      };

  Middleware get requireAuth => (Handler innerHandler) {
        return (Request request) async {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return ApiResponse.unauthorized('No valid token provided');
          }

          final token = authHeader.substring(7);
          if (!authService.verifyAccessToken(token, request)) {
            return ApiResponse.unauthorized('Invalid or expired token');
          }

          // Continue to the handler
          return innerHandler(request);
        };
      };
}
