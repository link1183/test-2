import 'package:backend/services/auth_service.dart';

Future<void> testLdapAuth(String username, String password) async {
  AuthService authService = AuthService(
    jwtSecret: 'Secret',
  );

  var a = await authService.authenticateUser(username, password);
  print(a);
}

void main() async {
  const username = 'agunthe1';
  const password = 'nFo4nAs53?jSJAnS';

  await testLdapAuth(username, password);
}
