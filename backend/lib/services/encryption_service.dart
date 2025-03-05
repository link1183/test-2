import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';

class EncryptionService {
  late final Encrypter _encrypter;
  late final String _publicKeyString;

  EncryptionService() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(255));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final rsaKeyParams =
        RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64);
    final params = ParametersWithRandom(rsaKeyParams, secureRandom);
    final keyGenerator = KeyGenerator('RSA');
    keyGenerator.init(params);

    final pair = keyGenerator.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    _encrypter = Encrypter(RSA(
      publicKey: publicKey,
      privateKey: privateKey,
    ));

    _publicKeyString = CryptoUtils.encodeRSAPublicKeyToPem(publicKey);
  }

  String get publicKey => _publicKeyString;

  String decrypt(String encryptedText) {
    final decoded = Encrypted.fromBase64(encryptedText);
    return _encrypter.decrypt(decoded);
  }
}
