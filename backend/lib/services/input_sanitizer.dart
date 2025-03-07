import 'dart:convert';

class InputSanitizer {
  static final RegExp _ldapInjectionPattern = RegExp(
    r'[()|\&!@<>\\/*\[\]{}=~\r\n:;,]|(\*\()|(^=)',
  );

  static final RegExp _sqlInjectionPattern = RegExp(
    r'(\b(union|select|insert|update|delete|drop|alter|exec|execute|from|where|order\s+by|group\s+by|having)\b)|(-{2})|(\/\*)|(\b(or|and)\b\s*\d*\s*[=<>])|(\bxp_cmdshell\b)',
    caseSensitive: false,
  );

  static final RegExp _xssPattern = RegExp(
    r'<[^>]*script|javascript:|data:|vbscript:|on\w+\s*=|\b(alert|confirm|prompt|console\.|eval|setTimeout|setInterval)\s*\(|<\s*img|<\s*iframe|<\s*svg|<\s*object|document\.|window\.|FormData\(',
    caseSensitive: false,
  );

  static final RegExp _dangerousChars = RegExp(r'[;`$]');

  static bool isValidEmail(String email) {
    if (email.isEmpty || email.length > 254) return false;

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );

    return emailRegex.hasMatch(email);
  }

  static bool isValidPassword(String password) {
    if (password.isEmpty || password.length > 128) return false;

    if (password.runes.any((rune) => rune < 32 || rune > 126)) return false;

    if (_sqlInjectionPattern.hasMatch(password)) return false;
    if (_xssPattern.hasMatch(password)) return false;

    return true;
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);

      if (!['http', 'https'].contains(uri.scheme)) return false;

      if (_xssPattern.hasMatch(url)) return false;

      //if (uri.host == 'localhost' ||
      //    uri.host == '127.0.0.1' ||
      //    uri.host.startsWith('192.168.') ||
      //    uri.host.startsWith('10.') ||
      //    uri.host.startsWith('172.')) {
      //  return false;
      //}

      return true;
    } catch (e) {
      return false;
    }
  }

  static bool isValidUsername(String username) {
    if (username.isEmpty || username.length > 50) return false;

    final validChars = RegExp(r'^[a-zA-Z0-9@._-]+$');
    if (!validChars.hasMatch(username)) return false;

    if (_ldapInjectionPattern.hasMatch(username)) return false;

    if (_sqlInjectionPattern.hasMatch(username)) return false;

    return true;
  }

  static dynamic sanitizeJson(dynamic input) {
    try {
      if (input is Map) {
        var sanitizedMap = <String, dynamic>{};
        input.forEach((key, value) {
          if (key is String) {
            var sanitizedKey = sanitizeText(key);
            sanitizedMap[sanitizedKey] = value is String && _isBase64(value)
                ? value
                : sanitizeJson(value);
          }
        });
        return sanitizedMap;
      } else if (input is List) {
        return input.map((item) => sanitizeJson(item)).toList();
      } else if (input is String) {
        return _isBase64(input) ? input : sanitizeText(input);
      } else if (input is int || input is double || input is bool) {
        return input;
      }

      return input;
    } catch (e) {
      return input;
    }
  }

  static String sanitizeLdapDN(String dn) {
    return dn.replaceAll(_ldapInjectionPattern, '');
  }

  static Map<String, dynamic>? sanitizeRequestBody(String body) {
    try {
      // Trim the body to remove any leading/trailing whitespace
      body = body.trim();

      // Check if body is empty
      if (body.isEmpty) {
        return null;
      }

      // Attempt to parse JSON
      dynamic decoded = json.decode(body);

      // Ensure decoded is a Map<String, dynamic>
      if (decoded is! Map) {
        return null;
      }

      // Convert to Map<String, dynamic> with explicit type checking
      Map<String, dynamic> sanitizedMap = {};
      decoded.forEach((key, value) {
        if (key is String) {
          sanitizedMap[key] = value;
        }
      });

      // Special handling for login credentials
      if (sanitizedMap.containsKey('username') &&
          sanitizedMap.containsKey('password')) {
        return sanitizedMap;
      }

      // Sanitize the JSON
      var sanitized = sanitizeJson(sanitizedMap);

      // Validate that sanitization didn't completely strip the data
      if (sanitized == null || (sanitized is Map && sanitized.isEmpty)) {
        return null;
      }

      return sanitized;
    } catch (e) {
      return null;
    }
  }

  static String sanitizeText(String input) {
    var sanitized = input.replaceAll(_dangerousChars, '');

    sanitized = htmlEscape.convert(sanitized);

    return sanitized.trim();
  }

  static bool _isBase64(String str) {
    if (str.length % 4 != 0 && !str.endsWith('=') && !str.endsWith('==')) {
      return false;
    }

    if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(str)) {
      return false;
    }

    try {
      base64.decode(str);

      if (str.length < 16) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
