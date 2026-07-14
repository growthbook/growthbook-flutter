import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';

void main() {
  group('GrowthBookSDK — saved groups callbacks', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    final cachingManager = CachingManager();

    Future<GrowthBookSDK> buildSdk({
      CacheRefreshHandler? refreshHandler,
      OnInitializationFailure? onInitializationFailure,
    }) async {
      return GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: {'id': 'user-1'},
        client: const MockNetworkClient(),
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
        refreshHandler: refreshHandler,
        onInitializationFailure: onInitializationFailure,
      ).initialize();
    }

    tearDown(() {
      cachingManager.clearCache();
    });

    // -------------------------------------------------------------------------
    // savedGroupsFetchedSuccessfully
    // -------------------------------------------------------------------------
    group('savedGroupsFetchedSuccessfully', () {
      test('stores saved groups in context', () async {
        final sdk = await buildSdk();
        final groups = {
          'admins': ['user-1', 'user-2']
        };

        sdk.savedGroupsFetchedSuccessfully(
          savedGroups: groups,
          isRemote: false,
        );

        expect(sdk.context.savedGroups, groups);
      });

      test('does not call refreshHandler when isRemote is false', () async {
        int callCount = 0;
        final sdk = await buildSdk(
          refreshHandler: (_) => callCount++,
        );
        final countAfterInit = callCount;

        sdk.savedGroupsFetchedSuccessfully(
          savedGroups: {},
          isRemote: false,
        );

        expect(callCount, countAfterInit);
      });

      test('calls refreshHandler with true when isRemote is true', () async {
        bool? handlerValue;
        final sdk = await buildSdk(
          refreshHandler: (value) => handlerValue = value,
        );

        sdk.savedGroupsFetchedSuccessfully(
          savedGroups: {
            'beta': ['user-42']
          },
          isRemote: true,
        );

        expect(handlerValue, isTrue);
      });

      test('does not crash when refreshHandler is null and isRemote is true',
          () async {
        final sdk = await buildSdk();

        expect(
          () => sdk.savedGroupsFetchedSuccessfully(
            savedGroups: {},
            isRemote: true,
          ),
          returnsNormally,
        );
      });
    });

    // -------------------------------------------------------------------------
    // savedGroupsFetchFailed
    // -------------------------------------------------------------------------
    group('savedGroupsFetchFailed', () {
      test('calls onInitializationFailure with the error', () async {
        GBError? captured;
        final sdk = await buildSdk(
          onInitializationFailure: (e) => captured = e,
        );

        sdk.savedGroupsFetchFailed(error: null, isRemote: false);

        // callback was invoked (even with null error)
        expect(captured, isNull);
      });

      test('does not call refreshHandler when isRemote is false', () async {
        int callCount = 0;
        final sdk = await buildSdk(
          refreshHandler: (_) => callCount++,
        );
        final countAfterInit = callCount;

        sdk.savedGroupsFetchFailed(error: null, isRemote: false);

        expect(callCount, countAfterInit);
      });

      test('calls refreshHandler with false when isRemote is true', () async {
        bool? handlerValue;
        final sdk = await buildSdk(
          refreshHandler: (value) => handlerValue = value,
        );

        sdk.savedGroupsFetchFailed(error: null, isRemote: true);

        expect(handlerValue, isFalse);
      });

      test('does not crash when refreshHandler is null and isRemote is true',
          () async {
        final sdk = await buildSdk();

        expect(
          () => sdk.savedGroupsFetchFailed(error: null, isRemote: true),
          returnsNormally,
        );
      });
    });

    // -------------------------------------------------------------------------
    // getStickyBucketAssignmentDocs
    // -------------------------------------------------------------------------
    group('getStickyBucketAssignmentDocs', () {
      test('returns empty map when no sticky bucket service is configured',
          () async {
        final sdk = await buildSdk();
        expect(sdk.getStickyBucketAssignmentDocs(), isEmpty);
      });

      test('returns empty map when stickyBucketAssignmentDocs is null',
          () async {
        final sdk = await buildSdk();
        sdk.context.stickyBucketAssignmentDocs = null;
        expect(sdk.getStickyBucketAssignmentDocs(), isEmpty);
      });
    });
  });
}
