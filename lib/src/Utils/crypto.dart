import 'dart:convert';
import 'dart:typed_data';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';
import 'package:pointycastle/export.dart';

// Dart equivalent of CryptoProtocol abstract class
abstract class CryptoProtocol {
  List<int> encrypt(Uint8List key, Uint8List iv, Uint8List plainText);
  List<int> decrypt(Uint8List key, Uint8List iv, Uint8List cypherText);
  Map<String, GBFeature>? getFeaturesFromEncryptedFeatures(String encryptedString, String encryptionKey);
  SavedGroupsValues? getSavedGroupsFromEncryptedFeatures(String encryptedString, String encryptionKey);
}

// Dart equivalent of Crypto class
class Crypto implements CryptoProtocol {
  @override
  Uint8List encrypt(Uint8List key, Uint8List iv, Uint8List plainText) {
    // Define AES block size
    const int kCCBlockSizeAES128 = 16;

    // Ensure key size and IV size are correct
    if (![16, 24, 32].contains(key.length) || iv.length != kCCBlockSizeAES128) {
      throw CryptoError('Invalid key or IV size');
    }

    // Create AES block cipher with PKCS7 padding
    // ignore: deprecated_member_use
    BlockCipher cipher = CBCBlockCipher(AESFastEngine());
    ParametersWithIV<KeyParameter> params = ParametersWithIV(KeyParameter(key), iv);

    PaddedBlockCipherParameters<CipherParameters, CipherParameters> paddingParams =
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(params, null);

    PaddedBlockCipherImpl paddingCipher = PaddedBlockCipherImpl(PKCS7Padding(), cipher);
    paddingCipher.init(true, paddingParams);

    // Encrypt the plainText
    Uint8List encryptedBytes = paddingCipher.process(Uint8List.fromList(plainText));

    return encryptedBytes;
  }

  @override
  Uint8List decrypt(Uint8List key, Uint8List iv, Uint8List cypherText) {
    // Define AES block size
    const int kCCBlockSizeAES128 = 16;

    // Ensure key size, IV size, and cypherText size are correct
    if (![16, 24, 32].contains(key.length) ||
        iv.length != kCCBlockSizeAES128 ||
        cypherText.length % kCCBlockSizeAES128 != 0) {
      throw CryptoError('Invalid key, IV, or cypherText size');
    }

    // Create AES block cipher with PKCS7 padding
    // ignore: deprecated_member_use
    BlockCipher cipher = CBCBlockCipher(AESFastEngine());
    ParametersWithIV<KeyParameter> params = ParametersWithIV(KeyParameter(key), iv);

    PaddedBlockCipherParameters<CipherParameters, CipherParameters> paddingParams =
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(params, null);

    PaddedBlockCipherImpl paddingCipher = PaddedBlockCipherImpl(PKCS7Padding(), cipher);
    paddingCipher.init(false, paddingParams);

    // Decrypt the cypherText
    Uint8List decryptedBytes = paddingCipher.process(Uint8List.fromList(cypherText));

    return decryptedBytes;
  }

  Map<String, dynamic>? _decryptString(String encryptedString, String encryptionKey) {
    final List<String> arrayEncryptedString = encryptedString.split('.');
    final String iv = arrayEncryptedString.first;
    final String cipherText = arrayEncryptedString.last;

    final Uint8List keyBase64 = base64Decode(encryptionKey);
    final Uint8List ivBase64 = base64Decode(iv);
    final Uint8List cipherTextBase64 = base64Decode(cipherText);
    try {
      final List<int> plainTextBuffer = decrypt(keyBase64, ivBase64, cipherTextBase64);
      return jsonDecode(utf8.decode(plainTextBuffer));
    } catch (e) {
      logger.e('Error decrypting: $e');
    }
    return null;
  }

  @override
  Map<String, GBFeature>? getFeaturesFromEncryptedFeatures(String encryptedString, String encryptionKey) {
    final Map<String, dynamic>? decodedMap = _decryptString(encryptedString, encryptionKey);
    if (decodedMap != null) {
      final Map<String, GBFeature> features = decodedMap.map((key, value) {
        return MapEntry(key, GBFeature.fromJson(value));
      });
      return features;
    }
    return null;
  }

  @override
  SavedGroupsValues? getSavedGroupsFromEncryptedFeatures(String encryptedString, String encryptionKey) {
    return _decryptString(encryptedString, encryptionKey);
  }
}

class CryptoError implements Exception {
  final String code;

  CryptoError(this.code);
  CryptoError.fromString(this.code);
}
