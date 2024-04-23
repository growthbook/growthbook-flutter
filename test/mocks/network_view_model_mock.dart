import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

class DataSourceMock extends FeaturesFlowDelegate {
  /// For data response.
  bool _isSuccess = false;
  bool get isSuccess => _isSuccess;

  /// For mocking error.
  bool _isError = false;
  bool get isError => _isError;

  @override
  void featuresFetchedSuccessfully(GBFeatures gbFeatures) {
    _isSuccess = true;
    _isError = false;
  }
  
  @override
  void featuresAPIModelSuccessfully(FeaturedDataModel model) {
    
  }

  @override
  void featuresFetchFailed(Object? error) {
    _isError = true;
    _isSuccess = false;
  }
}
