window.BENCHMARK_DATA = {
  "lastUpdate": 1794073685156,
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
      },
      {
        "commit": {
          "author": {
            "email": "29139614+renovate[bot]@users.noreply.github.com",
            "name": "renovate[bot]",
            "username": "renovate[bot]"
          },
          "committer": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "distinct": true,
          "id": "97bb94769d3a6b07ba690050b44bcb55f5ab054f",
          "message": "Update dependency elixir-lang/elixir to v1.20.5",
          "timestamp": "2026-11-07T14:19:07+01:00",
          "tree_id": "ba6add0c4125368373d9530549cfe2c7fbad5fe7",
          "url": "https://github.com/ulfurinn/wongi-engine-elixir/commit/97bb94769d3a6b07ba690050b44bcb55f5ab054f"
        },
        "date": 1794057569329,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "assert",
            "value": 136,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          },
          {
            "name": "retract bans",
            "value": 22,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          },
          {
            "name": "retract",
            "value": 116,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
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
          "id": "ffad4bac103761b9fc26bbb1e9a1ab7d65ad5e29",
          "message": "pin actions",
          "timestamp": "2026-11-07T14:19:49+01:00",
          "tree_id": "f7384b9dc36de9932d4436e7731aeb02663d39ec",
          "url": "https://github.com/ulfurinn/wongi-engine-elixir/commit/ffad4bac103761b9fc26bbb1e9a1ab7d65ad5e29"
        },
        "date": 1794057610725,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "assert",
            "value": 161,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          },
          {
            "name": "retract bans",
            "value": 24,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          },
          {
            "name": "retract",
            "value": 117,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "29139614+renovate[bot]@users.noreply.github.com",
            "name": "renovate[bot]",
            "username": "renovate[bot]"
          },
          "committer": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "distinct": true,
          "id": "51d13e46bfa76a592649de174a6ec2d144eb378b",
          "message": "Pin dependencies",
          "timestamp": "2026-11-07T18:47:22+01:00",
          "tree_id": "078bdbc3b04dc4689fce08df4da6ba1affb0e480",
          "url": "https://github.com/ulfurinn/wongi-engine-elixir/commit/51d13e46bfa76a592649de174a6ec2d144eb378b"
        },
        "date": 1794073663734,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "assert",
            "value": 176,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          },
          {
            "name": "retract bans",
            "value": 30,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          },
          {
            "name": "retract",
            "value": 177,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "29139614+renovate[bot]@users.noreply.github.com",
            "name": "renovate[bot]",
            "username": "renovate[bot]"
          },
          "committer": {
            "email": "ulfurinn@ulfurinn.net",
            "name": "Valeri Sokolov",
            "username": "ulfurinn"
          },
          "distinct": true,
          "id": "62938d934aa733d93c2674b8b73d2593766df862",
          "message": "Update dependency erlang/otp to v29.1.2",
          "timestamp": "2026-11-07T18:47:41+01:00",
          "tree_id": "d395a324c2a2a64ff2e484bd4d2f589cd0eb6632",
          "url": "https://github.com/ulfurinn/wongi-engine-elixir/commit/62938d934aa733d93c2674b8b73d2593766df862"
        },
        "date": 1794073684444,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "assert",
            "value": 196,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          },
          {
            "name": "retract bans",
            "value": 31,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          },
          {
            "name": "retract",
            "value": 158,
            "unit": "ms",
            "extra": "n = 2000, median of 5, Elixir 1.20.5, OTP 29"
          }
        ]
      }
    ]
  }
}