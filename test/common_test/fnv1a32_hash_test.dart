import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_utils.dart';

// Vectors from growthbook/growthbook packages/sdk-js/src/util.ts hashFnv32a().
// Regenerate: node -e "console.log(hashFnv32a('...'))"
void main() {
  final fnv = FNV();

  group('fnv1a32 – ASCII inputs', () {
    const vectors = <String, int>{
      '': 2166136261,
      'a': 3826002220,
      'b': 3876335077,
      'abc': 440920331,
      'hello': 1335831723,
      'test123': 950984763,
      'foo': 2851307223,
      'bar': 1991736602,
      'z': 4278997933, // bit-31 overflow
      'zz': 1466432373,
      'zzz': 2813343901,
    };

    vectors.forEach((input, expected) {
      test('fnv1a32("$input") == $expected', () {
        expect(fnv.fnv1a32(input), equals(expected));
      });
    });
  });

  group('fnv1a32 – Unicode / UTF-16 inputs', () {
    // Verifies codeUnitAt() is not masked to 8 bits (old bug: & 0xFF).
    const vectors = <String, int>{
      'Ā': 84593183, // U+0100 — first code unit > 255
      'ā': 67815564, // U+0101
      'я': 3389371454, // U+044F
      'тест': 8839891,
      '耀': 71490847, // U+8000, high bit set
      '￿': 2041487694, // U+FFFF, max BMP
    };

    vectors.forEach((input, expected) {
      test('fnv1a32("$input") == $expected', () {
        expect(fnv.fnv1a32(input), equals(expected));
      });
    });
  });

  group('fnv1a32 – version 2 intermediate values', () {
    // v2 applies fnv1a32 twice: fnv1a32(fnv1a32(seed+value).toString())
    test('fnv1a32("seeda") == 717764279', () {
      expect(fnv.fnv1a32('seeda'), equals(717764279));
    });

    test('fnv1a32("717764279") == 2503390505', () {
      expect(fnv.fnv1a32('717764279'), equals(2503390505));
    });

    test('fnv1a32("fooab") == 514738336', () {
      expect(fnv.fnv1a32('fooab'), equals(514738336));
    });

    test('fnv1a32("514738336") == 3887382575', () {
      expect(fnv.fnv1a32('514738336'), equals(3887382575));
    });
  });
}
