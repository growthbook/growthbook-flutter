import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';
import '../mocks/network_view_model_mock.dart';

// Delegate that throws on featuresAPIModelSuccessfully to exercise
// the catch block inside prepareFeaturesData.
class _ThrowingDelegate extends DataSourceMock {
  @override
  Future<void> featuresAPIModelSuccessfully(FeaturedDataModel model) async {
    throw Exception('deliberate error for testing');
  }
}

void main() {
  group('FeatureViewModel — additional coverage', () {
    const testHostURL = '<HOST URL>';
    const testApiKey = '<SOME KEY>';
    const attr = <String, String>{};

    late GBContext context;
    late DataSourceMock delegate;

    // Encrypted features test vectors (reused from sdk_builder_test)
    const validEncryptedFeatures =
        'vMSg2Bj/IurObDsWVmvkUg==.L6qtQkIzKDoE2Dix6IAKDcVel8PHUnzJ7JjmLjFZFQDqidRIoCxKmvxvUj2kTuHFTQ3/NJ3D6XhxhXXv2+dsXpw5woQf0eAgqrcxHrbtFORs18tRXRZza7zqgzwvcznx';
    const validEncryptionKey = 'Ns04T5n9+59rl2x3SlNHtQ==';
    // Wrong key (valid base64 length, decryption returns null)
    const wrongEncryptionKey = 'AAAAAAAAAAAAAAAAAAAAAA==';
    // Invalid base64 — causes exception inside _decryptString before inner try-catch
    const invalidBase64Encrypted = '!bad-base64!.!more-bad!';

    FeatureViewModel buildViewModel({
      String encryptionKey = '',
      bool networkError = false,
      FeaturesFlowDelegate? customDelegate,
    }) {
      return FeatureViewModel(
        encryptionKey: encryptionKey,
        delegate: customDelegate ?? delegate,
        source: FeatureDataSource(
          client: MockNetworkClient(error: networkError),
          context: context,
        ),
      );
    }

    setUp(() {
      context = GBContext(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        enabled: true,
        forcedVariation: {},
        qaMode: false,
        trackingCallBack: (_) {},
      );
      delegate = DataSourceMock();
    });

    tearDown(() async {
      await CachingManager().clearCache();
    });

    // -------------------------------------------------------------------------
    // connectBackgroundSync
    // -------------------------------------------------------------------------
    group('connectBackgroundSync', () {
      test('fetches features via SSE and calls success delegate', () async {
        final vm = buildViewModel();
        await vm.connectBackgroundSync();
        expect(delegate.isSuccess, isTrue);
      });

      test('reports error when SSE connection fails', () async {
        final vm = buildViewModel(networkError: true);
        await vm.connectBackgroundSync();
        expect(delegate.isError, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // prepareFeaturesData
    // -------------------------------------------------------------------------
    group('prepareFeaturesData', () {
      test('returns false when both features and encryptedFeatures are null', () async {
        final vm = buildViewModel();
        final data = FeaturedDataModel(
          features: null,
          encryptedFeatures: null,
        );
        expect(await vm.prepareFeaturesData(data), isFalse);
      });

      test('catch block calls handleException when delegate throws', () async {
        final throwingDelegate = _ThrowingDelegate();
        final vm = buildViewModel(customDelegate: throwingDelegate);
        final data = FeaturedDataModel(
          features: {'flag': GBFeature(defaultValue: true)},
          encryptedFeatures: null,
        );
        // Should not throw — exception is caught inside prepareFeaturesData
        await vm.prepareFeaturesData(data);
        expect(throwingDelegate.isError, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // handleValidFeatures — saved groups
    // -------------------------------------------------------------------------
    group('handleValidFeatures with savedGroups', () {
      test('calls savedGroupsFetchedSuccessfully when savedGroups is present', () async {
        final vm = buildViewModel();
        final data = FeaturedDataModel(
          features: {'flag': GBFeature(defaultValue: true)},
          encryptedFeatures: null,
          savedGroups: {'admins': ['user-1', 'user-2']},
        );
        await vm.handleValidFeatures(data);
        expect(delegate.isSuccess, isTrue);
      });

      test('skips savedGroups when null', () async {
        final vm = buildViewModel();
        final data = FeaturedDataModel(
          features: {'flag': GBFeature(defaultValue: false)},
          encryptedFeatures: null,
          savedGroups: null,
        );
        await expectLater(vm.handleValidFeatures(data), completes);
      });
    });

    // -------------------------------------------------------------------------
    // handleValidFeatures — encrypted path
    // -------------------------------------------------------------------------
    group('handleValidFeatures encrypted path', () {
      test('delegates to handleEncryptedFeatures when encryptedFeatures is set', () async {
        final vm = buildViewModel(encryptionKey: validEncryptionKey);
        final data = FeaturedDataModel(
          features: null,
          encryptedFeatures: validEncryptedFeatures,
        );
        final result = await vm.handleValidFeatures(data);
        expect(result, isTrue);
        expect(delegate.isSuccess, isTrue);
      });

      test('returns false when encryptedFeatures decryption fails', () async {
        final vm = buildViewModel(encryptionKey: wrongEncryptionKey);
        final data = FeaturedDataModel(
          features: null,
          encryptedFeatures: validEncryptedFeatures,
        );
        expect(await vm.handleValidFeatures(data), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // handleEncryptedFeatures
    // -------------------------------------------------------------------------
    group('handleEncryptedFeatures', () {
      test('returns false for empty encrypted string', () {
        final vm = buildViewModel(encryptionKey: validEncryptionKey);
        expect(vm.handleEncryptedFeatures(''), isFalse);
      });

      test('returns false when encryptionKey is empty', () {
        final vm = buildViewModel();
        expect(vm.handleEncryptedFeatures(validEncryptedFeatures), isFalse);
      });

      test('returns true and notifies delegate on successful decryption', () {
        final vm = buildViewModel(encryptionKey: validEncryptionKey);
        expect(vm.handleEncryptedFeatures(validEncryptedFeatures), isTrue);
        expect(delegate.isSuccess, isTrue);
      });

      test('returns false when decryption produces null (wrong key)', () {
        final vm = buildViewModel(encryptionKey: wrongEncryptionKey);
        expect(vm.handleEncryptedFeatures(validEncryptedFeatures), isFalse);
      });

      test('returns false and calls featuresFetchFailed on exception', () {
        final vm = buildViewModel(encryptionKey: validEncryptionKey);
        // Invalid base64 causes FormatException outside _decryptString inner try-catch
        expect(vm.handleEncryptedFeatures(invalidBase64Encrypted), isFalse);
        expect(delegate.isError, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // handleEncryptedSavedGroups
    // -------------------------------------------------------------------------
    group('handleEncryptedSavedGroups', () {
      test('returns false for empty encrypted string', () {
        final vm = buildViewModel(encryptionKey: validEncryptionKey);
        expect(vm.handleEncryptedSavedGroups(''), isFalse);
      });

      test('returns false when encryptionKey is empty', () {
        final vm = buildViewModel();
        expect(vm.handleEncryptedSavedGroups(validEncryptedFeatures), isFalse);
      });

      test('returns true and notifies delegate on successful decryption', () {
        final vm = buildViewModel(encryptionKey: validEncryptionKey);
        // validEncryptedFeatures decrypts to a Map<String, dynamic> — valid savedGroups
        expect(vm.handleEncryptedSavedGroups(validEncryptedFeatures), isTrue);
        expect(delegate.isSuccess, isTrue);
      });

      test('returns false when decryption produces null (wrong key)', () {
        final vm = buildViewModel(encryptionKey: wrongEncryptionKey);
        expect(vm.handleEncryptedSavedGroups(validEncryptedFeatures), isFalse);
      });

      test('returns false and calls savedGroupsFetchFailed on exception', () {
        final vm = buildViewModel(encryptionKey: validEncryptionKey);
        expect(vm.handleEncryptedSavedGroups(invalidBase64Encrypted), isFalse);
        expect(delegate.isError, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // cacheFeatures
    // -------------------------------------------------------------------------
    group('cacheFeatures', () {
      test('stores features in cache without throwing', () {
        final vm = buildViewModel();
        final data = FeaturedDataModel(
          features: {'flag': GBFeature(defaultValue: true)},
          encryptedFeatures: null,
        );
        expect(() => vm.cacheFeatures(data), returnsNormally);
      });
    });

    // -------------------------------------------------------------------------
    // _fetchCachedFeatures with non-empty encryptionKey (line 179)
    // -------------------------------------------------------------------------
    group('fetchFeatures with pre-populated cache and encryptionKey', () {
      test('reads cached features via GBFeaturesConverter when encryptionKey is set', () async {
        // Pre-populate cache with mock features JSON
        final cacheContent = Uint8List.fromList(utf8.encode(MockResponse.successResponse));
        CachingManager().putData(
          fileName: Constant.featureCache,
          content: cacheContent,
        );

        final vm = FeatureViewModel(
          encryptionKey: '3tfeoyW0wlo47bDnbWDkxg==',
          delegate: delegate,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
        );

        await vm.fetchFeatures(context.getFeaturesURL());
        expect(delegate.isSuccess, isTrue);
      });
    });
  });
}
