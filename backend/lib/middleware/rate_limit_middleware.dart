import 'package:backend/services/auth_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:shelf/shelf.dart';

class RateLimitMiddleware {
  final AuthService authService;

  RateLimitMiddleware(this.authService);

  Middleware get checkRateLimit => (Handler innerHandler) {
        return (Request request) async {
          if (!authService.checkRateLimit(request)) {
            return ApiResponse.tooManyRequests(
                'Too many attempts. Please try again later.');
          }

          // Continue to the handler
          return innerHandler(request);
        };
      };
}
