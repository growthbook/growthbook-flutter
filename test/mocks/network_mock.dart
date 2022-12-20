import 'dart:convert';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

class MockNetworkClient implements BaseClient {
  @override
  consumeGetRequest(String path, OnSuccess onSuccess, OnError onError) {
    final pseudoResponse = jsonDecode(MockResponse.successResponse);
    onSuccess(pseudoResponse);
    return pseudoResponse;
  }
}

class MockResponse {
  static const successResponse = """
            {
              "status": 200,
              "features": {
                "onboarding": {
                  "defaultValue": "top",
                  "rules": [
                    {
                      "condition": {
                        "id": "2435245",
                        "loggedIn": false
                      },
                      "variations": [
                        "top",
                        "bottom",
                        "center"
                      ],
                      "weights": [
                        0.25,
                        0.5,
                        0.25
                      ],
                      "hashAttribute": "id"
                    }
                  ]
                },
                "qrscanpayment": {
                  "defaultValue": {
                    "scanType": "static"
                  },
                  "rules": [
                    {
                      "condition": {
                        "loggedIn": true,
                        "employee": true,
                        "company": "merchant"
                      },
                      "variations": [
                        {
                          "scanType": "static"
                        },
                        {
                          "scanType": "dynamic"
                        }
                      ],
                      "weights": [
                        0.5,
                        0.5
                      ],
                      "hashAttribute": "id"
                    },
                    {
                      "force": {
                        "scanType": "static"
                      },
                      "coverage": 0.69,
                      "hashAttribute": "id"
                    }
                  ]
                },
                "editprofile": {
                  "defaultValue": false,
                  "rules": [
                    {
                      "force": false,
                      "coverage": 0.67,
                      "hashAttribute": "id"
                    },
                    {
                      "force": false
                    },
                    {
                      "variations": [
                        false,
                        true
                      ],
                      "weights": [
                        0.5,
                        0.5
                      ],
                      "key": "eduuybkbybk",
                      "hashAttribute": "id"
                    }
                  ]
                }
              }
            }
        """;
}
