window.BENCHMARK_DATA = {
  "lastUpdate": 1793109124520,
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
      }
    ]
  }
}