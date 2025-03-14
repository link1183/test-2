import 'dart:convert';

import 'package:shelf/shelf.dart';

class ApiResponse {
  static Response badRequest(String message, {dynamic details}) {
    return error(
      statusCode: 400,
      message: message,
      code: 'bad_request',
      details: details,
    );
  }

  static Response conflict(String message, {dynamic details}) {
    return error(
      statusCode: 409,
      message: message,
      code: 'conflict',
      details: details,
    );
  }

  static Response error({
    required int statusCode,
    required String message,
    String? code,
    dynamic details,
  }) {
    final Map<String, dynamic> body = {
      'error': {
        'message': message,
        if (code != null) 'code': code,
        if (details != null) 'details': details,
      }
    };

    return Response(
      statusCode,
      body: json.encode(body),
      headers: {'content-type': 'application/json'},
    );
  }

  static Response forbidden(String message) {
    return error(statusCode: 403, message: message, code: 'forbidden');
  }

  static Response notFound(String message) {
    return error(statusCode: 404, message: message, code: 'not_found');
  }

  static Response ok(dynamic data, {Map<String, String>? headers}) {
    return Response.ok(
      json.encode(data),
      headers: {'content-type': 'application/json', ...?headers},
    );
  }

  static Response serverError(String message, {dynamic details}) {
    return error(
      statusCode: 500,
      message: message,
      code: 'server_error',
      details: details,
    );
  }

  static Response tooManyRequests(String message) {
    return error(statusCode: 429, message: message, code: 'rate_limited');
  }

  static Response unauthorized(String message, {dynamic details}) {
    return error(
        statusCode: 401,
        message: message,
        code: 'unauthorized',
        details: details);
  }
}
