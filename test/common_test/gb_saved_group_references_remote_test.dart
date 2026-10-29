import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../Helper/gb_test_helper.dart';
import '../mocks/network_mock.dart';

/// The shared spec's `savedGroupReferencesRemote` section
/// (growthbook/growthbook#7277): saved groups whose members live outside the
/// payload, resolved by the app into the user's remote group ids.
///
/// The `feature` cases set `remoteGroupIds` on the [GBContext] and build the
/// evaluation context with [GBUtils.initializeEvalContext], the path the SDK
/// itself takes, so they cover how the ids reach evaluation.
void main() {
  group('savedGroupReferencesRemote - evalCondition', () {
    for (final item
        in GBTestHelper.getSavedGroupReferencesRemoteData('evalCondition')) {
      test(item[0], () {
        final result = GBConditionEvaluator().isEvalCondition(
          item[2],
          item[1],
          item.length > 4 ? item[4] : null,
        );
        expect(result, item[3]);
      });
    }
  });

  group('savedGroupReferencesRemote - feature', () {
    for (final item
        in GBTestHelper.getSavedGroupReferencesRemoteData('feature')) {
      test(item[0], () {
        final testContext = GBContextTest.fromMap(item[1]);
        final testData = GBFeaturesTest.fromMap(item[1]);
        final remoteGroupIds =
            (item[1]['remoteGroupIds'] as List?)?.cast<String>();

        final gbContext = GBContext(
          enabled: true,
          qaMode: false,
          attributes: testData.attributes,
          trackingCallBack: (_) {},
          backgroundSync: false,
          savedGroups: testContext.savedGroups,
          remoteGroupIds: remoteGroupIds,
        );
        if (testData.features != null) {
          gbContext.features = testData.features!;
        }

        final result = FeatureEvaluator().evaluateFeature(
            GBUtils.initializeEvalContext(gbContext, null), item[2]);
        final expected = GBFeatureResultTest.fromMap(item[3]);

        expect(result.value.toString(), expected.value.toString());
        expect(result.on, expected.on);
        expect(result.off, expected.off);
        expect(result.source?.name, expected.source);
        expect(result.ruleId, expected.ruleId);
      });
    }
  });

  group('GrowthBookSDK remote group ids', () {
    final cachingManager = CachingManager();

    // "flag" is on for members of grp_vip; "excluded" is on for resolved
    // non-members, with the $exists guard GrowthBook adds to "not in group"
    // rules
    final savedGroups = <String, dynamic>{
      'grp_vip': {'type': 'remote', 'attributeKey': 'account_id'},
    };
    final features = <String, GBFeature>{
      'flag': GBFeature.fromJson({
        'defaultValue': false,
        'rules': [
          {
            'condition': {
              '\$savedGroup': {'id': 'grp_vip'}
            },
            'force': true,
          }
        ],
      }),
      'excluded': GBFeature.fromJson({
        'defaultValue': false,
        'rules': [
          {
            'condition': {
              '\$not': {
                '\$savedGroup': {'id': 'grp_vip'}
              },
              '__gb_remoteGroupIds': {'\$exists': true},
            },
            'force': true,
          }
        ],
      }),
    };

    Future<GrowthBookSDK> buildSdk({
      BaseClient client = const MockNetworkClient(),
      bool remoteEval = false,
      List<String>? remoteGroupIds,
    }) async {
      final builder = GBSDKBuilderApp(
        apiKey: '<API_KEY>',
        hostURL: 'https://example.growthbook.io',
        attributes: {'account_id': 'a1'},
        client: client,
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
        remoteEval: remoteEval,
      );
      if (remoteGroupIds != null) builder.setRemoteGroupIds(remoteGroupIds);
      return builder.initialize();
    }

    GrowthBookSDK seed(GrowthBookSDK sdk) {
      sdk.featuresFetchedSuccessfully(gbFeatures: features, isRemote: false);
      sdk.savedGroupsFetchedSuccessfully(
          savedGroups: savedGroups, isRemote: false);
      return sdk;
    }

    tearDown(() {
      cachingManager.clearCache();
    });

    test('setRemoteGroupIds changes evaluation at runtime', () async {
      final sdk = seed(await buildSdk());

      // Unresolved groups match nobody, and fail "not in group" too
      expect(sdk.feature('flag').on, isFalse);
      expect(sdk.feature('excluded').on, isFalse);

      sdk.setRemoteGroupIds(['grp_vip']);
      expect(sdk.feature('flag').on, isTrue);
      expect(sdk.feature('excluded').on, isFalse);
      expect(sdk.remoteGroupIds, ['grp_vip']);

      // An empty list means "in no group", which is what lets "not in group"
      // match
      sdk.setRemoteGroupIds([]);
      expect(sdk.feature('flag').on, isFalse);
      expect(sdk.feature('excluded').on, isTrue);

      sdk.setRemoteGroupIds(null);
      expect(sdk.feature('flag').on, isFalse);
      expect(sdk.feature('excluded').on, isFalse);
    });

    test('the builder sets the remote group ids', () async {
      final sdk = seed(await buildSdk(remoteGroupIds: ['grp_vip']));

      expect(sdk.remoteGroupIds, ['grp_vip']);
      expect(sdk.feature('flag').on, isTrue);
    });

    test('remote evaluation sends the remote group ids', () async {
      final client = _CapturingClient();
      final sdk = await buildSdk(client: client, remoteEval: true);

      sdk.setRemoteGroupIds(['grp_vip']);
      await sdk.refresh();

      final attributes =
          client.lastPostParams?['attributes'] as Map<String, dynamic>?;
      expect(attributes?[Constant.remoteGroupIdsAttribute], ['grp_vip']);
      expect(attributes?['account_id'], 'a1');
    });

    /// The flag is cached on `savedGroups` changes, so every read doesn't
    /// rescan the payload
    test('hasRemoteSavedGroups follows savedGroups changes', () {
      final context = GBContext(savedGroups: savedGroups);
      expect(context.hasRemoteSavedGroups, isTrue, reason: 'set from init');

      context.savedGroups = {
        'admins': {
          'type': 'list',
          'attributeKey': 'id',
          'values': ['u_1']
        }
      };
      expect(context.hasRemoteSavedGroups, isFalse);

      context.savedGroups = savedGroups;
      expect(context.hasRemoteSavedGroups, isTrue);

      context.savedGroups = null;
      expect(context.hasRemoteSavedGroups, isFalse);
    });

    test('\$inGroup on a remote entry is undecided', () {
      final attributes = {
        'account_id': 'a1',
        '__gb_remoteGroupIds': ['grp_vip'],
      };
      final evaluator = GBConditionEvaluator();

      // $inGroup takes values from the payload, and a remote entry has none:
      // undecided, so it fails, and fails under $not as well
      expect(
        evaluator.isEvalCondition(
            attributes,
            {
              'account_id': {'\$inGroup': 'grp_vip'}
            },
            savedGroups),
        isFalse,
      );
      expect(
        evaluator.isEvalCondition(
            attributes,
            {
              '\$not': {
                'account_id': {'\$inGroup': 'grp_vip'}
              }
            },
            savedGroups),
        isFalse,
      );
    });
  });
}

/// Records the last POST body, then answers like [MockNetworkClient].
class _CapturingClient extends MockNetworkClient {
  _CapturingClient();

  Map<String, dynamic>? lastPostParams;

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
      OnSuccess onSuccess, OnError onError) {
    lastPostParams = params;
    return super.consumePostRequest(baseUrl, params, onSuccess, onError);
  }
}
