import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';

void main() {
  group('Crypto test', () {
    test('Crypto test', () {
      const String keyString = "Ns04T5n9+59rl2x3SlNHtQ==";
      const String stringForEncrypt =
          "{\"testfeature1\":{\"defaultValue\":true,\"rules\":[{\"condition\":{\"id\":\"1234\"},\"force\":false}]}}";
      const String ivString = "vMSg2Bj/IurObDsWVmvkUg==";
      final Crypto crypto = Crypto();

      final Uint8List keyBase64 = base64.decode(keyString);
      final Uint8List ivBase64 = base64.decode(ivString);
      final Uint8List stringForEncryptBase64 = utf8.encode(stringForEncrypt);

      final Uint8List encryptText =
          crypto.encrypt(keyBase64, ivBase64, stringForEncryptBase64);
      final Uint8List decryptText =
          crypto.decrypt(keyBase64, ivBase64, encryptText);

      final decryptedString = utf8.decode(decryptText);
      expect(stringForEncrypt, decryptedString);
    });
  });
}
