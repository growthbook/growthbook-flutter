import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

class DataSourceMock extends FeaturesFlowDelegate {
  /// For data response.
  bool _isSuccess = false;
  bool get isSuccess => _isSuccess;
  int counterNetworkCall = 0;

  /// For mocking error.
  bool _isError = false;
  bool get isError => _isError;

  @override
  void featuresFetchedSuccessfully(
      {required GBFeatures gbFeatures, required bool isRemote}) {
    if (isRemote) {
      counterNetworkCall++;
    }
    _isSuccess = true;
    _isError = false;
  }

  @override
  void featuresAPIModelSuccessfully(FeaturedDataModel model) {}

  @override
  void featuresFetchFailed({required GBError? error, required bool isRemote}) {
    _isError = true;
    _isSuccess = false;
  }

  @override
  void savedGroupsFetchFailed(
      {required GBError? error, required bool isRemote}) {
    _isError = true;
    _isSuccess = false;
  }

  @override
  void savedGroupsFetchedSuccessfully(
      {required SavedGroupsValues savedGroups, required bool isRemote}) {
    _isSuccess = true;
    _isError = false;
  }
}
