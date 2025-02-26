import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/token_service.dart';
import 'package:dartdap/dartdap.dart';
import 'package:shelf/shelf.dart';

class AuthService {
  final String ldapUrl;
  final int ldapPort;
  String baseDN;
  final TokenService tokenService;
  final String serviceAccountUsername;
  final String serviceAccountPassword;

  AuthService({
    required this.ldapUrl,
    required this.ldapPort,
    required this.baseDN,
    required String jwtSecret,
    required this.serviceAccountUsername,
    required this.serviceAccountPassword,
  }) : tokenService = TokenService(
          jwtSecret: jwtSecret,
          maxAttemptsPerWindow: 10,
          rateLimitWindow: Duration(seconds: 30),
        );

  Future<LdapConnection> _getLdapConnection() async {
    final ldap = LdapConnection(
      host: ldapUrl,
      port: ldapPort,
      ssl: true,
    );
    try {
      await ldap.open();
      return ldap;
    } catch (e) {
      if (!ldap.isReady) {
        try {
          await ldap.close();
        } catch (_) {}
      }
      throw Exception('Failed to connect to LDAP server: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserData(String username) async {
    username = InputSanitizer.sanitizeLdapDN(username);

    late final LdapConnection ldap;

    try {
      ldap = await _getLdapConnection();

      String serviceAccountDN =
          InputSanitizer.sanitizeLdapDN(serviceAccountUsername);

      serviceAccountDN = '$serviceAccountDN@ad.unil.ch';

      try {
        await ldap.bind(
            dn: DN(serviceAccountDN), password: serviceAccountPassword);
      } catch (e) {
        print('Service account bind failed: $e');
        rethrow;
      }

      final searchResult = await ldap.search(
        DN(baseDN),
        Filter.equals('sAMAccountName', username),
        ['displayName', 'cn', 'mail', 'memberOf'],
        scope: SearchScope.SUB_LEVEL,
      );

      SearchEntry? userEntry;
      await for (var entry in searchResult.stream) {
        if (entry.attributes['cn']?.values.first == username) {
          userEntry = entry;
          break;
        }
      }

      if (userEntry == null) return null;

      final sanitizedData = {
        'username': InputSanitizer.sanitizeText(
            userEntry.attributes['cn']?.values.first ?? ''),
        'displayName': InputSanitizer.sanitizeText(
            userEntry.attributes['displayName']?.values.first ?? ''),
        'email': InputSanitizer.sanitizeText(
            userEntry.attributes['mail']?.values.first ?? ''),
        'groups': userEntry.attributes['memberOf']?.values
                .map((v) => v.toString())
                .map((dn) =>
                    RegExp(r'CN=([^,]+)').firstMatch(dn)?.group(1) ?? '')
                .where((cn) => cn.isNotEmpty)
                .map((group) => InputSanitizer.sanitizeText(group))
                .toList() ??
            [],
      };

      return sanitizedData;
    } finally {
      await ldap.close();
    }
  }

  Future<Map<String, dynamic>?> authenticateUser(
      String username, String password) async {
    late final LdapConnection ldap;

    try {
      ldap = await _getLdapConnection();
      final userDN = '$username@ad.unil.ch';
      await ldap.bind(dn: DN(userDN), password: password);

      final searchResult = await ldap.search(
        DN(baseDN),
        Filter.equals('sAMAccountName', username),
        ['displayName', 'cn', 'mail', 'memberOf'],
        scope: SearchScope.SUB_LEVEL,
      );

      SearchEntry? userEntry;

      await for (var entry in searchResult.stream) {
        if (entry.attributes['cn']?.values.first == username) {
          userEntry = entry;
          break;
        }
      }

      if (userEntry == null) return null;

      final groups = <String>[];
      if (userEntry.attributes.containsKey('memberOf')) {
        groups.addAll(
          userEntry.attributes['memberOf']!.values
              .map((v) => v.toString())
              .map((dn) => RegExp(r'CN=([^,]+)').firstMatch(dn)?.group(1) ?? '')
              .where((cn) => cn.isNotEmpty),
        );
      }

      return {
        'username': userEntry.attributes['cn']?.values.first,
        'displayName': userEntry.attributes['displayName']?.values.first,
        'email': userEntry.attributes['mail']?.values.first,
        'groups': groups,
      };
    } on LdapResultInvalidCredentialsException catch (_) {
      print('Invalid credentials');
      return null;
    } on LdapException catch (e) {
      print('Unexpected error during authentication: $e');
      return null;
    } finally {
      await ldap.close();
    }
  }

  TokenPair generateTokenPair(Map<String, dynamic> userData, Request request) {
    final fingerprint = tokenService.generateFingerPrint(request);
    return tokenService.generateTokenPair(userData, fingerprint);
  }

  bool verifyAccessToken(String token, Request request) {
    final fingerprint = tokenService.generateFingerPrint(request);
    return tokenService.verifyAccessToken(token, fingerprint);
  }

  bool verifyRefreshToken(String token, Request request) {
    final fingerprint = tokenService.generateFingerPrint(request);
    return tokenService.verifyRefreshToken(token, fingerprint);
  }

  String? getUsernameFromRefreshToken(String token) {
    return tokenService.getUsernameFromRefreshToken(token);
  }

  bool checkRateLimit(Request request) {
    final ip = request.headers['x-forwarded-for']?.split(',').first.trim() ??
        request.headers['x-real-ip'] ??
        'unknown';

    return tokenService.checkRateLimit(ip);
  }
}
