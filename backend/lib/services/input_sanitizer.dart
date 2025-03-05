import 'dart:convert';

class InputSanitizer {
  static final RegExp _ldapInjectionPattern = RegExp(
    r'[()|\&!@<>\\/*\[\]{}=~\r\n]',
  );

  static final RegExp _sqlInjectionPattern = RegExp(
    r'(\b(union|select|insert|update|delete|drop|alter)\b)|(-{2})|(/\*)|(\b(or|and)\b\s+\d+\s*[=<>])',
    caseSensitive: false,
  );

  static final RegExp _xssPattern = RegExp(
    r'<[^>]*script|javascript:|data:|vbscript:|on\w+\s*=|\b(alert|confirm|prompt|console\.log)\s*\(',
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
    if (input is Map) {
      return input.map((key, value) => MapEntry(
            key is String ? sanitizeText(key) : key,
            value is String && _isBase64(value) ? value : sanitizeJson(value),
          ));
    } else if (input is List) {
      return input.map((item) => sanitizeJson(item)).toList();
    } else if (input is String) {
      return _isBase64(input) ? input : sanitizeText(input);
    }
    return input;
  }

  static String sanitizeLdapDN(String dn) {
    return dn.replaceAll(_ldapInjectionPattern, '');
  }

  static Map<String, dynamic>? sanitizeRequestBody(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (decoded.containsKey('username') && decoded.containsKey('password')) {
        return decoded;
      }

      return sanitizeJson(decoded);
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
    try {
      base64.decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }
}
