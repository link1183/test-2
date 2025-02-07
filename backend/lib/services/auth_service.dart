import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:dartdap/dartdap.dart';

class AuthService {
  final String ldapUrl;
  final int ldapPort;
  String baseDN;
  final String jwtSecret;

  AuthService({
    this.ldapUrl = 'dc1.ad.unil.ch',
    this.ldapPort = 636,
    this.baseDN = 'DC=ad,DC=unil,DC=ch',
    required this.jwtSecret,
  });

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
        ['displayName', 'cn', 'mail'],
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
      return {
        'username': userEntry.attributes['cn']?.values.first,
        'displayName': userEntry.attributes['displayName']?.values.first,
        'mail': userEntry.attributes['mail']?.values.first,
      };
    } on LdapException catch (e) {
      print('Unexpected error during authentification: $e');
      return null;
    } finally {
      await ldap.close();
    }
  }

  Future<List<String>> getAllGroups(String username, String password) async {
    LdapConnection? ldap;
    try {
      ldap = await _getLdapConnection();
      final userDN = '$username@ad.unil.ch';
      await ldap.bind(DN: userDN, password: password);

      // Filter for security groups (groupType=2147483650)
      final result = await ldap.search(
        baseDN,
        Filter.and([
          Filter.equals('objectClass', 'group'),
          //Filter.equals('groupType', '2147483650'), // Security group
          Filter.substring('cn', '*bcu*'),
        ]),
        ['distinguishedName', 'cn'],
        scope: SearchScope.SUB_LEVEL,
      );

      final groups = <String>[];
      await for (var entry in result.stream) {
        if (entry.attributes.containsKey('cn')) {
          final cn = entry.attributes['cn']?.values.first.toString() ?? '';
          if (cn.isNotEmpty) {
            groups.add(cn);
          }
        }
      }

      return groups..sort();
    } catch (e) {
      print('Error getting all groups: $e');
      return [];
    } finally {
      await ldap?.close();
    }
  }

  Future<List<String>> getUserGroups(String username, String password) async {
    LdapConnection? ldap;
    try {
      ldap = await _getLdapConnection();
      final userDN = '$username@ad.unil.ch';
      await ldap.bind(DN: userDN, password: password);

      final result = await ldap.search(
        baseDN,
        Filter.equals('sAMAccountName', username),
        ['memberOf'],
        scope: SearchScope.SUB_LEVEL,
      );

      final groups = <String>[];
      await for (var entry in result.stream) {
        if (entry.attributes.containsKey('memberOf')) {
          groups.addAll(
            entry.attributes['memberOf']!.values
                .map((v) => v.toString())
                .map((dn) =>
                    RegExp(r'CN=([^,]+)').firstMatch(dn)?.group(1) ?? '')
                .where((cn) => cn.isNotEmpty),
          );
        }
      }
      return groups..sort();
    } catch (e) {
      print('Error getting user groups: $e');
      return [];
    } finally {
      await ldap?.close();
    }
  }

  String generateToken(Map<String, dynamic> userData) {
    final claims = JWT(
      {
        'sub': userData['username'],
        'name': userData['displayName'],
        'email': userData['mail'],
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch ~/
            1000,
      },
    );

    return claims.sign(SecretKey(jwtSecret));
  }

  bool verifyToken(String token) {
    try {
      final decodedToken = JwtDecoder.decode(token);
      final exp = decodedToken['exp'] as int;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 < exp;
    } catch (e) {
      return false;
    }
  }
}
