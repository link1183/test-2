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
    this.ldapUrl = 'dc1.ad.unil.ch',
    this.ldapPort = 636,
    this.baseDN = 'DC=ad,DC=unil,DC=ch',
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
      await ldap.close();
      throw Exception('Failed to connect to LDAP server: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserData(String username) async {
    late final LdapConnection ldap;

    try {
      ldap = await _getLdapConnection();

      final serviceAccountDN = '$serviceAccountUsername@ad.unil.ch';
      await ldap.bind(DN: serviceAccountDN, password: serviceAccountPassword);

      final searchResult = await ldap.search(
        baseDN,
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
        'mail': userEntry.attributes['mail']?.values.first,
        'groups': groups,
      };
    } on LdapException catch (e) {
      print('Unexpected error during authentication: $e');
      return null;
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
      await ldap.bind(DN: userDN, password: password);

      final searchResult = await ldap.search(
        baseDN,
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
        'mail': userEntry.attributes['mail']?.values.first,
        'groups': groups,
      };
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
    print(fingerprint);
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
