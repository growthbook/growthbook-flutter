import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';
import 'package:growthbook_sdk_flutter/src/Utils/decrytion_utils.dart';

// Valid 16-byte key and IV (base64-encoded)
const _validKeyB64 = 'Ns04T5n9+59rl2x3SlNHtQ=='; // 16 bytes
final _validKey = base64Decode(_validKeyB64);
final _validIv = Uint8List(16); // 16 zero bytes

void main() {
  // -------------------------------------------------------------------------
  // DecryptionUtils.keyFromSecret
  // -------------------------------------------------------------------------
  group('DecryptionUtils.keyFromSecret', () {
    test('decodes a base64 key into bytes', () {
      final result = DecryptionUtils.keyFromSecret(_validKeyB64);
      expect(result, isA<Uint8List>());
      expect(result.length, 16);
    });
  });

  // -------------------------------------------------------------------------
  // DecryptionException constructor
  // -------------------------------------------------------------------------
  group('DecryptionException', () {
    test('stores the error message', () {
      final e = DecryptionException('something went wrong');
      expect(e.errorMessage, 'something went wrong');
    });
  });

  // -------------------------------------------------------------------------
  // CryptoError constructors
  // -------------------------------------------------------------------------
  group('CryptoError', () {
    test('default constructor stores code', () {
      final e = CryptoError('ERR_001');
      expect(e.code, 'ERR_001');
    });

    test('fromString constructor stores code', () {
      final e = CryptoError.fromString('ERR_002');
      expect(e.code, 'ERR_002');
    });
  });

  // -------------------------------------------------------------------------
  // Crypto.encrypt — invalid size guard
  // -------------------------------------------------------------------------
  group('Crypto.encrypt', () {
    test('throws CryptoError when key size is invalid', () {
      final crypto = Crypto();
      final badKey = Uint8List(5); // not 16/24/32 bytes
      expect(
        () => crypto.encrypt(badKey, _validIv, Uint8List(16)),
        throwsA(isA<CryptoError>()),
      );
    });

    test('throws CryptoError when IV size is invalid', () {
      final crypto = Crypto();
      final badIv = Uint8List(8); // not 16 bytes
      expect(
        () => crypto.encrypt(_validKey, badIv, Uint8List(16)),
        throwsA(isA<CryptoError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Crypto.decrypt — invalid size guard
  // -------------------------------------------------------------------------
  group('Crypto.decrypt', () {
    test('throws CryptoError when cypherText length is not a multiple of 16',
        () {
      final crypto = Crypto();
      final badCipher = Uint8List(15); // not multiple of 16
      expect(
        () => crypto.decrypt(_validKey, _validIv, badCipher),
        throwsA(isA<CryptoError>()),
      );
    });

    test('throws CryptoError when key size is invalid', () {
      final crypto = Crypto();
      final badKey = Uint8List(5);
      expect(
        () => crypto.decrypt(badKey, _validIv, Uint8List(16)),
        throwsA(isA<CryptoError>()),
      );
    });
  });
}
