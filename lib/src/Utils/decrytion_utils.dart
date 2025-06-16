import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class DecryptionUtils {
  static decrypt(String payload, String encryptionKey) async {
    if (!payload.contains('.')) {
      throw DecryptionError.invalidPayload;
    }

    try {
      List<String> parts = payload.split('.');
      String ivString = parts[0];
      String cipherTextString = parts[1];

      Uint8List ivData = base64Decode(ivString);
      Uint8List encryptionKeyData = base64Decode(encryptionKey);
      Uint8List cipherTextData = base64Decode(cipherTextString);

      Uint8List decryptedData =
          await AESCryptor.decrypt(cipherTextData, encryptionKeyData, ivData);

      String decryptedString = utf8.decode(decryptedData);
      return decryptedString;
    } catch (e) {
      throw DecryptionError.decryptionFailed;
    }
  }

  static Uint8List keyFromSecret(String encryptionKey) {
    Uint8List keyData = base64Decode(encryptionKey);
    return keyData;
  }
}

class AESCryptor {
  static Future<Uint8List> decrypt(
      Uint8List data, Uint8List key, Uint8List iv) async {
    try {
      final keyParameter = KeyParameter(key);
      final params = ParametersWithIV(keyParameter, iv);

      PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>
          paddingParams =
          PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>(
              params, null);

      // ignore: deprecated_member_use
      final cipher = PaddedBlockCipherImpl(
          PKCS7Padding(), CBCBlockCipher(AESFastEngine()));
      cipher.init(false, paddingParams);

      final decryptedData = cipher.process(Uint8List.fromList(data));

      return Uint8List.fromList(decryptedData);
    } catch (e) {
      throw DecryptionError.decryptionFailed;
    }
  }
}

class DecryptionException implements Exception {
  final String errorMessage;

  DecryptionException(this.errorMessage);
}

enum DecryptionError {
  invalidPayload,
  decryptionFailed,
}
