window.BENCHMARK_DATA = {
  "lastUpdate": 1675680074059,
  "repoUrl": "https://github.com/second-state/witc",
  "entries": {
    "Rust Benchmark": [
      {
        "commit": {
          "author": {
            "name": "second-state",
            "username": "second-state"
          },
          "committer": {
            "name": "second-state",
            "username": "second-state"
          },
          "id": "3b733c9347153189f9b0624e058f71f2f61709b5",
          "message": "fix benchmark ci",
          "timestamp": "2023-02-06T08:45:22Z",
          "url": "https://github.com/second-state/witc/pull/58/commits/3b733c9347153189f9b0624e058f71f2f61709b5"
        },
        "date": 1675680073126,
        "tool": "cargo",
        "benches": [
          {
            "name": "tests::base_instance_invokes_runtime",
            "value": 90931,
            "range": "± 682",
            "unit": "ns/iter"
          },
          {
            "name": "tests::base_native",
            "value": 0,
            "range": "± 0",
            "unit": "ns/iter"
          },
          {
            "name": "tests::fib_instance_invokes_host_function",
            "value": 2504,
            "range": "± 67",
            "unit": "ns/iter"
          },
          {
            "name": "tests::fib_instance_invokes_runtime",
            "value": 14753,
            "range": "± 112",
            "unit": "ns/iter"
          },
          {
            "name": "tests::fib_native",
            "value": 172,
            "range": "± 0",
            "unit": "ns/iter"
          }
        ]
      }
    ]
  }
}