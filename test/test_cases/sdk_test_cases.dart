/// Test cases specific to this SDK, kept separate from the shared spec in
/// test_case.dart so that file can be replaced verbatim when the spec changes.
const String gbSdkTestCases = r'''
{
  "evalCondition": [
    [
      "$notRegex - pass",
      {
        "userAgent": {
          "$notRegex": "(Mobile|Tablet)"
        }
      },
      {
        "userAgent": "Chrome Desktop Browser"
      },
      true
    ],
    [
      "$notRegex - fail",
      {
        "userAgent": {
          "$notRegex": "(Mobile|Tablet)"
        }
      },
      {
        "userAgent": "Android Mobile Browser"
      },
      false
    ],
    [
      "$notRegexi - pass",
      {
        "userAgent": {
          "$notRegexi": "(mobile|tablet)"
        }
      },
      {
        "userAgent": "Chrome Desktop Browser"
      },
      true
    ],
    [
      "$notRegexi - fail",
      {
        "userAgent": {
          "$notRegexi": "(mobile|tablet)"
        }
      },
      {
        "userAgent": "Android Mobile Browser"
      },
      false
    ],
    [
      "$ini - pass",
      {
        "tags": {
          "$ini": [
            "A",
            "B"
          ]
        }
      },
      {
        "tags": "a"
      },
      true
    ],
    [
      "$ini - fail",
      {
        "tags": {
          "$ini": [
            "a",
            "b"
          ]
        }
      },
      {
        "tags": "c"
      },
      false
    ],
    [
      "$ini - array pass",
      {
        "tags": {
          "$ini": [
            "A",
            "B"
          ]
        }
      },
      {
        "tags": [
          "d",
          "a"
        ]
      },
      true
    ],
    [
      "$nini - pass",
      {
        "tags": {
          "$nini": [
            "A",
            "B"
          ]
        }
      },
      {
        "tags": "c"
      },
      true
    ],
    [
      "$nini - fail",
      {
        "tags": {
          "$nini": [
            "A",
            "B"
          ]
        }
      },
      {
        "tags": "a"
      },
      false
    ],
    [
      "$alli - pass",
      {
        "tags": {
          "$alli": [
            "A",
            "B"
          ]
        }
      },
      {
        "tags": [
          "a",
          "b",
          "c"
        ]
      },
      true
    ],
    [
      "$alli - fail",
      {
        "tags": {
          "$alli": [
            "A",
            "B"
          ]
        }
      },
      {
        "tags": [
          "a",
          "c"
        ]
      },
      false
    ],
    [
      "ISO date $gte/$lte - previously broken operators fix",
      {
        "subscriptionDate": {
          "$gte": "2025-04-28T12:00",
          "$lte": "2025-12-31T23:59"
        }
      },
      {
        "subscriptionDate": "2025-06-15T14:30"
      },
      true
    ],
    [
      "ISO date $gt/$lt - ensure existing operators still work",
      {
        "lastLogin": {
          "$gt": "2025-01-01T00:00",
          "$lt": "2025-12-31T23:59"
        }
      },
      {
        "lastLogin": "2025-06-15T12:30"
      },
      true
    ],
    [
      "ISO date with timezone - edge case handling",
      {
        "scheduledAt": {
          "$lte": "2025-08-20T15:00:00+05:30"
        }
      },
      {
        "scheduledAt": "2025-08-20T14:30:00+05:30"
      },
      true
    ],
    [
      "ISO date with milliseconds - precision handling",
      {
        "timestamp": {
          "$gte": "2025-01-15T10:30:45.123Z"
        }
      },
      {
        "timestamp": "2025-01-15T10:30:45.456Z"
      },
      true
    ],
    [
      "ISO date boundary test - $gt passes but $lt fails",
      {
        "lastLogin": {
          "$gt": "2025-01-01T00:00",
          "$lt": "2025-06-01T00:00"
        }
      },
      {
        "lastLogin": "2025-12-31T23:59"
      },
      false
    ]
  ]
}
''';
