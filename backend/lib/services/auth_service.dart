import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/token_service.dart';
import 'package:backend/utils/logger.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dartdap/dartdap.dart';
import 'package:shelf/shelf.dart';

class AuthService {
  final String ldapUrl;
  final int ldapPort;
  String baseDN;
  final TokenService tokenService;
  final String serviceAccountUsername;
  final String serviceAccountPassword;
  final String jwtSecret;
  late final LdapConnectionPool _ldapPool;
  final _logger = LoggerFactory.getLogger('AuthService');

  AuthService({
    required this.ldapUrl,
    required this.ldapPort,
    required this.baseDN,
    required this.jwtSecret,
    required this.serviceAccountUsername,
    required this.serviceAccountPassword,
  }) : tokenService = TokenService(
          jwtSecret: jwtSecret,
          maxAttemptsPerWindow: 10,
          rateLimitWindow: Duration(seconds: 30),
        ) {
    _ldapPool = LdapConnectionPool(
        ldapUrl: ldapUrl, ldapPort: ldapPort, maxConnections: 5);
  }

  Future<Map<String, dynamic>?> authenticateUser(
      String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      return null;
    }

    late final LdapConnection ldap;

    try {
      ldap = await _ldapPool.getConnection();
      final userDN = '$username@ad.unil.ch';

      try {
        await ldap.bind(dn: DN(userDN), password: password);
      } on LdapException catch (e) {
        _logger.error('LDAP error during bind', e);
        throw Exception('Authentication error: ${e.message}');
      }

      try {
        final searchResult = await ldap.search(
          DN(baseDN),
          Filter.equals('sAMAccountName', username),
          ['displayName', 'cn', 'mail', 'memberOf'],
          scope: SearchScope.SUB_LEVEL,
        );

        SearchEntry? userEntry;

        await for (var entry in searchResult.stream) {
          if (entry.attributes['cn']?.values.isNotEmpty == true &&
              entry.attributes['cn']?.values.first == username) {
            userEntry = entry;
            break;
          }
        }

        if (userEntry == null) {
          return null;
        }

        final groups = <String>[];
        if (userEntry.attributes.containsKey('memberOf')) {
          groups.addAll(
            userEntry.attributes['memberOf']!.values
                .map((v) => v.toString())
                .map((dn) =>
                    RegExp(r'CN=([^,]+)').firstMatch(dn)?.group(1) ?? '')
                .where((cn) => cn.isNotEmpty)
                .map((group) =>
                    InputSanitizer.sanitizeText(group)), // Sanitize group names
          );
        }

        // Sanitize all user data before returning
        return {
          'username': InputSanitizer.sanitizeText(
              userEntry.attributes['cn']?.values.first?.toString() ?? ''),
          'displayName': InputSanitizer.sanitizeText(
              userEntry.attributes['displayName']?.values.first?.toString() ??
                  ''),
          'email': InputSanitizer.sanitizeText(
              userEntry.attributes['mail']?.values.first?.toString() ?? ''),
          'groups': groups,
        };
      } on LdapResultSizeLimitExceededException {
        throw Exception('Too many results returned from directory');
      } on LdapResultTimeLimitExceededException {
        throw Exception('Directory search timed out');
      } on LdapException catch (e) {
        _logger.error('LDAP error during search', e);
        throw Exception('Error retrieving user information: ${e.message}');
      }
    } catch (e) {
      if (e is! Exception) {
        _logger.error('Unexpected error during authentication', e);
        throw Exception('Authentication failed due to an unexpected error');
      }
      rethrow;
    } finally {
      try {
        await _ldapPool.releaseConnection(ldap);
      } catch (e) {
        _logger.error('Error closing LDAP connection', e);
      }
    }
  }

  bool checkRateLimit(Request request, [String? username]) {
    return tokenService.checkRateLimit(request, username);
  }

  Future<void> dispose() async {
    await _ldapPool.dispose();
  }

  TokenPair generateTokenPair(Map<String, dynamic> userData, Request request) {
    final fingerprint = tokenService.generateFingerPrint(request);
    return tokenService.generateTokenPair(userData, fingerprint);
  }

  List<String> getGroupsFromToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      final payload = jwt.payload;

      if (!payload.containsKey('groups')) {
        return [];
      }

      final groups = payload['groups'];
      if (groups is! List) {
        return [];
      }

      return groups
          .map((group) => group.toString())
          .where((group) => group.isNotEmpty)
          .toList();
    } catch (e) {
      _logger.error('Error extracting groups from token', e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserData(String username) async {
    username = InputSanitizer.sanitizeLdapDN(username);

    late final LdapConnection ldap;

    try {
      ldap = await _ldapPool.getConnection();

      String serviceAccountDN =
          InputSanitizer.sanitizeLdapDN(serviceAccountUsername);

      serviceAccountDN = '$serviceAccountDN@ad.unil.ch';

      try {
        await ldap.bind(
            dn: DN(serviceAccountDN), password: serviceAccountPassword);
      } catch (e) {
        _logger.critical('Service account bind failed', e);
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
      await _ldapPool.releaseConnection(ldap);
    }
  }

  String? getUsernameFromRefreshToken(String token) {
    return tokenService.getUsernameFromRefreshToken(token);
  }

  bool verifyAccessToken(String token, Request request) {
    final fingerprint = tokenService.generateFingerPrint(request);
    return tokenService.verifyAccessToken(token, fingerprint);
  }

  bool verifyRefreshToken(String token, Request request) {
    final fingerprint = tokenService.generateFingerPrint(request);
    return tokenService.verifyRefreshToken(token, fingerprint);
  }
}

class LdapConnectionPool {
  final String ldapUrl;
  final int ldapPort;
  final bool useSsl;
  final int maxConnections;
  final Duration connectionTimeout;

  final List<LdapConnection> _availableConnections = [];
  final List<LdapConnection> _inUseConnections = [];

  LdapConnectionPool({
    required this.ldapUrl,
    required this.ldapPort,
    this.useSsl = true,
    this.maxConnections = 5,
    this.connectionTimeout = const Duration(seconds: 10),
  });

  Future<void> dispose() async {
    // Close all connections when shutting down
    for (final connection in [..._availableConnections, ..._inUseConnections]) {
      await _safeClose(connection);
    }

    _availableConnections.clear();
    _inUseConnections.clear();
  }

  Future<LdapConnection> getConnection() async {
    if (_availableConnections.isNotEmpty) {
      final connection = _availableConnections.removeLast();
      _inUseConnections.add(connection);
      return connection;
    }

    if (_inUseConnections.length >= maxConnections) {
      throw Exception('Maximum LDAP connections reached');
    }

    final connection = LdapConnection(
      host: ldapUrl,
      port: ldapPort,
      ssl: useSsl,
    );

    try {
      await connection.open();
      _inUseConnections.add(connection);
      return connection;
    } catch (e) {
      await _safeClose(connection);
      throw Exception('Failed to create LDAP connection: $e');
    }
  }

  Future<void> releaseConnection(LdapConnection connection) async {
    if (_inUseConnections.contains(connection)) {
      _inUseConnections.remove(connection);

      // Check if connection is still valid
      if (connection.isReady) {
        _availableConnections.add(connection);
      } else {
        await _safeClose(connection);
      }
    }
  }

  Future<void> _safeClose(LdapConnection connection) async {
    try {
      if (connection.isReady) {
        await connection.close();
      }
    } catch (_) {}
  }
}
