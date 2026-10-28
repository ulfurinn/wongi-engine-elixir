window.BENCHMARK_DATA = {
  "lastUpdate": 1793218339882,
  "repoUrl": "https://github.com/ulfurinn/wongi-engine-elixir",
  "entries": {
    "Workload": [
      {
        "commit": {
          "author": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "committer": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "distinct": false,
          "id": "46b78ec95a94f2ccfded9e2b7faff7f513a7e930",
          "message": "Add notes on engine internals\n\nHow changes propagate through the network, how tokens are stored and\nfound, the invariants the engine relies on, its known limitations, and\nhow it is tested and benchmarked. For maintainers, so kept out of the\nuser documentation in pages/.",
          "timestamp": "2026-10-27T14:51:25+01:00",
          "tree_id": "9f8a83dec676c61a661bf4978257df6d7e481eb0",
          "url": "https://github.com/ulfurinn/wongi-engine-elixir/commit/46b78ec95a94f2ccfded9e2b7faff7f513a7e930"
        },
        "date": 1793109123734,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "assert",
            "value": 195,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          },
          {
            "name": "retract bans",
            "value": 44,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          },
          {
            "name": "retract",
            "value": 175,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "committer": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "distinct": true,
          "id": "00f57e43f5dfd41238a1582131dbad525bad5ab2",
          "message": "bump version",
          "timestamp": "2026-10-27T14:52:52+01:00",
          "tree_id": "0835906815cc78e1e34c05dfad76ab0ec7cc0a6d",
          "url": "https://github.com/ulfurinn/wongi-engine-elixir/commit/00f57e43f5dfd41238a1582131dbad525bad5ab2"
        },
        "date": 1793109194509,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "assert",
            "value": 126,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          },
          {
            "name": "retract bans",
            "value": 32,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          },
          {
            "name": "retract",
            "value": 129,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "committer": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "distinct": true,
          "id": "da464296b9037eaf62b9557e01a567c6647863ba",
          "message": "Add an option to run without token indexes\n\nWongi.Engine.new(token_indexes: false) skips the parent, fact and\nnode-specific token indexes and scans the node's tokens instead. They\nare kept by default; rule sets that produce many tokens and rarely\nretract can run faster without them.\n\nTOKEN_INDEXES=false mix test runs the suite in that mode, and CI does\nso on every build.",
          "timestamp": "2026-10-28T19:14:07+01:00",
          "tree_id": "8ede3c03ba85c7853d31e07101f1f40071ceb1b0",
          "url": "https://github.com/ulfurinn/wongi-engine-elixir/commit/da464296b9037eaf62b9557e01a567c6647863ba"
        },
        "date": 1793211831509,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "assert",
            "value": 193,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          },
          {
            "name": "retract bans",
            "value": 33,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          },
          {
            "name": "retract",
            "value": 158,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "committer": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "distinct": true,
          "id": "412702c4fa452723a9ebb111ff00e9639c57a646",
          "message": "bump version",
          "timestamp": "2026-10-28T21:11:54+01:00",
          "tree_id": "c8bdf129613f7afbda15fcddc56aa5632a44e415",
          "url": "https://github.com/ulfurinn/wongi-engine-elixir/commit/412702c4fa452723a9ebb111ff00e9639c57a646"
        },
        "date": 1793218339326,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "assert",
            "value": 194,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          },
          {
            "name": "retract bans",
            "value": 31,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          },
          {
            "name": "retract",
            "value": 149,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.4, OTP 29"
          }
        ]
      }
    ]
  }
}