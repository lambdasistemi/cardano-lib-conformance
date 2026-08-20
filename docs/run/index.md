# Running the gate

The repository keeps one root Nix flake as the unified gate. `flake.lock`
fixes every upstream source and its content hash, so a pinned run answers
one question: does the documented claim still match its evidence pin?

```sh
nix flake check
```

That command runs all 37 checks of the `balance-fixpoint` domain.

## Light tier — source and documentation evidence

The source-evidence checks inspect the pinned flake input store paths with
`rg` and fail when a required declaration disappears. The `*-no-candidate-hook`
checks are absence checks: they also fail, with an explicit "update the
balance-fixpoint skill" diagnostic, if a currently absent hook appears.

`examples-docs-inline` compares the complete code block on every per-stack
example page with the real source file and fails on any byte-level drift.

These checks build nothing from the upstream sources beyond fetching them,
so they are the cheap tier. Run one at a time with the
[per-check invocations](checks.md).

## Heavy tier — unit, examples, and cross-validation

Seven checks compile or execute code:

| Check | What it costs |
|---|---|
| `tx-tools-unit` | builds the upstream pinned pure unit check, not a text surrogate |
| `example-csl-outer-loop` | builds and runs the Rust program offline, emitting CBOR |
| `example-ccl-native-hook` | compiles and runs the Java program against fixed-output Maven jars |
| `example-scalus-diffhandler` | compiles the Scala example (compile-only) |
| `example-evolution-outer-loop` | typechecks the TypeScript example with `tsc` |
| `crossval-csl` | decodes the CSL artifact with pinned Pallas code and re-derives fee and value rules |
| `crossval-ccl` | the same cross-validation over the cardano-client-lib artifact |

The two `crossval-*` checks consume the CBOR artifacts produced by the CSL
and cardano-client-lib example checks, so they pull those examples in as
dependencies.

## Other modes

- [Per-check invocations and falsification](checks.md)
- [Floating drift mode](floating-drift.md)
